local AccessoriesManager = {}
local RS = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")
local SS = game:GetService("ServerStorage")
local ServerTypes = require(SS.Modules.ServerTypes)
local ItemInfo = require(SS.Modules.Dictionaries.ItemInfo)
local Models = RS.Models
local Welds = RS.Welds
local Events = RS.Events
local Tool_Folder = RS.Tools

local AccessoriesFolder = Models.Items.Accessories
local AccessoriesTools = Tool_Folder.Items.Accessories
local AccessoryAnimations = RS.Animations.Accessories
local WeldsFolder = Welds.Accessories

local AcessoryWelds = {}
local AccessoryAnims = {}

local AccessoryEvent = Events.AccessoryEvent

--[local Functions]--
local function GetAccessory(accessoryName)
	if not accessoryName then return nil end
	local accessory = AccessoriesFolder:FindFirstChild(accessoryName) --- This gets the accessory from ReplicatedStorage
	if accessory then
		return accessory:Clone() -- Clone the accessory to give each player their own copy
	else
		warn("Accessory not found:", accessoryName) -- Just incase I forgot to add it to the folder
		return nil
	end
end

local function RequestHair(ID: number): number?
	local model: Accessory = InsertService:LoadAsset(ID)
	local MeshID: number = nil

	if model then
		if
			model.AccessoryType ~= Enum.AccessoryType.Hair
			and model.AccessoryType ~= Enum.AccessoryType.Hat
			and model.AccessoryType ~= Enum.AccessoryType.Face
		then
			-- Then i would add a remote event to the client to nottify them that the asset they want is not a vaild hair
			model:Destroy()
			return nil
		end

		for _, v in pairs(model:GetChildren()) do
			if v:IsA("SpecialMesh") then
				MeshID = v.MeshId
				model:Destroy()
				return MeshID
			end
		end
	end

	return nil
end

local function ReturnAccessory(char, plr: Player, OldAccessory)
	if not OldAccessory then return end
    local accssoryType = ItemInfo.getStats(OldAccessory.Name).EquipSlot  or  OldAccessory:GetAttribute("AccessoryType") -- This checks what type of accessory it is (Hat, face, torso , Legs, Rings Artefacts etc)
	OldAccessory:Destroy()

	
	if AcessoryWelds[plr] and AcessoryWelds[plr][accssoryType] then
		AcessoryWelds[plr][accssoryType].Part1 = nil
	end
end

local function DestoryAccessory(char: Model, name)
	local target = char:FindFirstChild(name)

	if not target then
		return
	end

	target:Destroy()
end

local function Part0Finder(char, accessoryType) -- This function finds the base part to weld the accessory to based on the accessory type
	if accessoryType == "Hat" then
		return char:FindFirstChild("Head")
	elseif accessoryType == "Face" then
		return char:FindFirstChild("Head")
	elseif accessoryType == "Torso" then
		return char:FindFirstChild("Torso")
	elseif accessoryType == "Legs" then
		return char:FindFirstChild("Right Leg")
	elseif accessoryType == "Rings" then
		return char:FindFirstChild("Left Arm")
	elseif accessoryType == "Artefacts" then
		return char:FindFirstChild("Torso")
	elseif accessoryType == "Collar" then
		return char:FindFirstChild("Torso")
	else
		return nil
	end
end

--[Actual Module functions]--

function AccessoriesManager.LoadHairMesh(ID: number, colour: Color3)
	local MeshID = RequestHair(ID)
	local Mesh = Instance.new("SpecialMesh")
	Mesh.MeshId = MeshID
	Mesh.BrickColor = colour
end

