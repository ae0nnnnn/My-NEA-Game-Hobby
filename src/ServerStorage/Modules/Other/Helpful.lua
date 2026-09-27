local module = {}
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local SSModules = SS.Modules
local Events = RS.Events
local StaminaEvent = Events.Stamina

local MovementData = require(RS.Modules.Movement.Data)

local WeaponsModels = RS.Models.Weapons

local BlockingModule = require(script.Parent.Parent.BlockModule)
local Combat_Data = require(SSModules.Combat.Data.CombatData)
local SkillInfo = require(SSModules.Dictionaries.SkillInfo)

-- Tables
local Welds = Combat_Data.Welds
local EquipAnims = Combat_Data.EquipAnims
local UnEquipAnims = Combat_Data.UnEquipAnims
local IdleAnims = Combat_Data.IdleAnims
local BlockingAnims = Combat_Data.BlockingAnims
local EquipDebounce = Combat_Data.EquipDebounce
local WeaponsWeld = RS.Welds.Weapons

-- Constants
local k = 0.02 -- This is the rate of the drop off for DEX Crit Rate Scaling
local BaseCritRate = 0.15 -- Base Crit Rate %
local MaxCritRate = 0.45 -- Max Crit Rate % given by DEX Points


local MaxdownTime = 22  
local Reduction_Range = 2
local K_Time =  15 -- "the half life constant"

local FlowBonuses = {}
local GlobalMultMods = {} -- [char] = { astral=1.25, swing=0.45, parry=0.4, block=... } multiplicative

function module.DamageDealer(char :Model, damage)
	local hum = char:FindFirstChildOfClass("Humanoid") ::Humanoid
    if not hum or not char then return end 
	
	if hum.Health > damage then
		hum:TakeDamage(damage) -- Take the damage
	else
		hum.Health = 1
		-- This is where the knockdown logic would go
		local END = char:GetAttribute("END") or 1 
		local downtime = MaxdownTime - (Reduction_Range * (END/ (END + K_Time)))
		module.Ragdoll(char,downtime)
		char:SetAttribute("Downed", true)

		-- TODO: Create a functiuon that creates the prox prompt for downed enemies 
		task.delay(downtime, function()
			char:SetAttribute("Downed", false)
		end)
	end
end

function module.ChangeWeapon(plr, char, torso)
	char:SetAttribute("Equipped", false)
	char:SetAttribute("Combo", 1)
	char:SetAttribute("Stunned", false)
	char:SetAttribute("Swing", false)
	char:SetAttribute("Attacking", false)
	char:SetAttribute("Iframes", false)
	char:SetAttribute("IsBlocking", false)
	char:SetAttribute("HoldingBlock", false)
	char:SetAttribute("Mode1", false)
	char:SetAttribute("Mode2", false)
	char:SetAttribute("Parrying", false)
	char:SetAttribute("Sprinting", false)

	local currentWeapon = char:GetAttribute("CurrentWeapon")

	local Weapon = WeaponsModels[currentWeapon]:clone()

	Weapon.Parent = char

	if Weapon:FindFirstChild("SecondWeapon", true) then
		print(Weapon[currentWeapon].SecondWeapon)
		print("LetsWeld")
		Weapon[currentWeapon].SecondWeld.Part0 = char["Left Arm"]
		Weapon[currentWeapon].SecondWeld.Part1 = Weapon[currentWeapon].SecondWeapon
	end

	
	Welds[plr] = WeaponsWeld[currentWeapon].IdleWeaponWeld:Clone()

	Welds[plr].Parent = torso
	Welds[plr].Part0 = torso
	Welds[plr].Part1 = Weapon[currentWeapon]

	if module.CheckForAttributes(char, true, true, true, true, nil, true, true, true) then
		return
	end

	if EquipAnims[plr] then
		EquipAnims[plr]:Stop()
	end
	if IdleAnims[plr] then
		IdleAnims[plr]:Stop()
	end
	if UnEquipAnims[plr] then
		UnEquipAnims[plr]:Stop()
	end
	if BlockingAnims[plr] then
		BlockingAnims[plr]:Stop()
	end

	EquipDebounce[plr] = false
