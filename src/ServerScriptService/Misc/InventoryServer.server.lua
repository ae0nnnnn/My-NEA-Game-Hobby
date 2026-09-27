local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local InventoryManager = require(SS.Modules.Other.InventoryManager)
local Helper = require(SS.Modules.Other.Helpful)
local DataManager = require(ServerScriptService.Data.Modules.DataManager)
local PLR = require(SS.Modules.Objects.plr)

local Events = RS.Events
local InventoryEvent = Events.InventoryEvent

local GetInventory = Events:FindFirstChild("GetInventory") or Instance.new("RemoteFunction", Events)
GetInventory.Name = "GetInventory"

GetInventory.OnServerInvoke = function(plr)
	local obj = PLR.GetPLRFromPlayer(plr)
	if not obj or not obj.Data then return {}, {} end
	-- client expects (Inventory, Skills) — see InventoryClient.client.lua:213
	return obj.Data.Inventory, obj.Data.Skills
end


  --[[
TODO : add validation here 
]]





local function PickupItem(item: MeshPart)
    if item.Parent ~= workspace.ActiveItems then return end
    
    local touchConn
    touchConn = item.Touched:Connect(function(hit)
        local char = hit.Parent
        if char and char:FindFirstChildOfClass("Humanoid") then
            local plr = game.Players:GetPlayerFromCharacter(char)
            if plr then
                local uid = item.Name
                local result = InventoryManager.AddOrphanItem(plr, uid)
                if not result then return end -- full stacks or bound/clash: leave world item
                -- partial pickup leaves OrphanedItems[uid] alive with remainder
                if InventoryManager.OrphanedItems and InventoryManager.OrphanedItems[uid] then
                    -- remainder left behind, keep world item (already updated Count attr)
                    print("Partial Item Get! remainder:", InventoryManager.OrphanedItems[uid].Count)
                    return
                end
                print("Item Get!")
                item:Destroy()
                touchConn:Disconnect()
            end
        end
    end)
end
for _, item in ipairs(CS:GetTagged("Item")) do
    PickupItem(item)
end


CS:GetInstanceAddedSignal("Item"):Connect(PickupItem)





InventoryEvent.OnServerEvent:Connect(function(plr, action, ...)
    local char:Model = plr.Character  
    local obj = PLR.GetPLRFromPlayer(plr)
    if not char or not obj then return end
    if action == "Drop" then
        local uid,Count = ...
        if Helper.CheckForAttributes(char, true, true, true, nil, false, true, true, true) then return end
        if char:GetAttribute("InCombat") then return end  -- We cant drop stuff in combat
        if type(uid) ~= "string" then return end
        if type(Count) ~= "number" then Count = 1 end
        Count = math.floor(Count)
        if Count < 1 then return end
        InventoryManager.DropItem(obj, uid, Count)
    end

    if action == "HotbarUpdate" then
        local Itemtype ,uid, newLocation = ...
        if type(Itemtype) ~= "string" or type(uid) ~= "string" then return end 
        if type(newLocation) ~= "number" then return end 
        local pass = DataManager.SetLocation(obj, Itemtype, uid, newLocation)
        if not pass then return end 
        InventoryEvent:FireClient(plr, "InventoryChanged", obj.Data.Inventory, obj.Data.Accessories)
    end

end)
   





