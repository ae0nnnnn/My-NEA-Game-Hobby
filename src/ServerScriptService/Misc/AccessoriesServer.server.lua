local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataManager = require(script.Parent.Parent.Data.Modules.DataManager)
local AccessoriesModule = require(SS.Modules.Other.AccessoriesManager)
local ItemInfo = require(SS.Modules.Dictionaries.ItemInfo)
local PLROBJ = require(SS.Modules.Objects.plr)
local Template = require(ServerScriptService.Data.Template)



local Events = RS.Events
local AccessoryEvent = Events.AccessoryEvent
local InventoryEvent : RemoteEvent = Events.InventoryEvent or Instance.new("RemoteEvent", Events)
InventoryEvent.Name = "InventoryEvent"

-- Player Acessory Initialization has been moved to the my custom PLR object  .new function

AccessoryEvent.OnServerEvent:Connect(function(plr:Player, action : string, uid :string)
	if action == "EquipAccessory" then
		local char = plr.Character
		if char:GetAttribute("InCombat") then
			return
		end -- Cant change accessories in combat
		local obj = PLROBJ.GetPLRFromPlayer(plr)
		if not obj then return end 


		local _, entry = DataManager.FindItembyUID(obj, uid)

		if not entry then return end 

		local info = ItemInfo.getStats(entry.Name)
		if not info or info.Type ~= "Accessory" then return end 

		local slot = info.EquipSlot

		if not slot then return end 
			local removed = DataManager.RemoveItembyUID(obj, uid)
		if not removed then return end 
		DataManager.EquipAccessorySwap(obj, slot, removed)
		-- nuke puppet wherever it lives (Backpack or held in Character)
		local bp = plr:FindFirstChildOfClass("Backpack")
		if bp then
			local puppet = bp:FindFirstChild(uid)
			if puppet then puppet:Destroy() end 
		end
		local chr = plr.Character
		if chr then
			local held = chr:FindFirstChild(uid)
			if held then held:Destroy() end
			-- also catch Humanoid-held Tool edge
			local hum = chr:FindFirstChildOfClass("Humanoid")
			if hum then pcall(function() hum:UnequipTools() end) end
		end


		AccessoriesModule.EquipAccessory(char, removed.Name)
		InventoryEvent:FireClient(plr, "InventoryChanged", obj.Data.Inventory, obj.Data.Accessories)
	end 


		if action == "UnEquipAccessory" then
		local char = plr.Character
		if not char then return end
		if char:GetAttribute("InCombat") then return end
		local obj = PLROBJ.GetPLRFromPlayer(plr)
		if not obj then return end
		local slot = uid
		local entry = DataManager.UnEquipAccessoryToInventory(obj, slot)

		if not entry then return end 
		AccessoriesModule.UnequipAccessory(char, entry.Name)
		-- respawn puppet so Bag/Hotbar can find it again
		local bp = plr:FindFirstChildOfClass("Backpack")
		if bp and not bp:FindFirstChild(entry.UID) then
			local ToolBox = RS.Tools
			local template = ToolBox:FindFirstChild(entry.Name, true) :: Tool?
			if template then
				local puppet: Tool = template:Clone()
				puppet.Name = entry.UID
				puppet:SetAttribute("BaseName", entry.Name)
				puppet:SetAttribute("Count", entry.Count or 1)
				for _, v in ipairs(puppet:GetChildren()) do
					if v:IsA("ValueBase") and (v.Name == "slotIn" or v.Name == "ToolType" or v.Name == "TrueName" or v.Name == "AccessoryType") then v:Destroy() end
				end
				puppet.Parent = bp
			end
		end
		InventoryEvent:FireClient(plr, "InventoryChanged", obj.Data.Inventory, obj.Data.Accessories)
	end
	
end)

-- Player accessory cleanup  on remove has been moved to the my custom PLR object :Destroy function
