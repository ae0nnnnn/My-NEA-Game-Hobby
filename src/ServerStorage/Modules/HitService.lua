local module = {}

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Events = RS.Events
local WeaponSounds = SoundService.SFX.Weapons
local SSModules = SS.Modules
local WeaponsAnimations = RS.Animations.Weapons

local CombatEvent = Events.Combat
local UI_Update = Events.UI_Update
local VFX_Event = Events.VFX

local SoundsModule = require(RS.Modules.Combat.SoundsModule)
local ServerCombatModule = require(SSModules.CombatModule)
local WeaponsStatsModule = require(SSModules.Dictionaries.WeaponStats)
local HelpfulModule = require(SSModules.Other.Helpful)
local StatFormulas = require(SSModules.Other.StatFormulas)
local StunHandler = require(SSModules.Other.StunHandlerV2)
local PassiveManger = require(SSModules.Combat.PassiveManger)
local Threarts = require(SSModules.AI.ThreatTable)

local function GetNPCFromCharacter(char)
	local plr = game.Players:GetPlayerFromCharacter(char)
	if plr then
		return nil
	end
	local npcModule = require(SSModules.Objects.npc)
	return npcModule.GetNpcFromCharacter(char)
end

function module.BodyVelocity(parent, hrp, Knockback, stayTime)
	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(math.huge, 0, math.huge)
	bv.P = 50000
	bv.Velocity = hrp.CFrame.LookVector * Knockback
	bv.Parent = parent
	Debris:AddItem(bv, stayTime)
end

