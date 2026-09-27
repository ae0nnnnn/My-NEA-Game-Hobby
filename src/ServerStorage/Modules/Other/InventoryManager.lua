--TODO: Create a item type that i can use  akso nake tghat that ra	ther than going to the data manager directly it uses the player obj instead
--TODO: make cacrual UIDs rather than random num concationation
local InventoryManager = {}
local RS = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local TS = game:GetService("TweenService")


local Data = require(RS.Modules.Movement.Data)
local DataManager = require(ServerScriptService.Data.Modules.DataManager)
local PLR = require(SS.Modules.Objects.plr)
local ServerTypes = require(SS.Modules.ServerTypes)
local ItemInfo = require(RS.Modules.Dictionaries.ItemInfo)
local Template = require(ServerScriptService.Data.Template)

local Events = RS.Events
local InventoryEvent = Events.InventoryEvent

local ToolBox = RS.Tools
local Models = RS.Models
local ItemFolder: Folder = ToolBox.Items
local ItemModelFolder = Models.Items
local ActiveItemFolder = workspace.ActiveItems

local VFX_GROUP = "VFX_Models"

InventoryManager.OrphanedItems = {} :: { [string]: Template.ItemData }

function InventoryManager.AddItem(plr: Player, payload: DataManager.ItemPayload)
	local obj = PLR.GetPLRFromPlayer(plr)
	if not obj then
		return
	end

	local entry = DataManager.AddItemData(obj, payload)
	if not entry then
		return
	end
	local bp = plr:FindFirstChildOfClass("Backpack")
	if not bp then
		return
	end
	local template = ItemFolder:FindFirstChild(payload.Name, true) :: Tool?

	if not template then
		return
	end
	local newPuppet: Tool = template:Clone()
	newPuppet.Name = entry.UID
	newPuppet:SetAttribute("BaseName", payload.Name)
	newPuppet:SetAttribute("Count", entry.Count)
	for _, v in ipairs(newPuppet:GetChildren()) do
		if
			v:IsA("ValueBase")
			and (v.Name == "slotIn" or v.Name == "ToolType" or v.Name == "TrueName" or v.Name == "AccessoryType")
		then
			v:Destroy()
		end
	end
	newPuppet.Parent = bp
	InventoryEvent:FireClient(plr, "InventoryChanged", obj.Data.Inventory, obj.Data.Accessories)
end

function InventoryManager.AddOrphanItem(plr: Player, uid: string): Template.ItemData?
	if not uid then
		return nil
	end
	local obj = PLR.GetPLRFromPlayer(plr)
	if not obj then
		return nil
	end
	local stored = InventoryManager.OrphanedItems[uid]
	if not stored then
		return nil
	end
	if stored.IsBound and stored.BoundUserId ~= plr.UserId then
		return nil
	end

	local _, clash = DataManager.FindItembyUID(obj, uid)
	if clash then
		return nil
	end
	local info = ItemInfo.getStats(stored.Name)
	if info and info.StackType == "Stackable" then
		if not info.MaxStack then
			warn("Missing MaxStack for stackable " .. stored.Name)
			return nil
		end

		local hasStack = false
		local hasSpace = false
		local targetEntry: Template.ItemData? = nil
		for _, entry in ipairs(obj.Data.Inventory) do
			if entry.Name == stored.Name then
				hasStack = true
				if (entry.Count or 0) < info.MaxStack then
					hasSpace = true
					targetEntry = entry
					break
				end
			end
		end

		if hasStack and not hasSpace then
			return nil
		end

		if targetEntry then
			local space = info.MaxStack - (targetEntry.Count or 0)
			local storedCount = stored.Count or 1
			local addCount = math.min(space, storedCount)
			targetEntry.Count = (targetEntry.Count or 0) + addCount
			-- update existing puppet's Count attribute
			local bp = plr:FindFirstChildOfClass("Backpack")
			if bp then
				local puppet = bp:FindFirstChild(targetEntry.UID) :: Tool?
				if puppet then
					puppet:SetAttribute("Count", targetEntry.Count)
				end
			end
			if storedCount > space then
				-- partial pickup: leave remainder in world
				stored.Count = storedCount - addCount
				-- keep OrphanedItems[uid] = stored with new count, don't nuke
				-- update world mesh attribute if it exists
				local worldItem = workspace.ActiveItems:FindFirstChild(uid)
				if worldItem then
					worldItem:SetAttribute("Count", stored.Count)
				end
				InventoryEvent:FireClient(plr, "InventoryChanged", obj.Data.Inventory, obj.Data.Accessories)
				return targetEntry
			else
				InventoryManager.OrphanedItems[uid] = nil
				InventoryEvent:FireClient(plr, "InventoryChanged", obj.Data.Inventory, obj.Data.Accessories)
				return targetEntry
			end
		end
	end

	-- non-stackable OR first stack: insert stored as new entry and update tables
	stored.Location = DataManager.FirstFreeHotBarSlot(obj) or -1
	table.insert(obj.Data.Inventory, stored)
	InventoryManager.OrphanedItems[uid] = nil
	-- create new puppet for the new entry
	local bp = plr:FindFirstChildOfClass("Backpack")
	if bp then
		local template = ItemFolder:FindFirstChild(stored.Name, true) :: Tool?
		if template then
			local newPuppet: Tool = template:Clone()
			newPuppet.Name = stored.UID
			newPuppet:SetAttribute("BaseName", stored.Name)
			newPuppet:SetAttribute("Count", stored.Count)
			for _, v in ipairs(newPuppet:GetChildren()) do
				if
					v:IsA("ValueBase")
					and (
						v.Name == "slotIn"
						or v.Name == "ToolType"
						or v.Name == "TrueName"
						or v.Name == "AccessoryType"
					)
				then
					v:Destroy()
				end
			end
			newPuppet.Parent = bp
		end
	end
	InventoryEvent:FireClient(plr, "InventoryChanged", obj.Data.Inventory, obj.Data.Accessories)
	return stored