end

function module.CheckInFront(char, enemyChar)
	local enemyHRP = enemyChar.HumanoidRootPart
	local attackDirection = (char.HumanoidRootPart.Position - enemyHRP.Position).Unit
	local frontDirection = enemyHRP.CFrame.LookVector
	local direction = math.acos(attackDirection:Dot(frontDirection)) < math.rad(90)

	if not direction then
		print("Not infront")
		return false
	else
		print("infront")
		return true
	end
end

function module.CheckBehind(char, enemyChar)
	local enemyHRP = enemyChar.HumanoidRootPart
	local attackDirection = (char.HumanoidRootPart.Position - enemyHRP.Position).Unit
	local backDirection = -enemyHRP.CFrame.LookVector
	local direction = math.acos(attackDirection:Dot(backDirection)) < math.rad(90)

	if not direction then
		print("Not behind")
		return false
	else
		print("behind")
		return true
	end
end

function module.ResetMobility(char)
	local hum = char.Humanoid
	if not hum then return end

	-- AGL + per-action speed multiplier + live flow bonus (client-synced for
	-- players, read from the server Flow object for NPCs) + GlobalSpeedMult for passives/NPC slow.
	local SpeedMods = require(RS.Modules.Movement.Ultils.Speed)
	local flowBonus = module.GetCharFlowBonus(char)
	local globalMult = SpeedMods.GetGlobalSpeedMult(char)

	-- IsLow+InCombat penalty is centralized in SpeedMods.GetIsLowFactor (x0.65 on
	-- every speed getter), so ResetMobility applies no local penalty and no longer
	-- swaps to low sprint keys -- that would double-stack the reduction.
	local sprinting = char:GetAttribute("Sprinting")
	local sprintKey = sprinting and "SprintSpeed" or "WalkSpeed"
	local sprintAction = sprinting and "Sprint" or "Walk"

	hum.WalkSpeed = (SpeedMods.GetMovementSpeed(char, sprintKey, sprintAction) or hum.WalkSpeed) * flowBonus * globalMult
	hum.JumpHeight = (SpeedMods.GetJumpSpeed(char, "JumpHeight") or hum.JumpHeight) * flowBonus * globalMult
end

function module.GetGlobalSpeedMult(char)
	local SpeedMods = require(RS.Modules.Movement.Ultils.Speed)
	return SpeedMods.GetGlobalSpeedMult(char)
end

function module.SetGlobalSpeedMult(char, mult)
	char:SetAttribute("GlobalSpeedMult", mult)
	-- Mirror to NPC Flow object server-side for immediate heartbeat lerp (attribute replicates async)
	local ok, npcModule = pcall(function() return require(SSModules.Objects.npc) end)
	if ok and npcModule then
		local npcObj = npcModule.GetNpcFromCharacter(char)
		if npcObj and npcObj.MovementObj and npcObj.MovementObj.Flow then
			npcObj.MovementObj.Flow.GlobalSpeedMult = mult
		end
	end
end

function module.ApplyGlobalMult(char, key, mult)
	GlobalMultMods[char] = GlobalMultMods[char] or {}
	GlobalMultMods[char][key] = mult
	local eff = 1
	for _, v in pairs(GlobalMultMods[char]) do eff *= v end
	module.SetGlobalSpeedMult(char, eff)
end

function module.RemoveGlobalMult(char, key)
	local mods = GlobalMultMods[char]
	if not mods then return end
	mods[key] = nil
	local eff = 1
	for _, v in pairs(mods) do eff *= v end
	module.SetGlobalSpeedMult(char, eff)
	if next(mods) == nil then GlobalMultMods[char] = nil end
end