function module.Normal_Hitbox(char, weapon, eHum, npc, Hit, ...)
	local hitAnim = ...
	local Truehit = hitAnim
	local plrModule = require(SSModules.Objects.plr)

	if eHum and eHum.Parent ~= char then
		local eChar = eHum.Parent
		local Eplr = game.Players:GetPlayerFromCharacter(eChar)
		local Enpc = GetNPCFromCharacter(eChar)
		local attackerNpcObject = GetNPCFromCharacter(char)

		local eHRP = eChar.HumanoidRootPart

		local WeaponStats = WeaponsStatsModule.getStats(weapon)
		-- Dmg Varibles
		local BaseDmg = WeaponStats.Damage
		local Scaling = WeaponStats.Scaling
		local WPN_Points = StatFormulas.GetStat(char, "WPN", npc and npc.WPN)
		local DEX_Points = StatFormulas.GetStat(char, "DEX", npc and npc.DEX)
		local SPT_Points = StatFormulas.GetStat(char, "SPT", npc and npc.SPT)

		local STAT_POINTS = {
			DEX = DEX_Points,
			WPN = WPN_Points,
			SPT = SPT_Points,
		}

		-- Resolve attacker's element object for dodge count
		local attackerPlr = game.Players:GetPlayerFromCharacter(char)
		local attackerObj = attackerPlr and plrModule.GetPLRFromPlayer(attackerPlr) or attackerNpcObject
		local attackerDodges = 0
		if attackerObj and attackerObj.Element then
			attackerDodges = attackerObj.Element.Data.Dodges or 0
		end

		-- Resolve defender's element object for dodge count
		local defenderObj = Eplr and plrModule.GetPLRFromPlayer(Eplr) or Enpc
		local defenderDodges = 0
		if defenderObj and defenderObj.Element then
			defenderDodges = defenderObj.Element.Data.Dodges or 0
		end

		local P_eff = StatFormulas.WeaponPoints(WPN_Points)

		local Truedamage = math.ceil(BaseDmg + P_eff * ((BaseDmg / 1000) * Scaling))

		--Misc Varibles
		local Knockback = WeaponStats.Knockback
		local stunTime = WeaponStats.StunTime


		-- Pack-only friendly fire: same ActiveGroup members never damage each other (other packs can)
		do
			local victimGroupNameForHit = Enpc and Enpc.GetGroupName and Enpc:GetGroupName() or nil
			local attackerGroupNameForHit = attackerNpcObject and attackerNpcObject.GetGroupName and attackerNpcObject:GetGroupName() or nil
			if victimGroupNameForHit and attackerGroupNameForHit and victimGroupNameForHit == attackerGroupNameForHit then
				return "FriendlyFire"
			end
		end

		local stop, result =
			HelpfulModule.CheckForStatus(eChar, char, Enpc, BaseDmg, Hit.CFrame, true, true, true, true)
		if stop then
			return result
		end

		local PassiveCheckDmg, isCrit, damageAlreadydealt = PassiveManger.M1LandedPassive(attackerObj, defenderObj, Truedamage, STAT_POINTS)

	

		if damageAlreadydealt == false then
			HelpfulModule.DamageDealer(eChar, PassiveCheckDmg)
		end

		if attackerNpcObject and attackerNpcObject.AIObject and attackerNpcObject.AIObject.Threats then
			Threarts.RegisterHit(attackerNpcObject.AIObject, eChar, PassiveCheckDmg)
		end

		if Enpc and Enpc.AIObject and Enpc.AIObject.Threats then
			Threarts.RegisterDamage(Enpc.AIObject, char, PassiveCheckDmg)
		end
		-- Pack Tactics: elect Aggressor by last hit (Addendum B) — lazy require to avoid npc -> HitService cycle
		if Enpc and Enpc.GetGroupName then
			local groupNameForPack = Enpc:GetGroupName()
			if groupNameForPack then
				local success, npcModuleForPack = pcall(require, SSModules.Objects.npc)
				if success and npcModuleForPack and npcModuleForPack.NotifyHit then
					pcall(function() npcModuleForPack.NotifyHit(groupNameForPack, Enpc, char) end)
				end
			end
		end
		eChar:SetAttribute("InCombat", true)
		local KarmaDamage = 0
		if Eplr then
			UI_Update:FireClient(Eplr, KarmaDamage, eHum.Health, eHum.MaxHealth, PassiveCheckDmg)
		end

		

		ServerCombatModule.stopAnims(eHum)
		if attackerDodges and attackerDodges > 1 then
			print("Dodged hitbox VFX")
		else
			VFX_Event:FireAllClients("CombatEffects", RS.Effects.Combat.Blood, Hit.CFrame, 3)
		end

		if isCrit then
			if char:GetAttribute("Element") == "Astral" then
				VFX_Event:FireAllClients(
					"Highlight",
					eChar,
					0.5,
					Color3.fromRGB(255, 0, 0),
					Color3.fromRGB(138, 0, 229)
				)
			else
				VFX_Event:FireAllClients("Highlight", eChar, 0.5, Color3.fromRGB(255, 0, 0), Color3.fromRGB(255, 0, 0))
			end
		else
			VFX_Event:FireAllClients(
				"Highlight",
				eChar,
				0.5,
				Color3.fromRGB(255, 255, 255),
				Color3.fromRGB(246, 211, 211)
			)
		end

		SoundsModule.PlaySound(WeaponSounds[weapon].Combat.Hit, eChar.Torso)

		if defenderDodges and defenderDodges > 1 then
			local hitAnim = WeaponsAnimations.TwinSpears.Dodge["Dodge" .. char:GetAttribute("Combo")]
			eHum.Animator:LoadAnimation(hitAnim):Play()
			VFX_Event:FireAllClients("AfterImage", eChar, hitAnim, nil)
		else
			eHum.Animator:LoadAnimation(Truehit):Play()
		end

		module.BodyVelocity(char.HumanoidRootPart, char.HumanoidRootPart, Knockback, 0.2)

		if defenderDodges and defenderDodges > 1 and char:GetAttribute("Combo") >= 4 then
			-- BoneModule.DodgeRandomTP(eChar, char)
			-- TODO: Replace the aboove with the element object rather than a pure module
		elseif char:GetAttribute("Combo") >= 4 then
			Knockback = Knockback * 9
		end

		module.BodyVelocity(eHRP, char.HumanoidRootPart, Knockback, 0.3)

		StunHandler.Stun(eHum, stunTime,0,0)
		return result
	end

	return "Missed"
end

