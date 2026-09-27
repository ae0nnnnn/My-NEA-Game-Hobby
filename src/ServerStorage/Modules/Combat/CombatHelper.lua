local module = {}
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local SS = game:GetService("ServerStorage")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Events = RS.Events
local WeaponEffects = RS.Effects.Weapons
local WeaponSounds = SoundService.SFX.Weapons
local SSModules = SS.Modules
local AnimationsFolder = RS.Animations
local WeaponsAnimations = AnimationsFolder.Weapons

local SoundsModule = require(RS.Modules.Combat.SoundsModule)
local ServerCombatModule = require(SSModules.CombatModule)
local HitServiceModule = require(SSModules.HitService)
local MuchachoHitbox = require(SSModules.Hitboxes.MuchachoHitbox)
local WeaponsStatsModule = require(SSModules.Dictionaries.WeaponStats)
local HelpfullModule = require(SSModules.Other.Helpful)
local Combat_Data = require(ServerStorage.Modules.Combat.Data.CombatData)
local IntentService = require(SSModules.Combat.IntentService)

local VFX_Event: RemoteEvent = Events.VFX

local Connections = {}

local MaxCombo = 4

local FeintFlags = {}
local BlinkCooldowns = {}
local HitBoxes = {}
local SwingHitLog = {} -- per-swing dedupe: {[Identifier] = {[Humanoid]=true}} — works around MuchachoHitbox multi-part same-frame bug without touching vendored

