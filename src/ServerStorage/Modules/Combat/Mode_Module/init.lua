local module = {}
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local ServerStorage = game:GetService("ServerStorage")
local SSModules = SS.Modules

-- Module references
local ElementInfo = require(SSModules.Dictionaries.ElementInfo)
local HelpfulModule = require(SSModules.Other.Helpful)
local StatFormulas = require(SSModules.Other.StatFormulas)
local Textmod = require(RS.Modules.text)
local Combat_Data = require(SSModules.Combat.Data.CombatData)


-- Tables
local Welds = Combat_Data.Welds
local EquipAnims = Combat_Data.EquipAnims
local UnEquipAnims = Combat_Data.UnEquipAnims
local IdleAnims = Combat_Data.IdleAnims
local TransformAnims = Combat_Data.TransformAnims
local EquipDebounce = Combat_Data.EquipDebounce

-- Folders
local Models = RS.Models
local WeaponsModels = Models.Weapons
local WeaponsWeld = RS.Welds.Weapons
local WeaponsAnimations = RS.Animations.Weapons
local TransformConnections = {}

-- Resolves the real ElementObject via PLR/NPC instance, not just the string attribute.
-- Lazy-requires inside the function to avoid circular plr -> Mode_Module -> plr.
local function getElementObj(char: Model, npc: any?): any?
	-- Fast path: npc param already carries .Element (npc.lua passes self)
	if npc and typeof(npc) == "table" and (npc :: any).Element ~= nil then
		return (npc :: any).Element
	end
	-- Try PLR lookup via Player -> PLR object
	local plr = game.Players:GetPlayerFromCharacter(char)
	if plr then
		local ok, plrMod = pcall(require, SSModules.Objects.plr)
		if ok and plrMod and plrMod.GetPLRFromPlayer then
			local ok2, plrObj = pcall(plrMod.GetPLRFromPlayer, plr)
			if ok2 and plrObj and (plrObj :: any).Element then
				return (plrObj :: any).Element
			end
		end
	end
	-- Fallback: NPC lookup via Character -> NPC object (covers char without npc param, e.g. Revert)
	local ok3, npcMod = pcall(require, SSModules.Objects.npc)
	if ok3 and npcMod and npcMod.GetNpcFromCharacter then
		local ok4, npcObj = pcall(npcMod.GetNpcFromCharacter, char)
		if ok4 and npcObj and (npcObj :: any).Element then
			return (npcObj :: any).Element
		end
	end
	return nil
end

local function MakeWeaponInvisible(char, Weapon)
	if not Weapon and char then
		return
	end

	Weapon.transparency = 0.011
	Weapon.Reflectance = -0.4

	local HRP = char:FindFirstChild("HumanoidRootPart")
	local InviblePart = RS.Effects.InvisiblePart:Clone()
	local Weld = Instance.new("WeldConstraint")
	Weld.Part0 = HRP
	Weld.Part1 = InviblePart
	Weld.Parent = HRP
	InviblePart.Size = Weapon.Size + Vector3.new(0.5, 0.5, 0.5)
	InviblePart.CFrame = Weapon.CFrame
	InviblePart.Parent = HRP
end

local function RemoveInvisibleParts(char, Weapon)
	if not char then
		return
	end
	local HRP = char:FindFirstChild("HumanoidRootPart")
	if not HRP then
		return
	end
	for _, part in ipairs(HRP:GetChildren()) do
		if part.Name == "InvisiblePart" then
			part:Destroy()
		end
	end
end

local function ModelRefresher(weapon) -- debug function untill the obve function is ready
	weapon.Transparency = 0
	weapon.Reflectance = 0
end

-- Force-clears any in-progress attack state that may have been left hanging
-- because a transformation interrupted the swing before HitEnd could fire.
-- CombatModule's Stopped handler also does this, but calling it here ensures
-- the reset happens before we re-enable mobility / iframes at the end of a transform.
local function clearAttackState(char)
	char:SetAttribute("Attacking", false)
	char:SetAttribute("Swing", false)
end

function module.CleanupForPlayer(identifier)
	if TransformConnections[identifier] then
		pcall(function()
			TransformConnections[identifier]:Disconnect()
		end)
		TransformConnections[identifier] = nil
	end
	EquipDebounce[identifier] = nil
end

