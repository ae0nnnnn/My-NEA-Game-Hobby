local HS= game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Data = require(ReplicatedStorage.Modules.Movement.Data)
local Template = require(ServerScriptService.Data.Template)


local DataManager = {}


type ProfileData = Template.ProfileData
export type SlotData = Template.SlotData
export type GenData = Template.GeneralData
export type Settings = Template.Settings

type DumbPLR = {Data : Template.SlotData}


-- Store profiles from  ProfileStore
export type Profile = {
    Data: ProfileData,
    AddUserId: (self: Profile, userId: number) -> (),
    Reconcile: (self: Profile) -> (),
    EndSession: (self: Profile) -> (),
    OnSessionEnd: RBXScriptSignal,
}


export type ItemPayload = {
    Name: string,
    Count:number?,
    Stat_Rolls: {[string]: {[string]: number}}?,
    Modifiers: string?,
    ArtefactType: string?,
    IsBound: boolean?,
    BoundUserId: number?,
}

DataManager.Profiles = {} :: { [Player]: Profile }



function DataManager.IncreaseStat(plr,statName) -- This function handles the increase of stats,
    local profile = DataManager.Profiles[plr]
    if profile then
        local char = plr.Character
        local currentSlot = char:GetAttribute("CurrentSlot")
        local currentValue = profile.Data[currentSlot][statName]

        if currentValue < 99 then 
            profile.Data[currentSlot][statName] = currentValue + 1
        else
            print("You can't invest anymore into", statName)
        end
    end
end



function DataManager.IncreaseSkillPoints(plr,amount)
    local profile = DataManager.Profiles[plr]
    if profile then
        local char = plr.Character
        local currentSlot = char:GetAttribute("CurrentSlot")
        profile.Data[currentSlot].SkillPoints = profile.Data[currentSlot].SkillPoints + amount
    end
end

function DataManager.ChangeHairColor(plr,newColor: Color3)
    local profile = DataManager.Profiles[plr]
    if profile then
        local char = plr.Character
        local currentSlot = char:GetAttribute("CurrentSlot")
        local SlotData:SlotData = profile.Data[currentSlot]
        SlotData.Appearance.Hair_Colour = {
            Red = newColor.R,
            Green = newColor.G,
            Blue = newColor.B
        }
    end
end

function DataManager.ChangeElemment(plr,newValue) -- This function will handle the changing of the player's moveset
    local profile = DataManager.Profiles[plr]
    if profile then
        local char = plr.Character
        local currentSlot = char:GetAttribute("CurrentSlot")
        profile.Data[currentSlot].Element = newValue
    end
    
end

function DataManager.AddExperience(plr,amount)
    local profile = DataManager.Profiles[plr]
    if profile then
        local char = plr.Character
        local currentSlot = char:GetAttribute("CurrentSlot")
        profile.Data[currentSlot].Experience = profile.Data[currentSlot].Experience + amount
    end
end

function DataManager.UpdateAccessories(PLR :DumbPLR, accessoryType, accessoryItem: Template.ItemData?)
    if not PLR or not PLR.Data then return end 
    if accessoryItem ~= nil then
        accessoryItem.Location = nil
    end
    PLR.Data.Accessories[accessoryType] = accessoryItem
end


function DataManager.FirstFreeHotBarSlot(plr:DumbPLR):number?
    if not plr or not plr.Data then return nil end 

    local used = {}

    for _, entry in ipairs(plr.Data.Inventory) do
        if entry.Location and entry.Location >= 1 and entry.Location <= 10 then
            used[entry.Location] = true
        end
    end

    if plr.Data.Skills then
        for _,s in ipairs(plr.Data.Skills) do 
             if s.Location and s.Location >= 1 and s.Location <= 10 then
                used[s.Location] = true
             end
        end
    end

    for i =1,10 do
        if not used[i] then return i end
    end

    return nil
end