function module.Attack(char, npc)
	if not char or not char:FindFirstChild("Humanoid") then
		return
	end
	local hum = char.Humanoid
	local HRP = char:FindFirstChild("HumanoidRootPart")
	local torso = char:FindFirstChild("Torso")
	local plr = Players:GetPlayerFromCharacter(char)
	local Identifier = plr or npc

	if not HRP or not torso then
		return
	end

	local RevengeFlag = char:GetAttribute("CanRevenge")

	if RevengeFlag then
		print("I crave revenge")
		module.RevengeCounter(char, npc)
		return
	end

	if HelpfullModule.CheckForAttributes(char, true, true, true, true, true, true, true, nil, true) then
		return
	end
	if HelpfullModule.ManageStamina(char, "Swing") then
		return
	end

	IntentService.SetIntent(char, npc, "Swing")

	local currentWeapon = char:GetAttribute("CurrentWeapon")

	-- Begin swing
	char:SetAttribute("Attacking", true)
	char:SetAttribute("Swing", true)

	ServerCombatModule.ChangeCombo(char)
	ServerCombatModule.stopAnims(hum)

	-- Swing slow via GlobalSpeedMult (Flow-aware multiplicative stacking, restores via RemoveGlobalMult)
	HelpfullModule.ApplyGlobalMult(char, "swing", 0.45)
	hum.JumpHeight = 0

	local WeaponStats = WeaponsStatsModule.getStats(currentWeapon)
	local HitAnim = WeaponsAnimations[currentWeapon].Hit["Hit" .. char:GetAttribute("Combo")]
	local SwingEffect = WeaponEffects[currentWeapon].Swing["Swing" .. char:GetAttribute("Combo")]
	local SwingAnim = ServerCombatModule.getSwingAnims(char, currentWeapon)
	local playSwingAnimation = hum.Animator:LoadAnimation(SwingAnim)
	local swingReset = WeaponStats.SwingReset
	local swingFade = WeaponStats.SwingFade
	local SpeedMods = require(RS.Modules.Movement.Ultils.Speed)
	local attackSpeed = SpeedMods.GetAttackSpeed(char)
	if attackSpeed < 0.08 then attackSpeed = 0.08 end
	if swingReset / attackSpeed < 0.08 then
		warn(string.format("[CombatHelper] SwingReset too low: %s %.3f / speed %.3f", currentWeapon, swingReset, attackSpeed))
	end

	-- Disconnect any lingering connections from a previous swing
	if Connections[Identifier] then
		for _, conn in pairs(Connections[Identifier]) do
			if conn then
				conn:Disconnect()
			end
		end
	end

	Connections[Identifier] = {}

	-- Capture connections in locals so each handler always disconnects itself,
	-- not whatever the shared table holds at the time of firing (stale closure fix)
	local hitStartConn, hitEndConn

	local function cleanupSwing()
		if hitStartConn then
			hitStartConn:Disconnect()
			hitStartConn = nil
			Connections[Identifier].HitStart = nil
		end
		if hitEndConn then
			hitEndConn:Disconnect()
			hitEndConn = nil
			Connections[Identifier].HitEnd = nil
		end
		HelpfullModule.RemoveGlobalMult(char, "swing")
		HelpfullModule.ResetMobility(char)
		if HitBoxes[Identifier] then
			pcall(function()
				HitBoxes[Identifier]:Stop()
			end)
			HitBoxes[Identifier] = nil
		end
		SwingHitLog[Identifier] = nil
		char:SetAttribute("Attacking", false)
		char:SetAttribute("Swing", false)
		FeintFlags[Identifier] = false
		IntentService.SetIntent(char, npc, "None")
	end

	hitStartConn = playSwingAnimation:GetMarkerReachedSignal("HitStart"):Connect(function()
		HitBoxes[Identifier] = MuchachoHitbox.CreateHitbox()
		HitBoxes[Identifier].Size = WeaponStats.HitboxSize
		HitBoxes[Identifier].CFrame = HRP
		HitBoxes[Identifier].AutoDestroy = false
		HitBoxes[Identifier].VelocityPrediction = true
		HitBoxes[Identifier].Visualizer = true
		HitBoxes[Identifier].Offset = WeaponStats.HitboxOffset
		HitBoxes[Identifier].DetectionMode = "Default"

		local params = OverlapParams.new()
		params.FilterDescendantsInstances = { char }
		params.FilterType = Enum.RaycastFilterType.Exclude
		-- Pack-only friendly fire: exclude same-group members (data lives in Combat_Data, no npc require needed)
		if npc then
			local groupName = npc:GetGroupName()
			if groupName then
				local packData = Combat_Data.ActiveGroups[groupName]
				if packData then
					for member in pairs(packData.Members) do
						if member.Character and member.Character ~= char then
							table.insert(params.FilterDescendantsInstances, member.Character)
						end
					end
				end
			end
		end
		HitBoxes[Identifier].OverlapParams = params

		HitBoxes[Identifier]:Start()

		SwingHitLog[Identifier] = {}
		HitBoxes[Identifier].Touched:Connect(function(hit, humanoid)
			if SwingHitLog[Identifier] and SwingHitLog[Identifier][humanoid] then
				return
			end
			if SwingHitLog[Identifier] then
				SwingHitLog[Identifier][humanoid] = true
			end
			local Result = HitServiceModule.Normal_Hitbox(char, currentWeapon, humanoid, npc, hit, HitAnim)
			print(Result)
		end)

		hitStartConn:Disconnect()
		hitStartConn = nil
		Connections[Identifier].HitStart = nil
		FeintFlags[Identifier] = true
	end)

	hitEndConn = playSwingAnimation:GetMarkerReachedSignal("HitEnd"):Connect(function()
		if HitBoxes[Identifier] then
			pcall(function()
				HitBoxes[Identifier]:Stop()
			end)
			HitBoxes[Identifier] = nil -- Clear reference so it can't be stopped again
		end
		SwingHitLog[Identifier] = nil
		HelpfullModule.RemoveGlobalMult(char, "swing")
		char:SetAttribute("Swing", false)

		if char:GetAttribute("Combo") == MaxCombo then
			task.wait((swingReset / attackSpeed) + 0.7)
		else
			task.wait(swingReset / attackSpeed)
		end

		char:SetAttribute("Attacking", false)
		if hitEndConn then
			hitEndConn:Disconnect()
			hitEndConn = nil
		end

		Connections[Identifier].HitEnd = nil
		FeintFlags[Identifier] = false
	end)

	Connections[Identifier].HitStart = hitStartConn
	Connections[Identifier].HitEnd = hitEndConn

	playSwingAnimation.Stopped:Connect(function()
		cleanupSwing()
	end)

	if attackSpeed ~= 1 then
		playSwingAnimation:AdjustSpeed(attackSpeed)
	end
	playSwingAnimation:Play(swingFade)
	VFX_Event:FireAllClients("SwingEffect", SwingEffect, char)
	SoundsModule.PlaySound(WeaponSounds[currentWeapon].Combat.Swing, torso)

	if plr then
		VFX_Event:FireClient(plr, "CustomShake", 1, 2, 0, 0.7)
	end