function module.ClearGlobalMults(char)
	GlobalMultMods[char] = nil
	module.SetGlobalSpeedMult(char, 1)
end

function module.CheckForStatus(
    eChar,
    char,
    npc,
    blockingDamage,
    hitPos,
    CheckForBlocking,
    CheckForParrying,
    checkForDodging,
    checkForHyprParry
)
    if eChar.Humanoid.Health <= 0 or eChar:GetAttribute("Iframes") then
        return true, "HitLanded"
    end

    local stop = false
    local Result = "HitLanded"

    if checkForHyprParry and not stop then
        if eChar:GetAttribute("HyprParry") then
            Result = BlockingModule.HyprParrying(char, eChar, hitPos, npc)
            stop = true
        end
    end

    if CheckForParrying and not stop then
        if eChar:GetAttribute("Parrying") then
            Result = BlockingModule.Parrying(char, eChar, hitPos, npc)
            stop = true
        end
    end

    if CheckForParrying and not stop then
        local DefenderIdentifier = Players:GetPlayerFromCharacter(eChar) or npc
        local APWindow = DefenderIdentifier and Combat_Data.APFrames[DefenderIdentifier]
        if APWindow and tick() < APWindow then
            Result = BlockingModule.APParrying(char, eChar, hitPos, npc)
            stop = true
        end
    end

    if CheckForBlocking and not stop then
        if eChar:GetAttribute("IsBlocking") and module.CheckInFront(char, eChar) then
            Result = BlockingModule.Blocking(char, eChar, blockingDamage, hitPos)
            stop = true
        end
    end

    if checkForDodging and not stop then
        if eChar:GetAttribute("Dodging") then
            BlockingModule.Dodging(char, eChar, hitPos)
            stop = true
        end
    end

    return stop, Result
end




function module.CheckForAttributes(char, attack, swing, stun, ragdoll, equipped, blocking, Dodging, Sprinting, EXSprint)
	local attacking = char:GetAttribute("Attacking")
	local swinging = char:GetAttribute("Swing")
	local stunned = char:GetAttribute("Stunned")
	local isEquipped = char:GetAttribute("Equipped")
	local isRagdoll = char:GetAttribute("IsRagdoll")
	local isBlocking = char:GetAttribute("IsBlocking")
	local isDodging = char:GetAttribute("Dodging")
	local isSprinting = char:GetAttribute("Sprinting")
	local isEXSprinting = char:GetAttribute("IsEXSprinting")

	local stop = false

	if attacking and attack then
		stop = true
	end
	if swinging and swing then
		stop = true
	end
	if stunned and stun then
		stop = true
	end
	if isRagdoll and ragdoll then
		stop = true
	end
	if equipped and not isEquipped then
		stop = true
	end
	if blocking and isBlocking then
		stop = true
	end
	if Dodging and isDodging then
		stop = true
	end
	if Sprinting and isSprinting then
		stop = true
	end
	if EXSprint and isEXSprinting then
		stop = true
	end
	return stop
end

function module.CalculateCrit(DEX_Points)
	local roll = math.random(1, 100)

	local CritChance = BaseCritRate + (MaxCritRate - BaseCritRate) * (1 - math.exp(-k * DEX_Points))
	CritChance = CritChance * 100

	if roll <= CritChance then
		return true
	else
		return false
	end
end

function module.Ragdoll(char, ragdollTime)
	task.spawn(function()
		if char:GetAttribute("IsRagdoll") then
			return
		end

		char:SetAttribute("IsRagdoll", true)
		task.wait(ragdollTime)
		char:SetAttribute("IsRagdoll", false)
		char:SetAttribute("Iframes", true)
		task.wait(0.6)
		char:SetAttribute("Iframes", false)
	end)