function AccessoriesManager.EquipAccessory(char, accessoryName) -- This is the equiping function
	local plr = game.Players:GetPlayerFromCharacter(char)
	local hum = char:WaitForChild("Humanoid")
	local LeftLeg = char:FindFirstChild("Left Leg")

	local accessory = GetAccessory(accessoryName)
	local accssoryType = ItemInfo.getStats(accessoryName).EquipSlot or accessory:GetAttribute("AccessoryType") -- This checks what type of accessory it is (Hat, face, torso , Legs, Rings Artefacts etc)
	accessory.Parent = char.Accessories

	if not AcessoryWelds[plr] then
		AcessoryWelds[plr] = {}
	end

	if not AcessoryWelds[plr][accssoryType] then
		AcessoryWelds[plr][accssoryType] = WeldsFolder:FindFirstChild(accessoryName):Clone()
	end
	-- This gets the corresponding weld from ReplicatedStorage
	AcessoryWelds[plr][accssoryType].Parent = char.Accessories.Welds

	if AcessoryWelds[plr][accssoryType].Part1 then
		-- If there is already an accessory of this type equipped, return it to the player's backpack

		local existingAccessory = AcessoryWelds[plr][accssoryType].Part1
		if existingAccessory then
			ReturnAccessory(char, plr, existingAccessory)
		end
	end

	AcessoryWelds[plr][accssoryType].Part0 = Part0Finder(char, accssoryType) -- This sets Part0 of the weld to the correct body part
	if accessoryName == "Legs" then -- This is a special case for the legs and torso accessory as it needs to weld to both legs and Arms
		local AcessoryPair = accessory:FindFirstChild("AcessoryPair")
		local AcessoryPairWeld = AcessoryPair.Weld
		AcessoryPairWeld.Part0 = LeftLeg
		AcessoryPairWeld.Part1 = AcessoryPair
	elseif accessoryName == "Torso" then
		local sides = { ["LeftSeleve"] = "Left Arm", ["RightSeleve"] = "Right Arm" }
		for modelName, bodyPart in pairs(sides) do
			local part = accessory:FindFirstChild(modelName)
			if part and part:FindFirstChild("ExtraWeld") then
				part.Weld.Part0 = char:FindFirstChild(bodyPart)
				part.Weld.Part1 = part
			end
		end
	end

	AcessoryWelds[plr][accssoryType].Part1 = accessory -- This sets Part1 of the weld to the correct Accessory
	AcessoryWelds[plr][accssoryType].C0 = Welds.Accessories[accessoryName].C0 -- Enables the weld to attach the accessory to the character
	AccessoryEvent:FireClient(plr, "RefreshAnimations") --- This fires to the client script handling walk cycles to refresh their animations
	if AccessoryAnimations:FindFirstChild(accessoryName) then
		AccessoryAnims[plr] = hum.Animator:LoadAnimation(AccessoryAnimations[accessoryName]) -- This gets the corresponding animation for the accessory if it has one
		AccessoryAnims[plr]:Play() -- This plays the animation
	end

	DestoryAccessory(char, accessoryName)
end

function AccessoriesManager.UnequipAccessory(char, accessoryName) -- This is the unequiping function
	local plr = game.Players:GetPlayerFromCharacter(char)
	local accessory = char.Accessories:FindFirstChild(accessoryName)
	if accessory then
		ReturnAccessory(char, plr, accessory)
	end
	AccessoryEvent:FireClient(plr, "RefreshAnimations") -- Same thing as before
end

function AccessoriesManager.LoadRaceAcessories(PLR: ServerTypes.PLR) end

function AccessoriesManager.cleanup(plr) -- Cleans up the welds when the player leaves
	if AcessoryWelds[plr] then
		AcessoryWelds[plr] = nil
	end
end

function AccessoriesManager.CleanupForPlayer(plr)
	if AcessoryWelds[plr] then
		AcessoryWelds[plr] = nil
	end
	if AccessoryAnims[plr] then
		pcall(function()
			AccessoryAnims[plr]:Stop()
		end)
		AccessoryAnims[plr] = nil
	end
end

--[[
    AccessoriesManager Module Yap
    Reminders: 
    When adding new accessories,remember to create corresponding welds in ReplicatedStorage.Welds.Accessories
    Also rememeber to as an Atrribute "AccessoryType" to the accessory in ReplicatedStorage.Models.Accessories

    Make sure the welds have the correct C0 values to position the accessories properly.
    Also make sure special accessories like "Legs" and "Torso" that may require additional handling that within the base accessory model that the AcessoryPair or Left/Right Seleve parts have welds set up to attach to the correct body parts.

    I may or not add to a check that checks that for the legs accessory and makes a secondary weld to the right leg.

    Also i would need to add a race function that loads accesoires based on the char's race species 


    Functions:
    - EquipAccessory(char, accessoryName): Equips the specified accessory to the character.
    - UnequipAccessory(char, accessoryName): Unequips the specified accessory from the character and returns it to the player's backpack.
    
    Usage:
    AccessoriesManager.EquipAccessory(char, "hat")


    Welds Structure Idea:
    AccessoriesWelds{
        [player] = {
            ["Hat"] = WeldObject,
            ["Face"] = WeldObject,
            ["Torso"] = WeldObject,
            ["Legs"] = WeldObject,
            ["Artefacts"] = WeldObject,
            ["Rings"] = WeldObject
            ["Collar"] = WeldObject
        }
    }
]]

return AccessoriesManager