---------------------------------------------------------------------
-- MODE 1 TRANSFORMATION
---------------------------------------------------------------------
function module.Mode1(char, npc)
	if not char or not char:FindFirstChild("Humanoid") then
		return
	end

	local hum = char.Humanoid
	local rootPart = char:WaitForChild("HumanoidRootPart")

	local plr = game.Players:GetPlayerFromCharacter(char)
	local Identifier = plr or npc
	if not Identifier then
		return
	end
	if EquipDebounce[Identifier] then
		return
	end
	if HelpfulModule.CheckForAttributes(char, false, false, false, true, nil, false, false, false) then
		return
	end

	EquipDebounce[Identifier] = true
	char:SetAttribute("Iframes", true)
	char:SetAttribute("IsTransforming", true)

	local element = char:GetAttribute("Element")
	if element == nil or element == "..." or element == "None" then
		warn("[Mode_Module] Element attribute is invalid for character: " .. char.Name)
		return
	end
	local elemObj = getElementObj(char, npc)
	local elementStats = ElementInfo.getStats(element)
	local newWeapon = (elemObj and elemObj.Data and elemObj.Data.Mode1Weapon) or elementStats.Mode1
	TransformAnims[Identifier] = hum.Animator:LoadAnimation(WeaponsAnimations.Transformations[element].Mode1)
	rootPart.Anchored = true
	TransformAnims[Identifier]:Play()

	if TransformConnections[Identifier] then
		TransformConnections[Identifier]:Disconnect()
	end

	TransformConnections[Identifier] = TransformAnims[Identifier]:GetMarkerReachedSignal("Transform"):Connect(function()
		TransformConnections[Identifier]:Disconnect()

		for _, anim in ipairs(hum.Animator:GetPlayingAnimationTracks()) do
			if anim.Name == "Swing1" or anim.Name == "Swing2" or anim.Name == "Swing3" or anim.Name == "Swing4" then
				return
			end
		end

		if HelpfulModule.CheckForAttributes(char, true, true, true, true, nil, true, true, nil) then
			return
		end

		-- A transformation can interrupt a swing before HitEnd fires, leaving
		-- Attacking/Swing stuck. Clear them here before restoring normal state.
		clearAttackState(char)

		char:SetAttribute("CurrentWeapon", newWeapon)
		

		local torso = char:FindFirstChild("Torso")
		local rightArm = char:FindFirstChild("Right Arm")

		for _, weapon in ipairs(WeaponsModels:GetChildren()) do
			local existing = char:FindFirstChild(weapon.Name)
			if existing then
				existing:Destroy()
			end
		end

		HelpfulModule.ChangeWeapon(Identifier, char, torso)
		local WeaponMOdel = char:FindFirstChild(char:GetAttribute("CurrentWeapon"),true)
		ModelRefresher(WeaponMOdel[WeaponMOdel.Name])


		
		if Welds[Identifier] then
			Welds[Identifier].Part0 = rightArm
			Welds[Identifier].C0 = WeaponsWeld[newWeapon].HoldingWeaponWeld.C0
		end

		IdleAnims[Identifier] = hum.Animator:LoadAnimation(WeaponsAnimations[newWeapon].Main.Idle)
		EquipAnims[Identifier] = hum.Animator:LoadAnimation(WeaponsAnimations[newWeapon].Main.Equip)

		rootPart.Anchored = false
		char:SetAttribute("IsTransforming", false)
		char:SetAttribute("Equipped", true)
		char:SetAttribute("Iframes", false)
		char:SetAttribute("Mode1", true)

		-- Run element Mode1Init via PLR/NPC object (guard: nil for beasts)
		if elemObj and elemObj.Mode1Init then
			pcall(function()
				elemObj:Mode1Init(char)
			end)
		end

		EquipDebounce[Identifier] = false

		if IdleAnims[Identifier] then
			IdleAnims[Identifier]:Play()
		end
	end)
end