function DataManager.AddItemData(plr: DumbPLR, payload: ItemPayload) : Template.ItemData?
   if not plr or not plr.Data or not payload or not payload.Name then return nil end 

   local slot = DataManager.FirstFreeHotBarSlot(plr) or -1
   
    local item : Template.ItemData = {
        Name = payload.Name,
        UID = HS:GenerateGUID(false),
        Stat_Rolls = payload.Stat_Rolls or {},
        Count = payload.Count or 1,
        Location = slot,
        Modifiers = payload.Modifiers,
        ArtefactType = payload.ArtefactType,
        IsBound = payload.IsBound or false,
        BoundUserId = payload.BoundUserId,
    }
    table.insert(plr.Data.Inventory, item)
    return item 
end

function DataManager.FindItembyUID(plr: DumbPLR,uid:string) : (number?, Template.ItemData?)
    if not plr or not plr.Data then return nil,nil end 

    for i, entry in ipairs(plr.Data.Inventory) do 
        if entry.UID == uid then
            return i,entry
        end
    end


    return nil,nil
end

function DataManager.RemoveItembyUID(plr:DumbPLR, uid:string) :Template.ItemData?
    local idx, entry = DataManager.FindItembyUID(plr, uid)
    if not idx or not entry then return nil end 
    table.remove(plr.Data.Inventory,idx)
    return entry
end


function DataManager.UnEquipAccessoryToInventory(plr:DumbPLR, slot:string) : Template.ItemData?
    if not plr or not plr.Data or not slot then return nil end 

    if plr.Data.Accessories[slot] == nil and (slot ~= "Hat" and slot ~= "Face" and slot ~= "Torso" and slot ~= "Legs" and slot ~= "Artefacts" and slot ~= "Rings" and slot ~= "Collar") then
        return nil
    end

    local entry : Template.ItemData = plr.Data.Accessories[slot]
    if not entry then return nil end 
    entry.Location  = -1
    table.insert(plr.Data.Inventory, entry)
    plr.Data.Accessories[slot] = nil
    return entry
end


function DataManager.EquipAccessorySwap(plr:DumbPLR, slot:string, newItem: Template.ItemData) : Template.ItemData?
    if not plr or not plr.Data or not slot or not newItem then return nil end 

    local old: Template.ItemData = plr.Data.Accessories[slot]

    if old then
        old.Location = -1 
        table.insert(plr.Data.Inventory, old)
    end
    DataManager.UpdateAccessories(plr, slot, newItem)

    return old
end


function DataManager.SetLocation(plr:DumbPLR, Itemtype:string, uid:string, newLocation:number):boolean
    if not plr or not plr.Data then return false end 

    if newLocation ~= -1 and (typeof(newLocation) ~= "number" or newLocation < 1 or newLocation> 10 or newLocation% 1 ~= 0) then
        return false
    end

    local entry = nil

    if Itemtype == "Item" then
        local _, found = DataManager.FindItembyUID(plr, uid)
        entry = found

    elseif Itemtype == "Skill" then
        for _,s in ipairs(plr.Data.Skills) do 
            if s.Name == uid then entry = s break end 
        end
           if entry and entry.Location == nil then return false end
    else 
        return false
    end

    if not entry then return false end 
    if entry.Location == newLocation then return true end 
    if newLocation == -1 then
        entry.Location = -1
        return true
    end

    local oldLocation = entry.Location

    for _, inv in ipairs(plr.Data.Inventory) do 
        if inv ~= entry and inv.Location == newLocation then
            inv.Location = oldLocation
            entry.Location = newLocation
            return true
        end
    end

    for _,s in ipairs(plr.Data.Skills) do
        if s ~= entry and s.Location == newLocation then
            s.Location = oldLocation
            entry.Location = newLocation
            return true
        end
    end
    entry.Location = newLocation
    return true
end







   



--[[
 This is the rules for handeling player data
 1. Always access player data through DataManager.Profiles[player]
 2. Do not store player data locally in other modules, always access it when needed
 3. When modifying player data, ensure you are modifying the correct slot by checking the "Current_Slot" attribute on the player's character
 4. Modify data here only, do not create new data stores in other modules
]]





return DataManager