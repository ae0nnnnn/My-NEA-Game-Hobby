local module = {}

local players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Events = RS.Events
local RSModules = RS.Modules
local SSModule = SS.Modules
local WeaponSounds = SoundService.SFX.Weapons
local WeaponAnimsFolder = RS.Animations.Weapons

local Combat_Data = require(SSModule.Combat.Data.CombatData)

-- Tables
local BlockingAnims = Combat_Data.BlockingAnims
local ParryAnims = Combat_Data.ParryAnims
local SucessfulParry = Combat_Data.SuccessfulParry
local SuccssfulHypr = Combat_Data.SuccessfulHyprParry

local AP_WINDOW = 0.3
local AP_CHAIN_WINDOW = 0.18

local AP_Table = {}

local VFX_Event: RemoteEvent = Events.VFX
local MovementEvent: RemoteEvent = Events.Movement

local SoundsModule = require(RSModules.Combat.SoundsModule)
local ServerCombatModule = require(SSModule.CombatModule)
local WeaponStatsModule = require(SSModule.Dictionaries.WeaponStats)
local PassiveManger = require(SSModule.Combat.PassiveManger)
local StunHandler = require(SSModule.Other.StunHandlerV2)
local IntentService = require(SSModule.Combat.IntentService)
local SkillInfo = require(SSModule.Dictionaries.SkillInfo)

local function ResetMobility(char)
	-- Delegate to the shared implementation (AGL + speed multiplier + flow bonus).
	-- Lazy-required to avoid the Helpful <-> BlockModule require cycle.
	require(SSModule.Other.Helpful).ResetMobility(char)
end