end

function module.CancelAttack(char, npc)
	local plr = Players:GetPlayerFromCharacter(char)
	local Identifier = plr or npc
	local hum = char.Humanoid
	local currentWeapon = char:GetAttribute("CurrentWeapon")
	local SwingEffect = WeaponEffects[currentWeapon].Swing["Swing" .. char:GetAttribute("Combo")]

	if FeintFlags[Identifier] or char:GetAttribute("Swing") == false then
		return
	end

	char:SetAttribute("Attacking", false)
	char:SetAttribute("Swing", false)
	ServerCombatModule.stopAnims(hum)
	if HitBoxes[Identifier] then
		pcall(function()
			HitBoxes[Identifier]:Stop()
		end)
		HitBoxes[Identifier] = nil
	end
	SwingHitLog[Identifier] = nil
	HelpfullModule.RemoveGlobalMult(char, "swing")
	HelpfullModule.ResetMobility(char)
	HelpfullModule.RefundStamina(char, "Swing")
	VFX_Event:FireAllClients("DestroyVFX", char, SwingEffect)
	VFX_Event:FireAllClients("Highlight", char, 0.15, Color3.fromRGB(167, 166, 166), Color3.fromRGB(167, 166, 166))
	IntentService.SetIntent(char, npc, "Feint")

	task.delay(0.35, function()
		if char and char.Parent and IntentService.GetIntent(char, npc) == "Feint" then
			IntentService.SetIntent(char, npc, "None")
		end
	end)

	local sound = char:FindFirstChild("Swing", true)
	if sound then
		sound:Destroy()
	end
end