---------------------------------------------------------------------
-- MODE 2 TRANSFORMATION
---------------------------------------------------------------------
function module.Mode2(char, npc)
	if not char or not char:FindFirstChild("Humanoid") then
		return
	end

	local hum = char.Humanoid
	local rootPart = char:WaitForChild("HumanoidRootPart")

	local plr = game.Players:GetPlayerFromCharacter(char)
	local Identifier = plr or npc
	if not Identifier then
		return
	end
	if EquipDebounce[Identifier] then
		return
	end
	if HelpfulModule.CheckForAttributes(char, false, false, false, true, nil, false, false, false) then
		return
	end

	EquipDebounce[Identifier] = true
	char:SetAttribute("Iframes", true)
	char:SetAttribute("IsTransforming", true)
	char:SetAttribute("Mode2", true)
	char:SetAttribute(StatFormulas.STAT_MULT_ATTRIBUTE, StatFormulas.CONFIG.TRANSFORM.StatMult)

	local element = char:GetAttribute("Element")
	if element == nil or element == "..." or element == "None" then
		warn("[Mode_Module] Element attribute is invalid for character: " .. char.Name)
		return
	end
	local elemObj = getElementObj(char, npc)
	local elementStats = ElementInfo.getStats(element)
	local newWeapon = (elemObj and elemObj.Data and elemObj.Data.Mode2Weapon) or elementStats.Mode2
	local dialogue = (elemObj and elemObj.Data and elemObj.Data.Dialogue) or elementStats.Text

	hum.Health += 100
	rootPart.Anchored = true

	TransformAnims[Identifier] = hum.Animator:LoadAnimation(WeaponsAnimations.Transformations[element].Mode1)

	if plr then
		-- Textmod.feed(dialogue, plr)  freezing this for now
	end

	TransformAnims[Identifier]:Play()

	if TransformConnections[Identifier] then
		TransformConnections[Identifier]:Disconnect()
	end

	TransformConnections[Identifier] = TransformAnims[Identifier]:GetMarkerReachedSignal("Transform"):Connect(function()
		TransformConnections[Identifier]:Disconnect()

		for _, anim in ipairs(hum.Animator:GetPlayingAnimationTracks()) do
			if anim.Name == "Swing1" or anim.Name == "Swing2" or anim.Name == "Swing3" or anim.Name == "Swing4" then
				return
			end
		end

		if HelpfulModule.CheckForAttributes(char, true, true, true, true, nil, true, true, nil) then
			return
		end

		-- Clear any stuck attack state from a swing that was interrupted by this transformation
		clearAttackState(char)

		char:SetAttribute("CurrentWeapon", newWeapon)
		
		

		local torso = char:FindFirstChild("Torso")
		local rightArm = char:FindFirstChild("Right Arm")

		for _, weapon in ipairs(WeaponsModels:GetChildren()) do
			local existing = char:FindFirstChild(weapon.Name)
			if existing then
				existing:Destroy()
			end
		end

		HelpfulModule.ChangeWeapon(Identifier, char, torso)
		local WeaponMOdel = char:FindFirstChild(char:GetAttribute("CurrentWeapon"),true)
		ModelRefresher(WeaponMOdel[WeaponMOdel.Name])


		if Welds[Identifier] then
			Welds[Identifier].Part0 = rightArm
			Welds[Identifier].C0 = WeaponsWeld[newWeapon].HoldingWeaponWeld.C0
			if Welds[Identifier].C1 then
				Welds[Identifier].C1 = WeaponsWeld[newWeapon].HoldingWeaponWeld.C1
			end
		end

		IdleAnims[Identifier] = hum.Animator:LoadAnimation(WeaponsAnimations[newWeapon].Main.Idle)
		EquipAnims[Identifier] = hum.Animator:LoadAnimation(WeaponsAnimations[newWeapon].Main.Equip)


		rootPart.Anchored = false
		char:SetAttribute("IsTransforming", false)
		char:SetAttribute("Equipped", true)
		char:SetAttribute("Iframes", false)
		char:SetAttribute("Mode2", true)

		-- Run element Mode2Init via PLR/NPC object (guard: nil for beasts)
		if elemObj and elemObj.Mode2Init then
			pcall(function()
				elemObj:Mode2Init(char)
			end)
		end

		EquipDebounce[Identifier] = false

		if IdleAnims[Identifier] then
			IdleAnims[Identifier]:Play()
		end

		-- Only start MF drain coroutine for players, not NPCs
		if npc == nil then
			coroutine.wrap(function()
				local mf = char:GetAttribute("MF")
				local maxMF = char:GetAttribute("MaxMF")
				print("hello starting MF gain")
				while char:GetAttribute("Mode2") do
					task.wait(1)
					mf = char:GetAttribute("MF")
					maxMF = char:GetAttribute("MaxMF")
					if mf and mf < maxMF then
						char:SetAttribute("MF", math.min(mf + StatFormulas.CONFIG.MF.BuildupRate, maxMF))
						char:SetAttribute("StopTime_MF", os.clock())
					else
						while char:GetAttribute("AstralDodgeActive") do
							task.wait(0.1)
						end
						module.Revert(char)
						return
					end
				end
			end)()
		end
	end)