end

function InventoryManager.RemoveItem(obj: ServerTypes.PLR, uid: string): boolean
	if not obj or not obj.Data then
		return false
	end

	local entryIdx, entry = nil, nil

	entryIdx, entry = DataManager.FindItembyUID(obj, uid)
	if not entryIdx then
		return false
	end
	table.remove(obj.Data.Inventory, entryIdx)
	local plr = obj.Player
	local bp = plr:FindFirstChildOfClass("Backpack")

	if bp then
		local puppet = bp:FindFirstChild(uid)
		if puppet then
			puppet:Destroy()
		end
	end

	local char = plr.Character

	if char then
		local held = char:FindFirstChild(uid)
		if held then
			held:Destroy()
		end
	end
	return true
end


function InventoryManager.DropItem(obj: ServerTypes.PLR, uid: string, count: number)
	local _, entry = DataManager.FindItembyUID(obj, uid)
	if not entry or entry.IsBound then
		warn("The UID provided doesn't have an item or the Item is bound to the plr")
		return
	end
	local info = ItemInfo.getStats(entry.Name)
	if info and info.Type == "Skill" then return end
	local plr = obj.Player
	local char = plr.Character
	if not char then warn("Character not found for player: " .. plr.Name) return end
	local HRP = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not HRP then warn("HumanoidRootPart not found for player: " .. plr.Name) return end

	count = math.clamp(math.floor(count or 1), 1, entry.Count or 1)
	local isPartial = (info and info.StackType == "Stackable") and count < (entry.Count or 1)

	local dropUID: string
	local dropCount: number
	if isPartial then
		entry.Count = (entry.Count or 1) - count
		dropCount = count
		dropUID = game:GetService("HttpService"):GenerateGUID(false)
		local bp = plr:FindFirstChildOfClass("Backpack")
		local puppet = bp and bp:FindFirstChild(uid) or nil
		local held = char:FindFirstChild(uid)
		local target = puppet or held
		if target then target:SetAttribute("Count", entry.Count) end
	else
		dropCount = entry.Count or 1
		dropUID = entry.UID
	end

	-- grouping: merge into nearby pile if same Name and space
	local PILE_RADIUS = 8
	local pileUID: string? = nil
	local pilePart: MeshPart? = nil
	if info and info.StackType == "Stackable" then
		local dropPos = HRP.CFrame * CFrame.new(0, 0, -5)
		for _, part in ipairs(ActiveItemFolder:GetChildren()) do
			if part:IsA("BasePart") and CS:HasTag(part, "Item") then
				local orphan = InventoryManager.OrphanedItems[part.Name]
				if orphan and orphan.Name == entry.Name then
					if (part.Position - dropPos.Position).Magnitude <= PILE_RADIUS then
						local maxStack = info.MaxStack or 999
						if (orphan.Count or 0) + dropCount <= maxStack then
							pileUID = part.Name
							pilePart = part :: MeshPart
							break
						end
					end
				end
			end
		end
	end

	if pileUID and pilePart then
		local orphan = InventoryManager.OrphanedItems[pileUID] :: Template.ItemData
		orphan.Count = (orphan.Count or 0) + dropCount
		pilePart:SetAttribute("Count", orphan.Count)
		-- subtle pulse, not Back spaz
		local s = pilePart.Size
		TS:Create(pilePart, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = s * 1.08}):Play()
		task.delay(0.18, function()
			if pilePart.Parent then TS:Create(pilePart, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Size = s}):Play() end
		end)
		if not isPartial then InventoryManager.RemoveItem(obj, uid) end
		InventoryEvent:FireClient(plr, "InventoryChanged", obj.Data.Inventory, obj.Data.Accessories)
		return
	end

	-- no pile -> spawn new bobbing part
	local stored: Template.ItemData = {
		Name = entry.Name,
		UID = dropUID,
		Stat_Rolls = entry.Stat_Rolls,
		Count = dropCount,
		Location = nil,
		Modifiers = entry.Modifiers,
		ArtefactType = entry.ArtefactType,
		IsBound = entry.IsBound,
		BoundUserId = entry.BoundUserId,
	}
	InventoryManager.OrphanedItems[dropUID] = stored

	local droppedItem: MeshPart = ItemModelFolder:FindFirstChild(entry.Name, true):Clone()
	droppedItem.Name = dropUID
	droppedItem:SetAttribute("Count", dropCount)
	droppedItem:SetAttribute("BaseName", entry.Name)
	droppedItem.CollisionGroup = VFX_GROUP
	local Model: Model = Instance.new("Model")
	local Highlight = Instance.new("Highlight")
	Highlight.OutlineColor = Color3.new(0.992157, 0.992157, 0.992157)
	Highlight.FillTransparency = 1
	Highlight.OutlineTransparency = 0.5
	Highlight.Parent = droppedItem
	Model.Name = entry.Name .. "_Model"
	droppedItem.Parent = Model
	Model.Parent = ActiveItemFolder
	CS:AddTag(droppedItem, "Item")
	droppedItem.CustomPhysicalProperties = PhysicalProperties.new(0.3, 1, 0, 1, 0)
	droppedItem.CFrame = HRP.CFrame * CFrame.new(0, 0, -5)
	Model:ScaleTo(0.65)
	if not isPartial then
		InventoryManager.RemoveItem(obj, uid)
	else
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then pcall(function() hum:UnequipTools() end) end
		local held = char:FindFirstChild(uid)
		if held then held:Destroy() end
	end
	droppedItem.Anchored = true
	droppedItem.CanCollide = false
	droppedItem.CanTouch = true
	droppedItem.CanQuery = true
	droppedItem.Parent = ActiveItemFolder
	Model:Destroy()

	local BOB_HEIGHT = 0.25 -- slow small
	local BOB_SPEED = 0.9 -- ~7s cycle
	local startCF = droppedItem.CFrame
	local RS = game:GetService("RunService")
	local conn: RBXScriptConnection? = nil
	conn = RS.Heartbeat:Connect(function()
		if not droppedItem.Parent or not InventoryManager.OrphanedItems[dropUID] then
			if conn then conn:Disconnect() conn = nil end
			return
		end
		droppedItem.CFrame = startCF * CFrame.new(0, math.sin(tick() * BOB_SPEED) * BOB_HEIGHT, 0)
	end)
	task.delay(300, function()
		if conn then conn:Disconnect() conn = nil end
		if InventoryManager.OrphanedItems[dropUID] then
			InventoryManager.OrphanedItems[dropUID] = nil
			if droppedItem and droppedItem.Parent then droppedItem:Destroy() end
		end
	end)
	InventoryEvent:FireClient(plr, "InventoryChanged", obj.Data.Inventory, obj.Data.Accessories)
