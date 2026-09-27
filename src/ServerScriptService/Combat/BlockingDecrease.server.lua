--[[ Services and Modules ]]
--
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local Timer = require(RS.Modules.Packages.Timer)
local StatusEffectsModule = require(SS.Modules.StatusEffectsModule)
local CombatData = require(SS.Modules.Combat.Data.CombatData)
local PLRModule = require(SS.Modules.Objects.plr)

local Events = RS.Events
local UI_Update:RemoteEvent = Events.UI_Update

--[[ Configuration ]]
--
local CONFIG = {
    BLOCKING = {
        BASE_DECREASE_TIME = 3,
        BASE_DECREASE_AMOUNT = 2,
        --- TODO : Add the comabt versions
    },

    STAMINA = {
        BASE_REGEN_TIME = 2,
        BASE_REGEN_PERCENT = 10,
        -- TODO : as the combat versions
    },

    MANA = {
        BASE_REGEN_TIME = 2,
        COMBAT_REGEN_TIME = 5,
        BASE_REGEN_PERCENT = 10,
        COMBAT_REGEN_PERCENT = 5,
    },

    MF = {
        BASE_DECAY_TIME = 3,
        BASE_DECAY_PERCENT = 10,
    },
}

--[[ Connections ]]
--
local connectionRunning_Blocking = {}
local connectionRunning_Stamina = {}
local connectionRunning_Mana = {}
local connectionRunning_MF = {}

--[[ Functions ]]
--
local function WaitForAttributes(char, attributeList, timeout)
    timeout = timeout or 5
    local start = os.clock()

    while char.Parent do
        local allReady = true

        for _, attr in ipairs(attributeList) do
            if char:GetAttribute(attr) == nil then
                allReady = false
                break
            end
        end

        if allReady then
            return true
        end

        if os.clock() - start >= timeout then
            warn("Attributes not ready:", char, attributeList)
            return false
        end

        task.wait()
    end

    return false
end

local function onBlockingChanged(char)
    if char:GetAttribute("Blocking") > 0 and connectionRunning_Blocking[char] == nil then
        connectionRunning_Blocking[char] = true

        local signalConnection = nil
        signalConnection = char:GetAttributeChangedSignal("Blocking"):Connect(function()
            onBlockingChanged(char)
        end)

        coroutine.wrap(function()
            while char.Parent and char:GetAttribute("Blocking") > 0 do
                task.wait(1)
                
                local isBlocking = char:GetAttribute("IsBlocking")
                local lastStopTime = char:GetAttribute("LastStopTime") or 0
                local currentTime = tick()
                local DecreaseBlockingTime = CONFIG.BLOCKING.BASE_DECREASE_TIME
                local DecreaseAmount = CONFIG.BLOCKING.BASE_DECREASE_AMOUNT

                if not isBlocking and currentTime - lastStopTime >= DecreaseBlockingTime then
                    char:SetAttribute("Blocking", math.max(0, char:GetAttribute("Blocking") - DecreaseAmount))
                end
            end
            
            connectionRunning_Blocking[char] = nil
            if signalConnection then
                signalConnection:Disconnect()
            end
        end)()
    end
end

local function CheckForStatus(char)
    if not char or not char.Parent then
        return true
    end

    local Swing = char:GetAttribute("Swing")
    local Dodging = char:GetAttribute("Dodging")
    local IsEXSprinting = char:GetAttribute("IsEXSprinting")

    -- Only hard actions block regen now: swing, dodge, EX sprint. Sprinting and Blocking do NOT block (user asked - was annoying)
    if Swing or Dodging or IsEXSprinting then
        char:SetAttribute("StopTime_Stam", os.clock())
        return true
    end

    return false
end

local function StartStaminaRegen(char)
    if connectionRunning_Stamina[char] then
        return
    end
    if not char or not char.Parent then
        return
    end

    local stamina = char:GetAttribute("Stamina")
    local maxStamina = char:GetAttribute("MaxStamina")

    if stamina >= maxStamina then
        return
    end

    connectionRunning_Stamina[char] = true
    
    if not char:GetAttribute("StopTime_Stam") then
        char:SetAttribute("StopTime_Stam", os.clock())
    end

    task.spawn(function()
        while char.Parent and char:GetAttribute("Stamina") < char:GetAttribute("MaxStamina") do
            task.wait(0.5)

            local stopped = CheckForStatus(char)
            local lastStop = char:GetAttribute("StopTime_Stam") or os.clock()

            if not stopped and os.clock() - lastStop >= CONFIG.STAMINA.BASE_REGEN_TIME then
                local currentStam = char:GetAttribute("Stamina")
                local maxStam = char:GetAttribute("MaxStamina")
                local regenAmount = math.ceil(maxStam * (CONFIG.STAMINA.BASE_REGEN_PERCENT / 100))

                char:SetAttribute("Stamina", math.min(currentStam + regenAmount, maxStam))
                char:SetAttribute("StopTime_Stam", os.clock())
            end
        end

        connectionRunning_Stamina[char] = nil
    end)
end