end

---------------------------------------------------------------------
-- REVERT
---------------------------------------------------------------------
function module.Revert(char, npc)
	if not char or not char:FindFirstChild("Humanoid") then
		return
	end

	local hum = char:FindFirstChild("Humanoid")
	local torso = char:FindFirstChild("Torso")
	local rightArm = char:FindFirstChild("Right Arm")
	local plr = game.Players:GetPlayerFromCharacter(char)
	local Identifier = plr or npc
	if not Identifier then
		return
	end
	if EquipDebounce[Identifier] then
		return
	end
	local element = char:GetAttribute("Element")
	if element == nil or element == "..." or element == "None" then
		warn("[Mode_Module] Element attribute is invalid for character: " .. char.Name)
		return
	end
	local elemObj = getElementObj(char, npc)

	-- Mode2 -> Mode1 downgrade: different from Mode1 -> inactive
	-- This is the "Mode2 -> Mode1" path you asked to separate.
	if char:GetAttribute("Mode2") then
		char:SetAttribute(StatFormulas.STAT_MULT_ATTRIBUTE, 1)
		HelpfulModule.RemoveGlobalMult(char, "astral") -- undo Astral:Mode2Init (stack-aware)
		if elemObj and elemObj.Data and elemObj.Data.Dodges ~= nil then
			elemObj.Data.Dodges = 0 -- reset Time counter
		end
		char:SetAttribute("Mode2", false)
		module.Mode1(char, npc) -- Mode1 will set Mode1=true + call Mode1Init via elemObj
		return
	end

	if char:GetAttribute("Mode1") then
		EquipDebounce[Identifier] = true
		char:SetAttribute("Iframes", true)
		char:SetAttribute("IsTransforming", false)

		local newWeapon = "Fists"
		TransformAnims[Identifier] = hum.Animator:LoadAnimation(WeaponsAnimations.Transformations.Revert)
	
		hum.WalkSpeed = 8
		TransformAnims[Identifier]:Play()

		if TransformConnections[Identifier] then
			TransformConnections[Identifier]:Disconnect()
		end

		TransformConnections[Identifier] = TransformAnims[Identifier]
			:GetMarkerReachedSignal("Transform")
			:Connect(function()
				TransformConnections[Identifier]:Disconnect()

				for _, anim in ipairs(hum.Animator:GetPlayingAnimationTracks()) do
					if
						anim.Name == "Swing1"
						or anim.Name == "Swing2"
						or anim.Name == "Swing3"
						or anim.Name == "Swing4"
					then
						return
					end
				end

				if HelpfulModule.CheckForAttributes(char, true, true, true, true, nil, true, true, nil) then
					return
				end

				-- Clear any stuck attack state from a swing interrupted by this revert
				clearAttackState(char)

				char:SetAttribute("CurrentWeapon", newWeapon)

				for _, weapon in ipairs(WeaponsModels:GetChildren()) do
					local existing = char:FindFirstChild(weapon.Name)
					if existing then
						existing:Destroy()
					end
				end

				HelpfulModule.ChangeWeapon(Identifier, char, torso)

				if Welds[Identifier] then
					Welds[Identifier].Part0 = rightArm
					Welds[Identifier].C0 = WeaponsWeld[newWeapon].HoldingWeaponWeld.C0
				end

				IdleAnims[Identifier] = hum.Animator:LoadAnimation(WeaponsAnimations[newWeapon].Main.Idle)
				EquipAnims[Identifier] = hum.Animator:LoadAnimation(WeaponsAnimations[newWeapon].Main.Equip)

				HelpfulModule.ResetMobility(char)
				char:SetAttribute("IsTransforming", false)
				char:SetAttribute("Equipped", true)
				char:SetAttribute("Iframes", false)
				char:SetAttribute("Mode1", false)
				char:SetAttribute(StatFormulas.STAT_MULT_ATTRIBUTE, 1)
				HelpfulModule.RemoveGlobalMult(char, "astral")
				-- Guard: clear element state on full revert (Mode1 -> inactive)
				if elemObj and elemObj.Data and elemObj.Data.Dodges ~= nil then
					elemObj.Data.Dodges = 0
				end
				EquipDebounce[Identifier] = false

				if IdleAnims[Identifier] then
					IdleAnims[Identifier]:Play()
				end
			end)
	else
		warn(char, "Is performing a false revert")
	end
end

return module
