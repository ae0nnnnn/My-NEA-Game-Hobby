local plr = {}
plr.__index = plr
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local PS = game:GetService("PhysicsService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local SSModules = SS.Modules
local RSModules = RS.Modules

local DataManger = require(ServerScriptService.Data.Modules.DataManager)
local Movement = require(RSModules.Movement.Objects.Movement)
local ServerTypes = require(SSModules.ServerTypes)
local AcessoryManager = require(SSModules.Other.AccessoriesManager)
local CombatData = require(SSModules.Combat.Data.CombatData)
local helpfullModule = require(SSModules.Other.Helpful)
local StatFormulas = require(SSModules.Other.StatFormulas)
local CombatHelper = require(SSModules.Combat.CombatHelper)
local ModeModule = require(SSModules.Combat.Mode_Module)
local ParryModule = require(SSModules.Parrying)
local SkillMasterController = require(SSModules.Combat.SkillMasterController)

-- ServerTypes.PLR is the exported `PLRData & PLRMethods` type (see ServerTypes.lua).
-- Aliased locally so every annotation below reads cleanly.
type PLR = ServerTypes.PLR

local CHAR_GROUP = "Characters"
local VFX_GROUP = "VFX_Models"

pcall(function()
	PS:RegisterCollisionGroup(CHAR_GROUP)
end)

PS:CollisionGroupSetCollidable(CHAR_GROUP, VFX_GROUP, false)

local function GroupSeter(char: Model)
	for _, child in ipairs(char:GetDescendants()) do
		if child:IsA("BasePart") then
			child.CollisionGroup = CHAR_GROUP
		end
	end

	char.DescendantAdded:Connect(function(new)
		if new:IsA("BasePart") and new.CanCollide then
			new.CollisionGroup = CHAR_GROUP
		end
	end)
end

local function LoadCharacterAppearance(plr: PLR)
	local hum = plr.Character:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local AccessoriesFolder = Instance.new("Folder")
	local WeldsFolder = Instance.new("Folder")

	WeldsFolder.Name = "Welds"
	WeldsFolder.Parent = AccessoriesFolder
	AccessoriesFolder.Name = "Accessories"
	AccessoriesFolder.Parent = plr.Character

	for accessoryType, accessoryItem in pairs(plr.Data.Accessories) do
		if accessoryItem ~= nil then
			AcessoryManager.EquipAccessory(plr.Character, accessoryItem.Name)
		end
	end

	local bodyColors = plr.Character:FindFirstChildOfClass("BodyColors") or Instance.new("BodyColors",plr.Character)

		if plr.Data.Appearance.Skin_Tone ~= "" then
		local skinColor = BrickColor.new(Color3.fromHex(plr.Data.Appearance.Skin_Tone))
		bodyColors.HeadColor = skinColor
		bodyColors.LeftArmColor = skinColor
		bodyColors.RightArmColor = skinColor
		bodyColors.LeftLegColor = skinColor
		bodyColors.RightLegColor = skinColor
		bodyColors.TorsoColor = skinColor
	end

end

local function SetupStats(plr: PLR)
	local char = plr.Character

	local function setupSPT()
		local MaxMana = 0
		local MaxMF = 0

		local function sync()
			local SPT = StatFormulas.GetStat(char, "SPT")
			local END = StatFormulas.GetStat(char, "END")

			MaxMana = StatFormulas.MaxMana(SPT)
			MaxMF = StatFormulas.MaxMF(SPT, END)

			char:SetAttribute("MaxMana", MaxMana)
			char:SetAttribute("Mana", MaxMana)
			char:SetAttribute("MaxMF", MaxMF)
			char:SetAttribute("MF", MaxMF)
		end
		sync()

		local function onStatChanged()
			local Orginal_Mana = char:GetAttribute("Mana")
			local Orginal_MF = char:GetAttribute("MF")
			sync()
			if char:GetAttribute("InCombat") then
				char:SetAttribute("Mana", Orginal_Mana)
				char:SetAttribute("MF", Orginal_MF)
			end

			print("New Target for MANA = {", MaxMana, "}")
			print("New Target for MF = {", MaxMF, "}")
		end

		local function onStatMultChanged()
			local Orginal_Mana = char:GetAttribute("Mana") :: number
			local Orginal_MF = char:GetAttribute("MF") :: number
			sync()
			if char:GetAttribute("InCombat") then
				char:SetAttribute("Mana", Orginal_Mana)
			end
			char:SetAttribute("MF", math.min(Orginal_MF, char:GetAttribute("MaxMF") ::number))
		end

		char:GetAttributeChangedSignal("SPT"):Connect(onStatChanged)
		char:GetAttributeChangedSignal(StatFormulas.STAT_MULT_ATTRIBUTE):Connect(onStatMultChanged)
	end

	local function setupHealth(char: Model)
		local hum = char:FindFirstChildOfClass("Humanoid")

		if not hum then
			return
		end

		local function sync()
			local VIT = StatFormulas.GetStat(char, "VIT")
			hum.MaxHealth = StatFormulas.MaxHealth(VIT)
		end
		sync()
		hum.Health = hum.MaxHealth

		char:GetAttributeChangedSignal("VIT"):Connect(sync)
		char:GetAttributeChangedSignal(StatFormulas.STAT_MULT_ATTRIBUTE):Connect(sync)

		-- Monitor low health state
		hum.HealthChanged:Connect(function()
			if hum.Health <= hum.MaxHealth * StatFormulas.CONFIG.VIT.LOW_HEALTH_THRESHOLD then
				char:SetAttribute("IsLow", true)
				helpfullModule.ResetMobility(char)
			else
				char:SetAttribute("IsLow", false)
				helpfullModule.ResetMobility(char)
			end
		end)
	end

	local function setupStamina()
		local MaxStamina = 0

		local function sync()
			local END = StatFormulas.GetStat(char, "END")

			MaxStamina = StatFormulas.MaxStamina(END)

			char:SetAttribute("MaxStamina", MaxStamina)
			char:SetAttribute("Stamina", MaxStamina)
		end
		sync()

		local function onChanged()
			local Orginal = char:GetAttribute("Stamina")
			sync()
			if char:GetAttribute("InCombat") then
				char:SetAttribute("Stamina", Orginal)
			end

		end

		char:GetAttributeChangedSignal("END"):Connect(onChanged)
		char:GetAttributeChangedSignal(StatFormulas.STAT_MULT_ATTRIBUTE):Connect(onChanged)
	end

	for statName, statValue in pairs(plr.Data.STAT_POINTS) do
		plr.Stats[statName] = statValue
		char:SetAttribute(statName, statValue)
	end

	setupHealth(char)
	setupSPT()
	setupStamina()
end

local function SetupStates(plr: PLR)
	local char = plr.Character
	char:SetAttribute("CurrentWeapon", "Fists") -- I would replace this with the players's weapon in .Data when i add non movesert restricted weapons
	char:SetAttribute("Element", plr.Element.Name)
	char:SetAttribute("InCombat", false)
	char:SetAttribute("MF", 0)
	char:SetAttribute("Blocking", 0)
	char:SetAttribute("Karma", 0)
	char:SetAttribute(StatFormulas.STAT_MULT_ATTRIBUTE, 1)
end

local playertoPLR: { [Player]: PLR } = {}

function plr.new(Player: Player, Slot: string): PLR
	local self = (
		setmetatable({
			IsReady = false,
			HasMoved = false,
			Highlight = nil,
			Player = Player,
			Data = nil,
			FirstName = "",
			LastName = "",
			Character = Player.Character,
			CurrentSlot = Slot,
			HairColor = Color3.new(),
			Element = nil,
			MovementObj = nil,
			Intent = "None",
			Talents = {},
			Skills = {},
			Stats = {
				VIT = 0,
				END = 0,
				STR = 0,
				SPT = 0,
				DEX = 0,
				AGL = 0,
				WPN = 0,
			},
		}, plr) :: any
	) :: PLR
	local profile
	while true do
		print(DataManger.Profiles)
		profile = DataManger.Profiles[Player]
		print("Player data not found")
		if profile then
			break
		end
		task.wait()
	end

	self.MovementObj = Movement.new(Player)

	self.Data = profile.Data[Slot] --- Current Slot Data
	self.GlobalData = profile.Data.GENERAL -- Generla Data that is used to access info such the bank and Global Settings
	self.Settings = self.Data.Settings -- Settings data used to load keybinds for when they are added 

	if self.Character.Parent ~= Workspace.Characters then
		self.Character.Parent = workspace.Characters
	end

	local HRP = self.Character:FindFirstChild("HumanoidRootPart") :: BasePart

	while self.MovementObj.IsReady == false do
		task.wait(0.01)
	end

	local Cframeparts = self.Data.LastLocation

	if Cframeparts then
		local Cframe = CFrame.new(table.unpack(Cframeparts))
		HRP.CFrame = Cframe
	end

	local Highlight = Instance.new("Highlight")
	Highlight.Parent = self.Character
	Highlight.FillColor = Color3.new(0, 1, 0)
	Highlight.FillTransparency = 0.5
	Highlight.OutlineTransparency = 1
	Highlight.Name = "InitializeHighlight"
	self.Highlight = Highlight
	self.Character:SetAttribute("CurrentSlot", Slot)

	self.CurrentSlot = Slot
	self.HairColor = Color3.new(
		self.Data.Appearance.Hair_Colour.Red,
		self.Data.Appearance.Hair_Colour.Green,
		self.Data.Appearance.Hair_Colour.Blue
	)

	local target = self.Data.Element

	if target and target ~= "..." then
		local ElementModule = require(SSModules.Element[target])
		self.Element = ElementModule.new()
	else
		target = "Astral"
		local ElementModule = require(SSModules.Element[target])
		self.Element = ElementModule.new()
	end



	LoadCharacterAppearance(self)
	SetupStats(self)
	SetupStates(self)

	if  self.Element and self.Element.Innate then
		self.Element:Innate(self.Character)
	end

	helpfullModule.ResetMobility(self.Character)
	GroupSeter(self.Character)
	

	for _, v in pairs(self.Character:GetDescendants()) do
		if v.Parent and v.Parent:IsA("Accessory") and v:IsA("BasePart") then
			v.CanTouch = false
			v.CanQuery = false
		end
	end

	local Torso = self.Character:FindFirstChild("Torso")
	helpfullModule.ChangeWeapon(self.Player, self.Character, Torso)

	playertoPLR[Player] = self
	self.IsReady = true

	return self
end
function plr.Cleanup(self: PLR)
	if not self.Player or self._cleaned then
		return
	end
	self._cleaned = true

	AcessoryManager.CleanupForPlayer(self.Player)

	if self.MovementObj then
		pcall(function()
			self.MovementObj:Destroy()
		end)
		self.MovementObj = nil :: any
	end

	local Identifier = self.Player
	CombatData.ClearForPlayer(Identifier)
	CombatHelper.CleanupForPlayer(Identifier)
	ModeModule.CleanupForPlayer(Identifier)
	ParryModule.CleanupForPlayer(Identifier)
	SkillMasterController.CleanupForPlayer(Identifier)
	playertoPLR[self.Player] = nil
end

function plr:Destroy()
	local Character = self.Character
	if Character then
		local HRP = Character:FindFirstChild("HumanoidRootPart")
		if HRP and self.Data then
			local CframeParts = { (HRP :: BasePart).CFrame:GetComponents() }
			self.Data.LastLocation = CframeParts
		end
	end

	self:Cleanup()

	if self.Character then
		pcall(function()
			self.Character:Destroy()
		end)
	end

	table.clear(self)
	table.freeze(self)
end

function plr.GetPLRFromPlayer(Player: Player): PLR?
	if playertoPLR[Player] then
		return playertoPLR[Player]
	else
		warn("[PlayerObject]: This player doesn't have a valid plr object")
		return nil
	end
end

function plr:IncreaseStat(statName: string, amount: number?)
	self.Data.STAT_POINTS[statName] = self.Data.STAT_POINTS[statName] + (amount or 1)
end

function plr:EquipAccessory(accessoryType: string, accessoryItem)
	AcessoryManager.EquipAccessory(self.Character, accessoryType)
---	DataManger.UpdateAccessories(self.Player, accessoryType, accessoryItem)
end

function plr:UnequipAccessory(accessoryType: string)
	AcessoryManager.UnequipAccessory(self.Character, accessoryType)
	---DataManger.UpdateAccessories(self.Player, accessoryType, nil)
end

function plr.FirstMovement(self: PLR)
	self.HasMoved = true
	local char = self.Character
	char:SetAttribute("Iframes", false) -- The Iframes where given  @src/ServerScriptService/Pre-Loading/PlayerInit.server.lua 
	local hl = self.Highlight
	if hl and hl.Parent then
		hl:Destroy()
		self.Highlight = nil
	end
end

return plr