function module.RevengeCounter(char: Model, npc) -- TODO: Modify this to use the element obj rather than a general one
	local tag = char:FindFirstChild("RevengeTarget")
	if not tag then
		return
	end

	char:SetAttribute("CanRevenge", false)
	char:SetAttribute("Iframes", true)
	char:SetAttribute("Attacking", true)
	IntentService.SetIntent(char, npc, "RevengeCounter")

	local echar = tag.Value
	if not echar then
		return
	end

	local plr = Players:GetPlayerFromCharacter(char)
	local Identifier = plr or npc
	if Combat_Data.ActiveRecoveryTracks[Identifier] then
		Combat_Data.ActiveRecoveryTracks[Identifier]:Stop(0.1)
		Combat_Data.ActiveRecoveryTracks[Identifier] = nil
	end

	local EHRP = echar:FindFirstChild("HumanoidRootPart")
	local HRP = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	local currentWeapon = char:GetAttribute("CurrentWeapon")
	if not EHRP or not HRP or not hum then
		return
	end

	for _, item in pairs(char:GetDescendants()) do
		if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" then
			item.CanCollide = false
		end
	end

	HRP.AssemblyLinearVelocity = Vector3.zero
	HRP.AssemblyAngularVelocity = Vector3.zero

	for _, oldForce in ipairs(HRP:GetChildren()) do
		if oldForce:IsA("LinearVelocity") or oldForce:IsA("VectorForce") then
			oldForce:Destroy()
		end
	end

	local RevengeAnim = hum.Animator:LoadAnimation(WeaponsAnimations[currentWeapon].Combat.RevengeCounter)
	RevengeAnim:Play()

	VFX_Event:FireAllClients("HyprIndicator",char, HRP.CFrame)

	local REVENGE_CLOSE_DIST = 3.5

	local function restoreCollide()
		for _, item in pairs(char:GetDescendants()) do
			if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" then
				item.CanCollide = true
			end
		end
	end

	local function computeRevengeTarget(fromHRP: BasePart, toEHRP: BasePart, dist: number)
		local flatEnemy = Vector3.new(toEHRP.Position.X, fromHRP.Position.Y, toEHRP.Position.Z)
		local vec = flatEnemy - fromHRP.Position
		local dir = vec.Magnitude > 0 and vec.Unit or fromHRP.CFrame.LookVector
		local target = flatEnemy - (dir * dist)
		-- wall clamp same as lerp path so final snap doesn't clip through geometry
		local rayDir = target - fromHRP.Position
		local rayDist = rayDir.Magnitude
		if rayDist > 0 then
			local params = RaycastParams.new()
			params.FilterDescendantsInstances = { char, echar }
			params.FilterType = Enum.RaycastFilterType.Exclude
			local hit = workspace:Raycast(fromHRP.Position, rayDir.Unit * rayDist, params)
			if hit then
				target = hit.Position - (rayDir.Unit * 1.5)
			end
		end
		return target, flatEnemy
	end

	local function createRevengeHitboxAtMarker()
		if not HRP.Parent or not EHRP.Parent then
			return nil, nil
		end

		HRP.AssemblyLinearVelocity = Vector3.zero
		HRP.AssemblyAngularVelocity = Vector3.zero

		local targetPosition, flatEnemyPos = computeRevengeTarget(HRP, EHRP, REVENGE_CLOSE_DIST)
		HRP.CFrame = CFrame.lookAt(targetPosition, flatEnemyPos)
		-- ensure victim stays hypr-parryable: victim Iframes false during revenge hitbox
		if echar and echar.Parent then
			echar:SetAttribute("Iframes", false)
		end

		restoreCollide()

		print("We got there safely - CastHitBox")

		local size = Vector3.new(5, 5, 5)
		local comboValue = char:GetAttribute("Combo") :: number
		local HitAnim = WeaponsAnimations[currentWeapon].Hit["Hit" .. comboValue]

		local RevengeHitbox = MuchachoHitbox.CreateHitbox()
		RevengeHitbox.Size = size
		RevengeHitbox.CFrame = HRP.CFrame
		RevengeHitbox.Offset = CFrame.new(0, -3, 0)
		local params = OverlapParams.new()
		params.FilterDescendantsInstances = { char }
		params.FilterType = Enum.RaycastFilterType.Exclude
		RevengeHitbox.OverlapParams = params

		RevengeHitbox:Start()

		RevengeHitbox.Touched:Connect(function(hit, humanoid)
			return HitServiceModule.Revenge_Hitbox(char, currentWeapon, humanoid, npc, hit, HitAnim)
		end)

		-- revenger stays iframe'd through dash + hitbox so third-party can't steal the trade; victim stays hittable for hypr-parry (cleared above)
		task.delay(0.35, function()
			if RevengeHitbox then
				pcall(function() RevengeHitbox:Stop() end)
				RevengeHitbox = nil
			end
			char:SetAttribute("Attacking", false)
			char:SetAttribute("Iframes", false)
			HelpfullModule.ResetMobility(char)
			if tag then
				tag:Destroy()
			end
		end)
		return RevengeHitbox, HitAnim
	end

	local function TriggerRevengeHitbox()
		local markerConn: RBXScriptConnection? = nil
		local created = false
		local function doCreate()
			if created then return end
			created = true
			if markerConn then markerConn:Disconnect() end
			createRevengeHitboxAtMarker()
		end
		markerConn = RevengeAnim:GetMarkerReachedSignal("CastHitBox"):Connect(doCreate)
		task.delay(0.12, function()
			if not created then doCreate() end
		end)
		RevengeAnim.Stopped:Connect(function()
			task.wait(0.05)
			if not created then doCreate() end
		end)
	end

	do
		local initDist = (EHRP.Position - HRP.Position).Magnitude
		if initDist > 36 then
			restoreCollide()
			HelpfullModule.ResetMobility(char)
			char:SetAttribute("Attacking", false)
			char:SetAttribute("Iframes", false)
			if tag then tag:Destroy() end
			return
		end

		local REVENGE_DUR = math.clamp(initDist / 30, 0.08, 0.25)

		pcall(function() HRP:SetNetworkOwner(nil) end)
		task.delay(0.35, function()
			if HRP.Parent and plr and plr.Parent then
				pcall(function() HRP:SetNetworkOwner(plr) end)
			end
		end)

		local startCF = HRP.CFrame
		local targetPos, initFlat = computeRevengeTarget(HRP, EHRP, REVENGE_CLOSE_DIST)
		local targetCF = CFrame.lookAt(targetPos, Vector3.new(EHRP.Position.X, targetPos.Y, EHRP.Position.Z))
		local startTime = os.clock()
		local conn: RBXScriptConnection? = nil
		conn = RunService.Heartbeat:Connect(function()
			if not echar.Parent or not EHRP.Parent or not char.Parent or not HRP.Parent then
				if conn then conn:Disconnect() end
				restoreCollide()
				return
			end
			local elapsed = os.clock() - startTime
			local alpha = math.clamp(elapsed / REVENGE_DUR, 0, 1)
			local eased = 1 - (1 - alpha) ^ 2
			if alpha >= 1 then
				if conn then conn:Disconnect() end
				HRP.CFrame = targetCF
				if (HRP.Position - EHRP.Position).Magnitude > 40 then
					restoreCollide()
					char:SetAttribute("Attacking", false)
					char:SetAttribute("Iframes", false)
					if tag then tag:Destroy() end
					return
				end
				TriggerRevengeHitbox()
				return
			end
			HRP.CFrame = startCF:Lerp(targetCF, eased)
		end)
	end