local function FreezeAnims(hum: Humanoid, duration: number)
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)

	-- 1. Snapshot the track states by their Asset ID and current frame time
	local frozenSnapshots = {}

	for _, anim in ipairs(animator:GetPlayingAnimationTracks()) do
		local animObject = anim.Animation
		if animObject and animObject.AnimationId ~= "" then
			-- Save everything needed to recreate/resume the animation state
			table.insert(frozenSnapshots, {
				animationId = animObject.AnimationId,
				timePosition = anim.TimePosition,
				speed = anim.Speed > 0 and anim.Speed or 1,
				weight = anim.WeightTarget,
			})
			anim:AdjustSpeed(0)
		end
	end

	-- 2. Catch tracks triggered mid-hitstop
	local newTrackConnection = animator.AnimationPlayed:Connect(function(track)
		local animObject = track.Animation
		if animObject and animObject.AnimationId ~= "" then
			table.insert(frozenSnapshots, {
				animationId = animObject.AnimationId,
				timePosition = 0,
				speed = 1,
				weight = 1,
			})
			track:AdjustSpeed(0)
		end
	end)

	-- Hitstop duration
	task.wait(duration)
	newTrackConnection:Disconnect()

	-- 3. Restore tracks using the immutable IDs
	print("Attempting to unfreeze tracks from snapshots... Total logged:", #frozenSnapshots)

	-- Clear out any dead server tracks to rebuild cleanly
	for _, anim in ipairs(animator:GetPlayingAnimationTracks()) do
		anim:Stop(0)
	end

	for _, snapshot in ipairs(frozenSnapshots) do
		-- Create a clean tracking instance using the saved ID
		local newAnimInstance = Instance.new("Animation")
		newAnimInstance.AnimationId = snapshot.animationId

		local success, newTrack = pcall(function()
			return animator:LoadAnimation(newAnimInstance)
		end)

		if success and newTrack then
			newTrack:Play(0, snapshot.weight, snapshot.speed)
			newTrack.TimePosition = snapshot.timePosition
			print("Successfully restored track ID:", snapshot.animationId, "at time:", snapshot.timePosition)
		else
			print("Failed to restore snapshot for ID:", snapshot.animationId)
		end
	end
end
local function HyprKnockback(Char)
	if not Char then
		return
	end

	local HRP: BasePart = Char:FindFirstChild("HumanoidRootPart")
	local hum = Char:FindFirstChildOfClass("Humanoid")
	if not HRP or not hum then
		return
	end

	
	hum.AutoRotate = false

	local att = HRP:FindFirstChild("HyprAtt") or Instance.new("Attachment")
	att.Name = "HyprAtt"
	att.Parent = HRP

	local backwardDirection = -HRP.CFrame.LookVector

	-- 1. Restored Impulse Force
	local popUpwardForce = 25
	local popBackwardForce = 40
	local impulseVector = (backwardDirection * popBackwardForce) + Vector3.new(0, popUpwardForce, 0)
	HRP:ApplyImpulse(impulseVector * HRP:GetMass())

	-- 2. Restored LinearVelocity Constraint
	local slideSpeed = 75
	local lv = Instance.new("LinearVelocity")
	lv.Name = "HyprForce"
	lv.Attachment0 = att
	lv.MaxForce = math.huge
	lv.VectorVelocity = backwardDirection * slideSpeed
	lv.Parent = HRP

	-- Clean up physics objects locally
	Debris:AddItem(lv, 0.25)
	Debris:AddItem(att, 0.25)

	-- Restore AutoRotate right after the knockback objects are destroyed
	task.delay(0.25, function()
		if hum and hum.Parent then
			hum.AutoRotate = true
		end
	end)
end

function module.HyprParrying(char, eChar, npc)
	if not char or not eChar then
		return
	end
	local EHRP: BasePart = eChar:FindFirstChild("HumanoidRootPart")
	local HRP: BasePart = char:FindFirstChild("HumanoidRootPart")

	if not EHRP or not HRP then
		return
	end

	local EcurrentWeapon = char:GetAttribute("CurrentWeapon")

	local hum: Humanoid = char.Humanoid
	local Ehum: Humanoid = eChar.Humanoid

	local plr = players:GetPlayerFromCharacter(eChar)
	local identifer = plr or npc
	local Result = "Hitlanded"
	SuccssfulHypr[identifer] = true

	eChar:SetAttribute("HyprParry", false)
	eChar:SetAttribute("Parrying", false)
	if ParryAnims[identifer] then
		pcall(function()
			ParryAnims[identifer]:Stop()
		end)
	end

	local DistOffset = CFrame.new(0, 0, -3.5) -- this is the offset for how far apart the attack (char) would be from defnder(echar)
	local rotation = CFrame.Angles(0, math.rad(180), 0) -- same as above but for roatation

	HRP.CFrame = EHRP.CFrame * DistOffset * rotation

	local HyprSound = WeaponSounds[EcurrentWeapon].Blocking.HyprParrySFX

	local Defenderhitstop =
		eChar.Humanoid.Animator:LoadAnimation(WeaponAnimsFolder[EcurrentWeapon].Blocking.HyprParryLanded) --- Its a a one frame animation for hitstop

	VFX_Event:FireAllClients("HyprParry", char, eChar)

	local tag = Instance.new("ObjectValue", eChar)
	tag.Name = "RevengeTarget"
	tag.Value = char

	Defenderhitstop:Play()
	FreezeAnims(hum, 0.2) -- freeze the currently playing animation although some "weighty" attacks it might not stop though (though is more than the current prototype needs)
	Ehum.AutoRotate = false
	hum.AutoRotate = false
	HRP.Anchored = true
	EHRP.Anchored = true

	char:SetAttribute("Iframes", true)
	char:SetAttribute("Stunned", true)
	eChar:SetAttribute("Stunned", true)
	eChar:SetAttribute("Iframes", true)
	IntentService.SetIntent(char, nil, "None")
	IntentService.SetIntent(eChar, nil, "None")

	task.wait(0.2) -- change to how long the hitstop is was 0.2
	Defenderhitstop:Stop()
	char:SetAttribute("Stunned", false)
	eChar:SetAttribute("Stunned", false)
	char:SetAttribute("Iframes", false)
	HRP.Anchored = false
	EHRP.Anchored = false

	if char:GetAttribute("BreakMeter") then
		local currentBreak = char:GetAttribute("BreakMeter")
		local breakDamage = 50 -- Adjust based on weapon data
		local newbreak = math.max(0, currentBreak - breakDamage)

		char:SetAttribute("BreakMeter", newbreak)

		if newbreak <= 0 then
			print("You messed up!")
			-- trigger the Weapon Breaking Logic Here
		end
	end

	local recover = eChar.Humanoid.Animator:LoadAnimation(WeaponAnimsFolder[EcurrentWeapon].Blocking.Hypr_Recover)
	if not plr then
		HyprKnockback(eChar)
	else
		MovementEvent:FireClient(plr, "HyprParry", eChar)
	end

	--	local stagger = char.Humanoid.Animator:LoadAnimation(WeaponAnimsFolder[EcurrentWeapon].Blocking.HyprParryStagger)
	recover:Play()
	local targetPlr = players:GetPlayerFromCharacter(eChar) or npc
	Combat_Data.ActiveRecoveryTracks[targetPlr] = recover
	--stagger:Play()
	SoundsModule.PlaySound(HyprSound, EHRP)

	task.delay(0.2, function()
		if not eChar or not eChar.Parent then
			return
		end
		eChar:SetAttribute("CanRevenge", true)

		task.delay(1.2, function()
			if eChar and eChar.Parent then
				eChar:SetAttribute("CanRevenge", false)
				eChar:SetAttribute("Iframes", false)
				print("help me")
				ResetMobility(eChar)
				ResetMobility(char)
				Ehum.AutoRotate = true
				hum.AutoRotate = true
				tag:Destroy()
			end
		end)
	end)

	StunHandler.Stun(char.Humanoid, 0.8, 2, 0)

	Result = "Hypr-Parried"

	return Result
end

function module.Parrying(char, eChar, hitPos, npc)
	local identifier = players:GetPlayerFromCharacter(eChar) or npc
	local Result = "HitLanded"
	SucessfulParry[identifier] = true
	if identifier then
		Combat_Data.APFrames[identifier] = tick() + AP_WINDOW
		AP_Table[identifier] = false
	end
	if ParryAnims[identifier] then
		ParryAnims[identifier]:Stop()
		-- Kill the parry anims to prevent the rest of the parry process from being ran so cooldowns are not triggered
	end

	local currentWeapon = char:GetAttribute("CurrentWeapon")
	local BlockDmg = WeaponStatsModule.getStats(currentWeapon).BlockDmg

	char:SetAttribute("Blocking", char:GetAttribute("Blocking") + BlockDmg)
	eChar:SetAttribute("Blocking", eChar:GetAttribute("Blocking") - BlockDmg)
	eChar:SetAttribute("InCombat", true)
	eChar:SetAttribute("Parrying", false)
	eChar:SetAttribute("HyprParry", false)

	if eChar:GetAttribute("Blocking") < 0 then
		eChar:SetAttribute("Blocking", 0)
	end

	VFX_Event:FireAllClients("CombatEffects", RS.Effects.Combat.Parry, hitPos, 3)
	SoundsModule.PlaySound(WeaponSounds[eChar:GetAttribute("CurrentWeapon")].Blocking.Parry, eChar.Torso)

	local attackerIntent = IntentService.GetIntent(char, npc)
	local skillData = SkillInfo.getSkill(attackerIntent)
	local interrupt = not skillData or skillData.ParryInterupt ~= false

	if interrupt then
		ServerCombatModule.stopAnims(char.Humanoid)

		char.Humanoid.Animator
			:LoadAnimation(WeaponAnimsFolder[char:GetAttribute("CurrentWeapon")].Blocking.GotParried)
			:Play()

		StunHandler.Stun(char.Humanoid, 1.2, 0, 0)
	end

	eChar.Humanoid.Animator
		:LoadAnimation(WeaponAnimsFolder[eChar:GetAttribute("CurrentWeapon")].Blocking.ParryLanded)
		:Play()
	local plr = players:GetPlayerFromCharacter(char)
	if plr then
		VFX_Event:FireClient(plr, "CustomShake", 4, 8, 0, 1.2)
	end
	VFX_Event:FireAllClients("Highlight", eChar, 1, Color3.new(1, 1, 0), Color3.new(0.894118, 0.607843, 0.0588235))

	Result = "Parried"

	return Result
end

function module.APParrying(char, eChar, hitPos, npc)
	local identifier = players:GetPlayerFromCharacter(eChar) or npc
	local Result = "HitLanded"

	if identifier and not AP_Table[identifier] then
		Combat_Data.APFrames[identifier] = tick() + AP_CHAIN_WINDOW
		AP_Table[identifier] = true
	end

	if ParryAnims[identifier] then
		ParryAnims[identifier]:Stop()
	end
	char:SetAttribute("Blocking", math.min(100, char:GetAttribute("Blocking") + 5))

	eChar:SetAttribute("InCombat", true)
	eChar:SetAttribute("Parrying", false)
	eChar:SetAttribute("HyprParry", false)

	VFX_Event:FireAllClients("CombatEffects", RS.Effects.Combat.Parry, hitPos, 3)
	SoundsModule.PlaySound(WeaponSounds[eChar:GetAttribute("CurrentWeapon")].Blocking.Parry, eChar.Torso)

	eChar.Humanoid.Animator:LoadAnimation(WeaponAnimsFolder[eChar:GetAttribute("CurrentWeapon")].Blocking.ParryLanded):Play()

	VFX_Event:FireAllClients("Highlight", eChar, 0.2, Color3.new(1, 1, 0), Color3.new(0.894118, 0.607843, 0.0588235))

	Result = "Parried"

	return Result
end

function module.GuardBreak(char)
	VFX_Event:FireAllClients("CombatEffects", RS.Effects.Combat.GuardBreak, char.HumanoidRootPart.CFrame, 3)

	VFX_Event:FireAllClients("Highlight", char, 2, Color3.fromRGB(255, 255, 0), Color3.fromRGB(170, 170, 0))

	ServerCombatModule.stopAnims(char.Humanoid)

	char.Humanoid.Animator
		:LoadAnimation(WeaponAnimsFolder[char:GetAttribute("CurrentWeapon")].Blocking.GuardBreak)
		:Play()

	SoundsModule.PlaySound(WeaponSounds[char:GetAttribute("CurrentWeapon")].Blocking.GuardBreak, char.Torso)

	char:SetAttribute("Blocking", 0)
	char:SetAttribute("IsBlocking", false)
	IntentService.SetIntent(char, nil, "None")

	local plr = players:GetPlayerFromCharacter(char)
	if plr then
		VFX_Event:FireClient(plr, "CustomShake", 6, 12, 0, 2)
	end

	StunHandler.Stun(char.Humanoid, 1.35,0,0)
end

function module.ActivateBlocking(char, npc)
	local hum = char.Humanoid
	local plr = players:GetPlayerFromCharacter(char)
	local Identifier = plr or npc

	SoundsModule.PlaySound(WeaponSounds[char:GetAttribute("CurrentWeapon")].Blocking.BlockingStart, char.Torso)

	BlockingAnims[Identifier] =
		hum:LoadAnimation(WeaponAnimsFolder[char:GetAttribute("CurrentWeapon")].Blocking.Blocking)
	BlockingAnims[Identifier]:Play()

	char:SetAttribute("IsBlocking", true)
	IntentService.SetIntent(char, npc, "Block")

	if plr then
		-- Player: remove hard WalkSpeed=6 slow → just kill sprint via remote, keep jump lock
		MovementEvent:FireClient(plr, "ForceAction", "StopSprint")
		hum.JumpHeight = 0
	else
		-- NPC: keep Flow-aware slow via GlobalSpeedMult (stacked)
		local SpeedMods = require(RS.Modules.Movement.Ultils.Speed)
		local walkBase = SpeedMods.GetMovementSpeed(char, "WalkSpeed", "Walk") or hum.WalkSpeed
		local blockSpeed = WeaponStatsModule.getStats(char:GetAttribute("CurrentWeapon")).BlockingWalkSpeed
		local mult = walkBase > 0 and (blockSpeed / walkBase) or 1
		require(SSModule.Other.Helpful).ApplyGlobalMult(char, "block", mult)
		hum.JumpHeight = 0
	end
end

function module.DeactivateBlocking(char, npc)
	local plr = players:GetPlayerFromCharacter(char)
	local Identifier = plr or npc

	SoundsModule.PlaySound(WeaponSounds[char:GetAttribute("CurrentWeapon")].Blocking.BlockingStop, char.Torso)
	BlockingAnims[Identifier]:Stop()
	char:SetAttribute("IsBlocking", false)
	char:SetAttribute("LastStopTime", tick())
	IntentService.SetIntent(char, npc, "None")

	if not plr then
		require(SSModule.Other.Helpful).RemoveGlobalMult(char, "block")
	end
	ResetMobility(char)
end

function module.Dodging(char, eChar, hitpos)
	if not char or not eChar then
		return
	end
	local currentWeapon = eChar:GetAttribute("CurrentWeapon")
	local dir = eChar:GetAttribute("CurrentMoveKey")

	if dir == "None" then
		local Anim = WeaponAnimsFolder[currentWeapon].Dodging.None
		VFX_Event:FireAllClients("AfterImage", char, Anim, nil)
	else
		-- Once i make the dodge landed vfx it would go here play the vfx at hitpos
	end

	PassiveManger.DodgeLanded(char)
	-- SoundsModule.PlaySound() this would be used once i made a dodge landed sound
end

function module.Blocking(char, enemyChar, damage, hitPos)
	if enemyChar:GetAttribute("Blocking") <= 100 then
		local currentWeapon = char:GetAttribute("CurrentWeapon")
		local BlockDmg = WeaponStatsModule.getStats(currentWeapon).BlockDmg
		local data = WeaponStatsModule.getStats(currentWeapon)
		local ChipDmgPercent = data.ChipDamage
		local Result = "HitLanded"

		local ChipDmg = damage * (ChipDmgPercent / 100)

		enemyChar:SetAttribute("Blocking", enemyChar:GetAttribute("Blocking") + BlockDmg)
		enemyChar:SetAttribute("InCombat", true)
		enemyChar.Humanoid:TakeDamage(ChipDmg)

		print(ChipDmg)

		if enemyChar:GetAttribute("Blocking") >= 100 then
			module.GuardBreak(enemyChar)
			Result = "GuardBroken"
			return Result
		end

		VFX_Event:FireAllClients("Highlight", enemyChar, 0.5, Color3.fromRGB(255, 255, 0), Color3.fromRGB(255, 255, 0))

		VFX_Event:FireAllClients("CombatEffects", RS.Effects.Combat.Block, hitPos, 3)

		SoundsModule.PlaySound(WeaponSounds[enemyChar:GetAttribute("CurrentWeapon")].Blocking.Blocked, enemyChar.Torso)

		enemyChar.Humanoid.Animator
			:LoadAnimation(WeaponAnimsFolder[enemyChar:GetAttribute("CurrentWeapon")].Blocking.Blocked)
			:Play()

		Result = "Blocked"
		return Result
	end

	return "WasHit"
end

return module