end


function InventoryManager.LoadInventory(plr: Player)
	local char = plr.Character
	if not char then return end
	local backpack = plr:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	local CurrentSlot = char:GetAttribute("CurrentSlot") or "SLOT_1"
	local profile = DataManager.Profiles[plr]
	if not profile then return end
	local slotData = profile.Data[CurrentSlot] or profile.Data["SLOT_"..tostring(CurrentSlot)]
	if not slotData or not slotData.Inventory then return end

	for _, entry in ipairs(slotData.Inventory) do
		local existing = backpack:FindFirstChild(entry.UID) :: Tool?
		if existing then
			existing:SetAttribute("BaseName", entry.Name)
			existing:SetAttribute("Count", entry.Count or 1)
			for _, v in ipairs(existing:GetChildren()) do
				if v:IsA("ValueBase") and (v.Name == "slotIn" or v.Name == "ToolType" or v.Name == "TrueName" or v.Name == "AccessoryType") then
					v:Destroy()
				end
			end
		else
			local template = ToolBox:FindFirstChild(entry.Name, true) :: Tool? -- was ItemFolder, now ToolBox so Skills also found
			if template then
				local puppet: Tool = template:Clone()
				puppet.Name = entry.UID
				puppet:SetAttribute("BaseName", entry.Name)
				puppet:SetAttribute("Count", entry.Count or 1)
				for _, v in ipairs(puppet:GetChildren()) do
					if v:IsA("ValueBase") and (v.Name == "slotIn" or v.Name == "ToolType" or v.Name == "TrueName" or v.Name == "AccessoryType") then
						v:Destroy()
					end
				end
				puppet.Parent = backpack
			else
				warn("[LoadInventory] missing template for", entry.Name)
			end
		end
	end

	-- SKILLS same backpack puppets
	if slotData.Skills then
		for _, s in ipairs(slotData.Skills) do
			local existing = backpack:FindFirstChild(s.Name) :: Tool?
			if not existing then
				local template = ToolBox:FindFirstChild(s.Name, true) :: Tool?
				if template then
					local puppet: Tool = template:Clone()
					puppet.Name = s.Name
					puppet:SetAttribute("BaseName", s.Name)
					puppet.Parent = backpack
				else
					warn("[LoadInventory] missing skill template for", s.Name)
				end
			end
		end
	end

	local obj = PLR.GetPLRFromPlayer(plr)
	if obj then
		InventoryEvent:FireClient(plr, "InventoryChanged", obj.Data.Inventory, obj.Data.Accessories)
	end
end
return InventoryManager
