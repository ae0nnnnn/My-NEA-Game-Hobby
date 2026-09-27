----[[VARIABLES]]----
local UIS = game:GetService("UserInputService") -- the user input service, used for detecting inputs from the player/client
local SG = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")
local RSModules = RS.Modules

local inventory_module = require(RSModules.InventoryUI) -- requring the module script

local Events = RS.Events
local UI_Update = Events.UI_Update
local InventoryEvent = Events:WaitForChild("InventoryEvent")
local GetInventory = Events:FindFirstChild("GetInventory")

local player = game:GetService("Players").LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local backpack = player:WaitForChild("Backpack")
-- keep them fresh after death
player.CharacterAdded:Connect(function(newChar)
	char = newChar
	hum = newChar:WaitForChild("Humanoid")
	backpack = player:WaitForChild("Backpack")
end)

local playerGUI = player:FindFirstChildOfClass("PlayerGui")

local gui = playerGUI:WaitForChild("Inventory") 
local bag = gui:WaitForChild("BAG")
local hotbar = gui:WaitForChild("HOTBAR")



local itemTemplate = bag:WaitForChild("ItemTemplate")
local slotDragger = gui:WaitForChild("SLOT_DRAGGER")

local justEquipped = false
local currentFrameBeingHoveredOn = nil
local currentItemSelected = nil
local isDraggingItem = false
local currentMousePos = nil

local plr = game.Players.LocalPlayer

print("InventoryClient loaded, gui=", playerGUI and playerGUI:FindFirstChild("Inventory"))
print("bag test", playerGUI and playerGUI:FindFirstChild("Inventory") and playerGUI.Inventory:FindFirstChild("BAG"))
print(GetInventory)

local currentInventory: { inventory_module.ItemData } = {}
local currentSkills: { inventory_module.SkillData } = {}

-- a table used to convert all the slots to enums (this will be helpful when detecting player inputs)
local slotsToEnum = {
	[1] = Enum.KeyCode.One,
	[2] = Enum.KeyCode.Two,
	[3] = Enum.KeyCode.Three,
	[4] = Enum.KeyCode.Four,
	[5] = Enum.KeyCode.Five,
	[6] = Enum.KeyCode.Six,
	[7] = Enum.KeyCode.Seven,
	[8] = Enum.KeyCode.Eight,
	[9] = Enum.KeyCode.Nine,
	[10] = Enum.KeyCode.Zero,
}

SG:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) -- disabling the default roblox backpack

----[[FUNCTIONS]]----

local function toggleBag(toggle)
	if toggle == true then
		bag.Visible = true
	elseif toggle == false then
		bag.Visible = false
	end
end

local function rebuildByLocation()
	local byLoc: { [number]: any } = {}
	local byUID: { [string]: any } = {}
	for _, e in ipairs(currentInventory) do
		byUID[e.UID] = e
		if e.Location and e.Location >= 1 and e.Location <= 10 then
			byLoc[e.Location] = e
		end
	end
	for _, s in ipairs(currentSkills) do
		if s.Location and s.Location >= 1 and s.Location <= 10 then
			byLoc[s.Location] = s
		end
	end
	return byLoc, byUID
end