end


function module.Blink(char, npc, target)
	local plr = Players:GetPlayerFromCharacter(char)
	local Identifier = plr or npc
	if BlinkCooldowns[Identifier] and tick() - BlinkCooldowns[Identifier] < 0.5 then
		return
	end
	BlinkCooldowns[Identifier] = tick()
	IntentService.SetIntent(char, npc, "Blink")

	local HRP = char:FindFirstChild("HumanoidRootPart")
	local Hum = char.Humanoid
	local currentWeapon = char:GetAttribute("CurrentWeapon")
	if not HRP or not Hum then
		return
	end
	local Hit2nim = WeaponsAnimations[currentWeapon].Hit["Hit" .. char:GetAttribute("Combo")]

	HRP.CFrame = target.HumanoidRootPart.CFrame * CFrame.new(0, 2, 0)

	--local BlinkAnim = Hum.Animator:LoadAnimation(WeaponsAnimations[currentWeapon].Blink):Play()
	--SoundsModule.PlaySound(WeaponSounds[currentWeapon].Combat.Blink, HRP) will uncomment when blink sound is added
	local Size = Vector3.new(5, 5, 5)
	local BlinkHitbox = MuchachoHitbox.CreateHitbox()
	BlinkHitbox.CFrame = HRP
	BlinkHitbox.Size = Size
	BlinkHitbox.Offset = CFrame.new(0, -2, 0)
	local params = OverlapParams.new()
	params.FilterDescendantsInstances = { char }
	params.FilterType = Enum.RaycastFilterType.Exclude
	BlinkHitbox.DetectionMode = "HitOnce"
	BlinkHitbox:Start()

	BlinkHitbox.Touched:Connect(function(hit, humanoid)
		HitServiceModule.Blink_Hitbox(char, currentWeapon, humanoid, npc, hit, Hit2nim)
	end)

	task.delay(0.5, function() -- TODO :  replace with anim event when added so its actually possbile to parry it
		if BlinkHitbox then
			pcall(function()
				BlinkHitbox:Stop()
			end)
			BlinkHitbox = nil
		end
	end)
end

function module.UpperCut(char, npc)
	if HelpfullModule.CheckForAttributes(char, true, true, true, true, true, true, true, nil, true) then
		return
	end

	IntentService.SetIntent(char, npc, "UpperCut")
end



function module.CleanupForPlayer(identifier)
	if Connections[identifier] then
		for _, conn in pairs(Connections[identifier]) do
			if conn then
				pcall(function()
					conn:Disconnect()
				end)
			end
		end
		Connections[identifier] = nil
	end
	if HitBoxes[identifier] then
		pcall(function()
			HitBoxes[identifier]:Stop()
		end)
		HitBoxes[identifier] = nil
	end
	FeintFlags[identifier] = nil
	BlinkCooldowns[identifier] = nil
	SwingHitLog[identifier] = nil
end
return module