function module.Revenge_Hitbox(char, weapon, eHum, npc, Hit, ...)
	local hitAnim = ...
	local Truehit = hitAnim
	local plrModule = require(SSModules.Objects.plr)

	if eHum and eHum.Parent ~= char then
		local eChar = eHum.Parent
		local Eplr = game.Players:GetPlayerFromCharacter(eChar)
		local Enpc = GetNPCFromCharacter(eChar)

		local BaseDmg = 20

		local stop, result =
			HelpfulModule.CheckForStatus(eChar, char, Enpc, BaseDmg, Hit.CFrame, true, true, true, true)
		if stop and result ~= "HitLanded" then
			return result
		end

		HelpfulModule.DamageDealer(eChar, BaseDmg)

		local revengeDefenderObj = Eplr and plrModule.GetPLRFromPlayer(Eplr)
		local revengeDefenderDodges = 0
		if revengeDefenderObj and revengeDefenderObj.Element then
			revengeDefenderDodges = revengeDefenderObj.Element.Data.Dodges or 0
		elseif Enpc and Enpc.Element then
			revengeDefenderDodges = Enpc.Element.Data.Dodges or 0
		end

		if revengeDefenderDodges and revengeDefenderDodges > 1 then
			local hitAnimDodge = WeaponsAnimations.TwinSpears.Dodge["Dodge" .. char:GetAttribute("Combo")]
			eHum.Animator:LoadAnimation(hitAnimDodge):Play()
			VFX_Event:FireAllClients("AfterImage", eChar, hitAnimDodge, nil)
		else
			eHum.Animator:LoadAnimation(Truehit):Play()
		end

		SoundsModule.PlaySound(WeaponSounds[weapon].Combat.Hit, eChar.Torso)
		VFX_Event:FireAllClients("CombatEffects", RS.Effects.Combat.Blood, Hit.CFrame, 3)
		VFX_Event:FireAllClients("Highlight", eChar, 0.5, Color3.fromRGB(255, 255, 255), Color3.fromRGB(246, 211, 211))

		module.BodyVelocity(eChar.HumanoidRootPart, char.HumanoidRootPart, 12, 0.2)
		StunHandler.Stun(eChar.Humanoid, 0.35, 0, 0)
		return result
	end

	return "Missed"
end

function module.Blink_Hitbox(char, weapon, eHum, npc, Hit, ...)
	local hitAnim = ...
	local Truehit = hitAnim
	local plrModule = require(SSModules.Objects.plr)

	if eHum and eHum.Parent ~= char then
		local eChar = eHum.Parent
		local Eplr = game.Players:GetPlayerFromCharacter(eChar)
		local Enpc = GetNPCFromCharacter(eChar)

		local BaseDmg = 20 -- would replace with actual WPN scaling when we have it

		local stop, result =
			HelpfulModule.CheckForStatus(eChar, char, Enpc, BaseDmg, Hit.CFrame, true, true, true, true)
		print(result, "helpful result")
		if stop and result ~= "HitLanded" then
			return result
		end

		-- local PassiveCheckDmg, isCrit, damageAlreadydealt =	PassiveManger.BlinkHitPassive(char,eChar,BaseDmg)  doesnt exist yet but will be added in the future

		print(eHum)

		-- Resolve defender's element object for dodge count
		local blinkDefenderObj = Eplr and plrModule.GetPLRFromPlayer(Eplr)
		local blinkDefenderDodges = 0
		if blinkDefenderObj and blinkDefenderObj.Element then
			blinkDefenderDodges = blinkDefenderObj.Element.Data.Dodges or 0
		elseif Enpc and Enpc.Element then
			blinkDefenderDodges = Enpc.Element.Data.Dodges or 0
		end

		if blinkDefenderDodges and blinkDefenderDodges > 1 then
			local hitAnim = WeaponsAnimations.TwinSpears.Dodge["Dodge" .. char:GetAttribute("Combo")]
			eHum.Animator:LoadAnimation(hitAnim):Play()
			VFX_Event:FireAllClients("AfterImage", eChar, hitAnim, nil)
		else
			eHum.Animator:LoadAnimation(Truehit):Play()
		end

		SoundsModule.PlaySound(WeaponSounds[weapon].Combat.Hit, eChar.Torso)
		VFX_Event:FireAllClients("Highlight", eChar, 0.5, Color3.fromRGB(255, 255, 255), Color3.fromRGB(37, 33, 33))
		eHum:TakeDamage(20)
	end

	return "Missed"
end

return module