local function inputBegan(input, processed)
	if justEquipped == true then
		justEquipped = false
	end

	local byLoc, byUID = rebuildByLocation()

	for loc, entry in pairs(byLoc) do
		if input.KeyCode == slotsToEnum[loc] then
			local isSkill = entry.UID == nil
			local puppetName = entry.UID or entry.Name
			local puppet = backpack:FindFirstChild(puppetName) or char:FindFirstChild(puppetName)
			if isSkill then
				inventory_module.TriggerSkill(entry.Name)
			else
				if puppet and puppet:IsA("Tool") then
					local equipped = char:FindFirstChildOfClass("Tool")
					if equipped and equipped.Name == puppetName then
						-- already holding this slot -> toggle off
						inventory_module.ItemUnequip(hum, hotbar)
						justEquipped = false
					else
						justEquipped = true
						inventory_module.ItemUnequip(hum, hotbar)
						inventory_module.ItemEquip(puppet, hum, hotbar, entry.Location)
					end
				end
			end
			return -- handled this key, don't fall through to second loop
		end
	end

	-- fallback: if we somehow pressed a slot with no byLoc entry but still hold that tool, unequip
	for _, tool in pairs(char:GetChildren()) do
		if tool:IsA("Tool") then
			local entry = byUID[tool.Name]
			local loc = entry and entry.Location
			if loc and loc >= 1 and loc <= 10 and input.KeyCode == slotsToEnum[loc] then
				inventory_module.ItemUnequip(hum, hotbar)
			end
		end
	end

	if input.KeyCode == Enum.KeyCode.Backquote  or input.KeyCode == Enum.KeyCode.Slash then

		if bag.Visible == true then
			toggleBag(false)
		elseif bag.Visible == false then
			toggleBag(true)
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		local equippedTool = char:FindFirstChildOfClass("Tool")
		if equippedTool then
			local entry = byUID[equippedTool.Name]
			-- if no entry, treat as skill puppet by Name
			local isSkill = false
			if not entry then
				for _, s in ipairs(currentSkills) do
					if s.Name == equippedTool.Name then
						isSkill = true
						break
					end
				end
			end
			if not isSkill then
				inventory_module.UseItem(plr, equippedTool, hotbar, entry and entry.Name or nil)
			end
		else
			isDraggingItem = true
			inventory_module.MouseDown(
				UIS:GetMouseLocation(),
				slotDragger,
				backpack,
				bag,
				hotbar,
				itemTemplate,
				currentInventory,
				currentSkills
			)
		end
	end
end

local function inputEnded(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isDraggingItem = false
		inventory_module.MouseUp(slotDragger, hotbar, bag, backpack, itemTemplate, currentInventory, currentSkills)
	end
end

bag.MouseEnter:Connect(function()
	inventory_module.HoverFrameChange(true, bag)
end)

bag.MouseLeave:Connect(function()
	if isDraggingItem == false then
		inventory_module.HoverFrameChange(false)
	end
end)

for _, slot in pairs(hotbar:GetChildren()) do
	if slot:IsA("ImageButton") then
		slot.MouseEnter:Connect(function()
			inventory_module.HoverFrameChange(true, slot)
		end)
		slot.MouseLeave:Connect(function()
			if isDraggingItem == false then
				inventory_module.HoverFrameChange(false)
			end
		end)
	end
end

local function refresh(inventory, skills)
	currentInventory = inventory or currentInventory
	currentSkills = skills or currentSkills
	-- InventoryEvent currently fires (Inventory, Accessories) — handle both shapes
	if skills and typeof(skills) == "table" and skills.Hat ~= nil then
		-- second arg is Accessories dict, not Skills array — keep old skills
		skills = currentSkills
	else
		currentSkills = skills or currentSkills
	end
	inventory_module.BagLoad(bag, backpack, currentInventory, currentSkills, itemTemplate)
	inventory_module.HotbarLoad(hotbar, backpack, currentInventory, currentSkills)
end

-- snapshot on join
if GetInventory then
	local ok, inv, skl = pcall(function()
		return GetInventory:InvokeServer()
	end)
	if ok and inv then
		-- GetInventory may return (Inventory, Skills) or (Inventory, Skills, Accessories)
		if typeof(skl) == "table" and skl.Hat ~= nil then
			-- skl is Accessories, ignore
			refresh(inv, currentSkills)
		else
			refresh(inv, skl or {})
		end
	else
		refresh({}, {})
	end
else
	refresh({}, {})
end

-- server push — replaces backpack.ChildAdded/Removed
InventoryEvent.OnClientEvent:Connect(function(action, a, b)
	if action == "InventoryChanged" then
		-- a = Inventory, b = Accessories or Skills (handle both)
		if b and typeof(b) == "table" and b.Hat ~= nil then
			refresh(a, currentSkills)
		else
			refresh(a, b or currentSkills)
		end
	end
end)

UIS.InputBegan:Connect(inputBegan)
UIS.InputEnded:Connect(inputEnded)
