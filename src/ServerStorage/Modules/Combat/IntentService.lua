local IntentService = {}

local Players = game:GetService("Players")
local SS = game:GetService("ServerStorage")
local SSModules = SS.Modules

-- Event-driven intent: fires on every SetIntent so NPC FSM can react instantly (A with 0.2215 human delay)
IntentService.IntentChanged = Instance.new("BindableEvent")
IntentService.IntentTick = {} :: {[Model]: number}

local function GetCombatObject(char, npc)
    local plr = Players:GetPlayerFromCharacter(char)
    if plr then
        local success, PlrObjectService = pcall(require, SSModules.Objects.plr)
        if success then
            return PlrObjectService.GetPLRFromPlayer(plr)
        end
        return nil
    end
    return npc
end

function IntentService.SetIntent(char, npc, intent)
    local obj = GetCombatObject(char, npc)
    if obj then
        obj.Intent = intent
    end
    if char then
        char:SetAttribute("Intent", intent)
        IntentService.IntentTick[char] = os.clock()
        char:SetAttribute("IntentTick", os.clock())
    end
    -- fire even if char is NPC — only pass Instances/strings (npc table is cyclic, BindableEvent can't serialize it)
    IntentService.IntentChanged:Fire(char, intent)
end

function IntentService.GetIntent(char, npc)
    local obj = GetCombatObject(char, npc)
    if obj then
        return obj.Intent
    end
    if char then
        return char:GetAttribute("Intent")
    end
    return nil
end

return IntentService