local function StartMFDecay(char)
    if connectionRunning_MF[char] then
        return
    end
    if not char or not char.Parent then
        return
    end

    local mf = char:GetAttribute("MF")
    if not mf or mf <= 0 then
        return
    end

    connectionRunning_MF[char] = true

    if not char:GetAttribute("StopTime_MF") then
        char:SetAttribute("StopTime_MF", os.clock())
    end

    task.spawn(function()
        while char.Parent and (char:GetAttribute("MF") or 0) > 0 do
            task.wait(0.5)

            local lastStop = char:GetAttribute("StopTime_MF") or os.clock()

            if os.clock() - lastStop >= CONFIG.MF.BASE_DECAY_TIME then
                local currentMF = char:GetAttribute("MF") or 0
                local maxMF = char:GetAttribute("MaxMF") or 1
                local decayAmount = math.ceil(maxMF * (CONFIG.MF.BASE_DECAY_PERCENT / 100))
                char:SetAttribute("MF", math.max(0, currentMF - decayAmount))
                char:SetAttribute("StopTime_MF", os.clock())
            end
        end

        connectionRunning_MF[char] = nil
    end)
end

local function SetupCharacter(char)
    if not char then
        return
    end
    
    local ok = WaitForAttributes(char, { "Stamina", "MaxStamina" }, 6)
    if not ok then
        return
    end

    char:SetAttribute("StopTime_Stam", os.clock())

    char:GetAttributeChangedSignal("Stamina"):Connect(function()
        StartStaminaRegen(char)
    end)

    char:GetAttributeChangedSignal("Sprinting"):Connect(function()
        StartStaminaRegen(char)
    end)

    char:GetAttributeChangedSignal("IsEXSprinting"):Connect(function()
        StartStaminaRegen(char)
    end)

    char:GetAttributeChangedSignal("MF"):Connect(function()
        StartMFDecay(char)
    end)

    StartStaminaRegen(char)
end

local function SetupManaRegen(char)
end

StatusEffectsModule.Signal:Connect(function(char, npc, action, effectName)
    print("Signal Gotten!")

    if action ~= "StatusEffectAdded" then return end

    local plr = game.Players:GetPlayerFromCharacter(char)
    local identifier = plr or npc

    local hum: Humanoid = char:FindFirstChildOfClass("Humanoid")
    local effectData = CombatData.ActiveStatusEffects[identifier] and CombatData.ActiveStatusEffects[identifier][effectName]

    if not effectData then return end

    local duration = effectData.Duration
    local stacks = effectData.Stacks
    local startTime = tick()

    local function isExpired()
        local current = CombatData.ActiveStatusEffects[identifier]
        if not current or not current[effectName] then
            return true
        end
        return (tick() - startTime) >= duration
    end

    if effectName == "Burn" then
        print("Burn active!")
        local damage = 25 * 2 ^ (1 - stacks)
        local clock = Timer.new(1)

        clock.Tick:Connect(function()
            if isExpired() then
                clock:Destroy()
                StatusEffectsModule.RemoveStatusEffect(char, npc, effectName)
                return
            end
            hum:TakeDamage(damage)
        end)
        clock:Start()
    end

    if effectName == "Bleed" then
        print("Bleed Now")
        local dps = 2 * 2 ^ (1 - stacks)
        local clock = Timer.new(0.5)

        clock.Tick:Connect(function()
            if isExpired() then
                clock:Destroy()
                StatusEffectsModule.RemoveStatusEffect(char, npc, effectName)
                return
            end
            hum:TakeDamage(dps)
        end)
        clock:Start()
    end

    if effectName == "Poison" then
        print("Poison Now")
        local clock = Timer.new(3)

        clock.Tick:Connect(function()
            if isExpired() then
                clock:Destroy()
                StatusEffectsModule.RemoveStatusEffect(char, npc, effectName)
                return
            end

            local maxHealth = hum.MaxHealth
            local dps = ((5 + stacks) / 100) * maxHealth

            if hum.Health - dps <= 0 then
                clock:Destroy()
                StatusEffectsModule.RemoveStatusEffect(char, npc, effectName)
                return
            end
            hum:TakeDamage(dps)
        end)
        clock:Start()
    end
end)

if workspace:FindFirstChild("NPC") then
    for _, v in ipairs(workspace.NPC:GetChildren()) do
        if v:IsA("Model") and v:FindFirstChild("Humanoid") then
            SetupCharacter(v)
            v:GetAttributeChangedSignal("Blocking"):Connect(function()
                onBlockingChanged(v)
            end)
        end
    end
end

game.Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char)
        local PLR = PLRModule.GetPLRFromPlayer(plr)
        while not PLR or not PLR.IsReady do
            task.wait(0.1)
            PLR = PLRModule.GetPLRFromPlayer(plr)
        end

        SetupCharacter(char)
        char:GetAttributeChangedSignal("Blocking"):Connect(function()
            onBlockingChanged(char)
        end)
    end)
end)

if workspace:FindFirstChild("NPC") then
    workspace.NPC.ChildAdded:Connect(function(child)
        if child:IsA("Model") and child:FindFirstChild("Humanoid") then
            SetupCharacter(child)
            child:GetAttributeChangedSignal("Blocking"):Connect(function()
                onBlockingChanged(child)
            end)
        end
    end)
end