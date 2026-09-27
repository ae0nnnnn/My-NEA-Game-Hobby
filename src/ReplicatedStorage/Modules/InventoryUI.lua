local module = {}

local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local RSModules = RS.Modules
local ItemInfo = require(RSModules.Dictionaries.ItemInfo)

local Events = RS.Events
local AccessoryEvent = Events.AccessoryEvent
local InventoryEvent = Events.InventoryEvent
local skillevent = Events.SkillCast

local slotsToNums = {
	["SLOT1"] = 1,
	["SLOT2"] = 2,
	["SLOT3"] = 3,
	["SLOT4"] = 4,
	["SLOT5"] = 5,
	["SLOT6"] = 6,
	["SLOT7"] = 7,
	["SLOT8"] = 8,
	["SLOT9"] = 9,
	["SLOT0"] = 10,
}

local currentFrameBeingHoveredOn = nil :: Instance?
local currentItemSelected = nil :: Tool?
local isDraggingItem = false

local ItemDataTemplate =
	{ --- Yes Yes i know having this means that i would have to update both at once and idc its only for type checking
		["Name"] = "", --> the actual name of the item
		["UID"] = "", -->  UILD for when inventory manager creates a new item
		["Stat_Rolls"] = {} :: { [string]: { [string]: number } }?, --> the rolls based on rarity that the item got basically for every tick in each rarity.Subsats the item us given those substat bonus (when created) per tic
		["ArtefactType"] = nil :: string?, --> basically for the Artefact accesoires there are three types Normal, Deformed, Refined --> though i wouild explain what these do in the item doc once i get to it
		["Count"] = 1, --> number gotten duh
		["Location"] = nil :: number?, --> The number slot in the hotbar (if set to -1 the location id the main inventory)
		["Modifiers"] = nil :: string?, --> one modifer per item
		["IsBound"] = false, -- If the item is bound to the player
		["BoundUserId"] = nil :: number?, -- this is the plr that the item uis bound to if the active plr holding the item is different kick the plr and void the item
	}

