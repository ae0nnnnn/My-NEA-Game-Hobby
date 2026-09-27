local PassiveManger = {}
local RS = game:GetService("ReplicatedStorage")

local Events = RS.Events
local UI_Update = Events.UI_Update

-- Maths Contants
local p = 2.0 -- Soft Cap Exponent for Crit Dmg
local BaseCritDmg = 1.5 -- Base Crit Dmg Multiplier
local MaxBonus = 1.7 -- Max Crit Dmg Multiplier

local CritDropoffRate = 0.02
local BaseCritRate = 0.15 -- In %
local MaxCritRate = 0.45 -- Max Crit from DEX

local MaxdownTime = 22
local Reduction_Range = 2
local K_Time = 15 -- "the half life constant"

local function CalcCrit(DEX: number)
	local roll = math.random(1, 100)

	local CritChance = BaseCritRate + (MaxCritRate - BaseCritRate) * (1 - math.exp(-CritDropoffRate * DEX))
	CritChance = CritChance * 100

	if roll <= CritChance then
		return true
	else
		return false
	end
end

local function Ragdoll(char, ragtime)
	task.spawn(function()
		if char:GetAttribute("IsRagdoll") then
			return
		end

		char:SetAttribute("IsRagdoll", true)
		task.wait(ragtime)
		char:SetAttribute("IsRagdoll", false)
		char:SetAttribute("Iframes", true)
		task.wait(0.6)
		char:SetAttribute("Iframes", false)
	end)
end

local function DamageDealer(char, damage)
	local hum = char:FindFirstChildOfClass("Humanoid") :: Humanoid
	if not hum or not char then
		return
	end

	if hum.Health > damage then
		hum:TakeDamage(damage) -- Take the damage
	else
		hum.Health = 1
		-- This is where the knockdown logic would go
		local END = char:GetAttribute("END") or 1
		local downtime = MaxdownTime - (Reduction_Range * (END / (END + K_Time)))
		Ragdoll(char, downtime)
		char:SetAttribute("Downed", true)
		task.delay(downtime, function()
			char:SetAttribute("Downed", false)
		end)
	end
end

function PassiveManger.M1LandedPassive(attackerObj, defenderObj, damage, STAT_POINTS) -- This refers to when a light attack lands on char
	--[[
    attackerObj - the PLR/NPC object that landed the attack
    defenderObj - the PLR/NPC object that got hit
    damage - the damage that was dealt from base sclaing
    Stats - the stats of the character that landed the attack
    --]]

	if not attackerObj or not defenderObj then
		return damage, false, false
	end

	local attackerChar = attackerObj.Character
	local defenderChar = defenderObj.Character
	local DEX_Points = STAT_POINTS.DEX
	local AttackerElement = attackerObj.Element and attackerObj.Element.Name
	local DefenderElement = defenderObj.Element and defenderObj.Element.Name
	local Attacker_Second_ModeCheck = attackerChar:GetAttribute("Mode2")
	local Defender_Second_ModeCheck = defenderChar:GetAttribute("Mode2")
	local Defender_plr = defenderObj.Player
	local DamageModifiers = 10
	local TotalRes = 0.25
	local isCrit
	local CritDmgMult = BaseCritDmg + (MaxBonus - BaseCritDmg) * (DEX_Points / 99) ^ p
	local Attack_Dodged = false
	local damageAlreadydealt = false

	local MultipliedDamage = damage * (1 + DamageModifiers / 100)
	MultipliedDamage = MultipliedDamage * (1 - TotalRes)

	if attackerChar:GetAttribute("CritTest") then
		isCrit = true
	else
		isCrit = CalcCrit(DEX_Points)
		print(isCrit)
	end

	if isCrit then
		MultipliedDamage = MultipliedDamage * CritDmgMult
	end

	if DefenderElement == "Time" then
		print("If there was a passive for mode 1 it would be here")
		if Defender_Second_ModeCheck then

			-- Resolve defender's element object for dodge count
			local DodgeCounter = 0
			if defenderObj.Element and defenderObj.Element.Name == "Time" then
				DodgeCounter = defenderObj.Element.Data.Dodges or 0
			end

			if DodgeCounter > 0 then
				MultipliedDamage = 0
				if defenderObj.Element then
					defenderObj.Element.Data.Dodges = math.max(0, DodgeCounter - 1)
				end
				defenderChar:SetAttribute("InCombat", true)
				DamageDealer(defenderChar, MultipliedDamage)
				Attack_Dodged = true
				damageAlreadydealt = true
			else
				DamageDealer(defenderChar, MultipliedDamage)
				damageAlreadydealt = true
			end
		end
	end

	if AttackerElement == "Time" then
		print("If there was a passive for mode 1 it would be here")
		if Attacker_Second_ModeCheck and not Attack_Dodged then
			local TargetHum = defenderChar.Humanoid
			local Karma = defenderChar:GetAttribute("Karma")
			defenderChar:SetAttribute("Karma", math.min(Karma + 5, 50))
			local totalDamage = 0
			local tickRate = 3 -- Stage 1

			if Karma > 33 then
				tickRate = 1 -- Stage 3
			elseif Karma > 16 then
				tickRate = 2 -- Stage 2
			end

			local dotDamage = 3 -- Damage per tick
			local karmaDecayRate = 2 -- Karma decreases over time

			task.spawn(function()
				while totalDamage < MultipliedDamage and Karma > 0 and TargetHum and TargetHum.Health > 0 do
					Karma = defenderChar:GetAttribute("Karma")
					if Karma <= 0 then
						break
					end
					DamageDealer(defenderChar, dotDamage)
					totalDamage += dotDamage

					Karma = math.max(0, Karma - (karmaDecayRate * tickRate))
					defenderChar:SetAttribute("Karma", Karma)

					task.wait(tickRate)

					if totalDamage >= MultipliedDamage or TargetHum.Health <= 0 then
						break
					end
				end
				damageAlreadydealt = true
				if Defender_plr then
					UI_Update:FireClient(
						Defender_plr,
						totalDamage,
						TargetHum.Health,
						TargetHum.MaxHealth,
						MultipliedDamage
					)
				end
			end)
		end
	end

	if AttackerElement == "Astral" then
		print("If there was a passive for mode 1 it would be here")
		if Attacker_Second_ModeCheck then
			local SPT = STAT_POINTS.SPT
			local SPT_Bonus = 1
			local SPTScalingFactor = 0.01
			SPT_Bonus = 1 + (SPT * SPTScalingFactor)

			damage = damage * SPT_Bonus

			MultipliedDamage = damage * (1 + DamageModifiers / 100)
			MultipliedDamage = MultipliedDamage * (1 - TotalRes)

			if attackerChar:GetAttribute("CritTest") then
				isCrit = true
			else
				isCrit = CalcCrit(DEX_Points)
				print(isCrit)
			end

			if isCrit then
				MultipliedDamage = MultipliedDamage * CritDmgMult
			end
		end
	end

	return MultipliedDamage, isCrit, damageAlreadydealt
end

function PassiveManger.DefensivePassive(attackerObj, defenderObj, damage) -- This refers to when an object blocks an attack
end

function PassiveManger.DodgeLanded(attackerObj, defenderObj) -- As the name impled this is when an object succesfully dodged something
end

function PassiveManger.BackStabPassive(attackerObj, defenderObj, damage) -- This refers to when an object lands a backstab attack
end

function PassiveManger.OnSkillLanded(attackerObj, defenderObj, damage, skill) -- this
	
end

return PassiveManger