end
function module.ManageStamina(char, action, skillName)
    local Stamina = char:GetAttribute("Stamina")
    local Fail = false
    local plr = Players:GetPlayerFromCharacter(char)

	if not plr then return false end  --> npcs dont need to pay stamina

    if action == "Dodge" then
        if Stamina >= 20 then
            Fail = false
            char:SetAttribute("Stamina", (Stamina - 20))
			print(char:GetAttribute("Stamina"))
            return Fail
        else
            Fail = true
            print(char, "Did not have enough stamina to perform a dodge")
            return Fail
        end
    end

    if action == "Swing" then
        if Stamina >= 2 then
            Fail = false
            char:SetAttribute("Stamina", (Stamina - 2))
            return Fail
        else
            Fail = true
            if plr then
                StaminaEvent:FireClient(plr, 10)
            end
            return Fail
        end
    end

    if action == "Skill" then
        local skillData = skillName and SkillInfo.getSkill(skillName)
        local cost = skillData and skillData.Costs and skillData.Costs.Stamina or 0

        if Stamina >= cost then
            Fail = false
            char:SetAttribute("Stamina", (Stamina - cost))
            return Fail
        else
            Fail = true
            if plr then
                StaminaEvent:FireClient(plr, 10)
            end
            return Fail
        end
    end

    if action == "Climb" then
        local cost = MovementData.Data.ClimbStaminaCost
        if Stamina >= cost then
            Fail = false
            char:SetAttribute("Stamina", (Stamina - cost))
            return Fail
        else
            print(char, "Did not have enough stamina to climb")
            Fail = true
            return Fail
        end
    end

    if action == "DoubleJump" then
        local cost = MovementData.Data.DoubleJumpStaminaCost
        if Stamina >= cost then
            Fail = false
            char:SetAttribute("Stamina", (Stamina - cost))
            return Fail
        else
            Fail = true
            if plr then
                StaminaEvent:FireClient(plr, 10)
            end
            return Fail
        end
    end

    -- Add ExSprint Tick Cost
    if action == "ExSprint" then
        if Stamina >= 5 then -- Change 5 to your preferred drain amount per tick
            Fail = false
            char:SetAttribute("Stamina", (Stamina - 5))
            return Fail
        else
            Fail = true
            return Fail
        end
    end

    return Fail
end

function module.RefundStamina(char, action)
	local Stamina = char:GetAttribute("Stamina")


	if action == "DodgeCancel" then
		char:SetAttribute("Stamina", (Stamina + 20))
	end

	if action == "Swing" then
		char:SetAttribute("Stamina", (Stamina + 2))
	end

	if action == "ExSprint" then
		local drain = 5
		while Stamina >=  drain do
			char:SetAttribute("Stamina",(Stamina - 5))
		end
	end

end

function module.ManageMana(char, Skill)
	-- This is for when I start the spell and skill system fully
end

-- Flow bonus sync (client pushes via MovementEvent "FlowUpdate", stored here)
function module.SetFlowBonus(identifier, value)
	FlowBonuses[identifier] = value
end

function module.GetFlowBonus(identifier)
	return FlowBonuses[identifier]
end

-- Resolve the current flow bonus for a character.
-- Players use the client-synced value; NPCs read their (server-authoritative) Flow object.
-- Lazy-requires npc to avoid the Helpful <-> npc require cycle.
function module.GetCharFlowBonus(char)
	local plr = Players:GetPlayerFromCharacter(char)
	if plr then
		return FlowBonuses[plr] or 1
	end

	local npcModule = require(SSModules.Objects.npc)
	local npcObj = npcModule and npcModule.GetNpcFromCharacter(char)
	if npcObj and npcObj.MovementObj and npcObj.MovementObj.Flow then
		return npcObj.MovementObj.Flow.FlowBonus or 1
	end

	return 1
end

Players.PlayerRemoving:Connect(function(player)
	FlowBonuses[player] = nil
	-- Clean any character-based GlobalMultMods for this player's characters
	for char in pairs(GlobalMultMods) do
		if Players:GetPlayerFromCharacter(char) == player then
			GlobalMultMods[char] = nil
		end
	end
end)

return module