local SkillData = {
	["Name"] = "",
	["Location"] = nil :: number?, --> The number slot in the hotbar (if set to -1 the location id the main inventory and nil means that the item is either not set up  therefore is most likely bugged  (skills cant be banked) and 1,2,3,4,5,6,7,8,9,10 means hotbar 1,2,3,4,5,6,7,8,9,10
	["Modifiers"] = nil :: { string }?, --> the modifers the skill got infused with
	["Level"] = 1,
}

export type ItemData = typeof(ItemDataTemplate)
export type SkillData = typeof(SkillData)

function module.TriggerSkill(skillName)
	print("help me")
	skillevent:FireServer(skillName)
end

function module.HoverFrameChange(toggle, frame)
	if toggle == true then
		currentFrameBeingHoveredOn = frame
	else
		currentFrameBeingHoveredOn = nil
	end
end

function module.BagLoad(bag, backpack, inventory, skills, itemTemplate)
	local bagUIDs = {}
	for _, entry in ipairs(inventory) do
		if entry.Location == -1 then
			bagUIDs[entry.UID] = true
		end
	end
	for _, s in ipairs(skills) do
		if s.Location == -1 then
			bagUIDs[s.Name] = true
		end
	end

	-- Hide frames not in bag (show only bagUIDs)
	for _, desc in pairs(bag.ScrollingFrame:GetDescendants()) do
		if desc:IsA("Frame") and desc:FindFirstChild("itemImage") then
			desc.Visible = bagUIDs[desc.Name] == true
		end
	end

	-- Inventory bag items: entry.Location == -1
	for _, entry in ipairs(inventory) do
		if entry.Location == -1 then
			local existing = bag.ScrollingFrame:FindFirstChild(entry.UID, true)
			if existing then
				existing.Visible = true
			else
				local stats = ItemInfo.getStats(entry.Name)
				local category = stats and stats.Type or "Items"
				local newItemFrame = itemTemplate:Clone()
				newItemFrame.Name = entry.UID
				local puppet = backpack:FindFirstChild(entry.UID)
				newItemFrame.itemImage.Image = puppet and puppet.TextureId or ""
				newItemFrame.Visible = true
				newItemFrame.Parent = bag.ScrollingFrame[category].Bag

				newItemFrame.MouseEnter:Connect(function()
					module.HoverFrameChange(true, newItemFrame)
				end)
				newItemFrame.MouseLeave:Connect(function()
					if isDraggingItem == false then
						module.HoverFrameChange(false)
					end
				end)
			end
		end
	end

	-- Skills bag items: s.Location == -1 (frame Name = s.Name)
	for _, s in ipairs(skills) do
		if s.Location == -1 then
			local existing = bag.ScrollingFrame:FindFirstChild(s.Name, true)
			if existing then
				existing.Visible = true
			else
				local newItemFrame = itemTemplate:Clone()
				newItemFrame.Name = s.Name
				local puppet = backpack:FindFirstChild(s.Name)
				newItemFrame.itemImage.Image = puppet and puppet.TextureId or ""
				newItemFrame.Visible = true
				-- skills have no Type in ItemInfo, fallback to Skills folder or Items
				local parent = bag.ScrollingFrame:FindFirstChild("Skills")
						and bag.ScrollingFrame["Skills"]:FindFirstChild("Bag")
					or bag.ScrollingFrame
				newItemFrame.Parent = parent

				newItemFrame.MouseEnter:Connect(function()
					module.HoverFrameChange(true, newItemFrame)
				end)
				newItemFrame.MouseLeave:Connect(function()
					if isDraggingItem == false then
						module.HoverFrameChange(false)
					end
				end)
			end
		end
	end
end

function module.HotbarLoad(hotbar: Instance, backpack: Backpack, inventory: { ItemData }, skills: { SkillData })
	for _, slot in pairs(hotbar:GetChildren()) do
		if slot:IsA("ImageButton") and slot:FindFirstChild("itemImage") then
			slot.itemImage.Image = ""
		end
	end

	for _, entry in ipairs(inventory) do
		local location = entry.Location
		if location and location >= 1 and location <= 10 then
			local frameName = location == 10 and "SLOT0" or "SLOT" .. tostring(location)
			local SlotFrame = hotbar:FindFirstChild(frameName)
			if SlotFrame then
				local puppet = backpack:FindFirstChild(entry.UID) :: Tool
				SlotFrame.itemImage.Image = puppet and puppet.TextureId or ""
			end
		end
	end

	for _, s in ipairs(skills) do
		local location = s.Location
		if location and location >= 1 and location <= 10 then
			local frameName = location == 10 and "SLOT0" or "SLOT" .. tostring(location)
			local slotFrame = hotbar:FindFirstChild(frameName)
			if slotFrame then
				local puppet = backpack:FindFirstChild(s.Name) :: Tool
				slotFrame.itemImage.Image = puppet and puppet.TextureId or ""
			end
		end
	end
end

function module.MouseDown(
	MosPos,
	slotdragger,
	bp: Backpack,
	bag,
	hotbar,
	itemplate,
	inv: { ItemData },
	skills: { SkillData }
)
	if not isDraggingItem and currentFrameBeingHoveredOn then
		if currentFrameBeingHoveredOn:IsDescendantOf(bag) then
			isDraggingItem = true
			slotdragger.itemImage.Image = currentFrameBeingHoveredOn.itemImage.Image
			slotdragger.Visible = true
			currentFrameBeingHoveredOn.Visible = false

			for _, item in pairs(bp:GetChildren()) do
				if item:IsA("Tool") and item.Name == currentFrameBeingHoveredOn.Name then
					currentItemSelected = item
					break
				end
			end

			while isDraggingItem do
				MosPos = UIS:GetMouseLocation()
				slotdragger.Position = UDim2.fromOffset(MosPos.X, MosPos.Y)
				task.wait()
			end
		elseif currentFrameBeingHoveredOn:IsDescendantOf(hotbar) then
			local targetslot = slotsToNums[currentFrameBeingHoveredOn.Name]
			local uidOrName: string? = nil
			if inv then
				for _, entry in ipairs(inv) do
					if entry.Location == targetslot then
						uidOrName = entry.UID
						break
					end
				end
			end

			if not uidOrName and skills then
				for _, s in ipairs(skills) do
					if s.Location == targetslot then
						uidOrName = s.Name
						break
					end
				end
			end

			if uidOrName then
				for _, item in ipairs(bp:GetChildren()) do
					if item:IsA("Tool") and item.Name == uidOrName then
						currentItemSelected = item
						break
					end
				end
			end

			if currentItemSelected then
				isDraggingItem = true
				slotdragger.itemImage.Image = currentFrameBeingHoveredOn.itemImage.Image
				slotdragger.Visible = true
				currentFrameBeingHoveredOn.itemImage.Image = ""

				while isDraggingItem do
					MosPos = UIS:GetMouseLocation()
					slotdragger.Position = UDim2.fromOffset(MosPos.X, MosPos.Y)
					task.wait()
				end
			end
		end
	end
end

function module.MouseUp(slotDragger, hotbar, bag, backpack, itemTemplate, inventory, skills)
	isDraggingItem = false

	if currentItemSelected and currentFrameBeingHoveredOn then
		local newLocation: number? = nil
		if currentFrameBeingHoveredOn:IsDescendantOf(hotbar) then
			newLocation = slotsToNums[currentFrameBeingHoveredOn.Name]
		elseif currentFrameBeingHoveredOn == bag or currentFrameBeingHoveredOn:IsDescendantOf(bag) then
			newLocation = -1
		end

		if newLocation then
			local id = currentItemSelected.Name
			local isSkill = false
			if skills then
				for _, s in ipairs(skills) do
					if s.Name == id then
						isSkill = true
						break
					end
				end
			end
			-- fallback: if not found in skills, check inventory UID — else use ItemInfo
			if not isSkill and inventory then
				for _, entry in ipairs(inventory) do
					if entry.UID == id then
						isSkill = false
						break
					end
				end
			end
			local kind = isSkill and "Skill" or "Item"
			local id = currentItemSelected.Name -- UID for Item, Name for Skill (both stored as Tool.Name)
			InventoryEvent:FireServer("HotbarUpdate", kind, id, newLocation)
			-- no local BagLoad/HotbarLoad — wait for InventoryChanged from server
		else
			-- dropped nowhere valid: just restore visuals on next InventoryChanged
		end
	end

	slotDragger.Visible = false
	currentItemSelected = nil
end

function module.ItemEquip(item, hum, hotbar, loc: number?)
	hum:EquipTool(item)
	if loc and loc >= 1 and loc <= 10 then
		local frameName = loc == 10 and "SLOT0" or "SLOT" .. tostring(loc)
		local f = hotbar:FindFirstChild(frameName)
		if f then
			f.UIStroke.Color = Color3.fromRGB(255, 255, 255)
		end
	end
end

function module.ItemUnequip(hum, hotbar)
	hum:UnequipTools()
	for _, slot in pairs(hotbar:GetChildren()) do
		if slot:IsA("ImageButton") then
			slot.UIStroke.Color = Color3.fromRGB(20, 20, 20)
		end
	end
end

function module.UseItem(plr, Item, hotbar, baseName: string?)
	-- baseName = entry.Name ("Hat"), Item.Name is UID
	local name = baseName or Item:GetAttribute("BaseName") or Item.Name
	local stats = ItemInfo.getStats(name)
	local toolType = stats and stats.Type or ""
	print(tostring(Item), toolType)

	if toolType == "Accessory" then
		-- server derives EquipSlot from ItemInfo, only trust UID
		AccessoryEvent:FireServer("EquipAccessory", Item.Name)
	end
end

return module
