local Time = {}
Time.__index = Time
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local SSModules = SS.Modules
local Combat_Data = require(SSModules.Combat.Data.CombatData)
local AnimationsFolder = RS.Animations
local WeaponsAnimations = AnimationsFolder.Weapons
local WeaponsModels = RS.Models.Weapons
local WeaponsWeld = RS.Welds
local Welds = Combat_Data.Welds
local EquipAnims = Combat_Data.EquipAnims
local IdleAnims = Combat_Data.IdleAnims
local EquipDebounce = Combat_Data.EquipDebounce

local ServerTypes = require(SSModules.ServerTypes)
type ElementBase = ServerTypes.ElementBase

type TimeData = {
	Dodges: number,
	Mode1Weapon: string,
	Mode2Weapon: string,
	Mode2Callout: string,
	Dialogue: { string },
	WeaponCounter: number,
	Connection: RBXScriptConnection?,
	WeaponSwapAnimation: AnimationTrack?,
	DidSwap: boolean,
	WeaponArsenal: { string },
	LastHitStat: string?,
	Knowledge: number
}

type ElementBaseNoData = {
	Name: string,
	R: (self: ElementBase, char: Model) -> (),
	Z: (self: ElementBase, char: Model) -> (),
	X: (self: ElementBase, char: Model) -> (),
	C: (self: ElementBase, char: Model) -> (),
	V: (self: ElementBase, char: Model) -> (),
	Innate: ((self: ElementBase, char: Model) -> ())?,
	Mode1Init: ((self: ElementBase, char: Model) -> ())?,
	Mode2Init: ((self: ElementBase, char: Model) -> ())?,
	RevengeCounter: ((self: ElementBase, char: Model, target: Model) -> ())?,
}

export type TimeObject = ElementBaseNoData & { Data: TimeData }

local function GetNPCFromCharacter(char)
	local plr = game.Players:GetPlayerFromCharacter(char)
	if plr then
		return nil
	end
	local npcModule = require(SSModules.Objects.npc)
	return npcModule.GetNpcFromCharacter(char)
end

local CONFIG = {
	HilightColour = Color3.new(0.211765, 0.015686, 0.352941),
}

function Time.new(): TimeObject
	local self = (
		setmetatable({
			Name = "Time" :: "Time",
			Data = {
				Dodges = 0,
				Mode1Weapon = "DrakeFang",
				Mode2Weapon = "TwinSpears",
				Mode2Callout = "...",
				Dialogue = {
					"<h>Asmondaios<h><sound:rbxassetid://98570702510642>It seems I need to drop the funny guy act huh<sound:rbxassetid://98570702510642>",
					"<h>Lunara<h><sound:rbxassetid://137940291335732> Well no, doofus<sound:rbxassetid://137940291335732>",
					"<h>Asmondaios<h><sound:rbxassetid://98570702510642><shake>Ow !</shake> my Bad, So we need to pull out all the stops then<sound:rbxassetid://98570702510642>",
					"<h>???<h><shake><colour:#FF0000>Crazy</colour:#FF0000></shake> monkey!",
				},
				WeaponCounter = 1,
				Connection = nil,
				WeaponSwapAnimation = nil,
				DidSwap = false,
				WeaponArsenal = {
					"Tooth_And_Nail",
					"Judgement",
					"Fang",
					"DrakeFang",
					"Glock",
				},
			},
		}, Time) :: any
	) :: TimeObject
	return self
end

local function Mode1_R(self: TimeObject, char: Model)
	local plr = game.Players:GetPlayerFromCharacter(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local torso = char:FindFirstChild("Torso")
	local rightArm = char:FindFirstChild("Right Arm")
	local HelpfullModule = require(SSModules.Other.Helpful)
	local Identifier = plr or GetNPCFromCharacter(char)
	if not Identifier then
		return
	end
	if EquipDebounce[Identifier] then
		return
	end
	if self.Data.Connection then
		self.Data.Connection:Disconnect()
	end
	local CharWeaponCounter = self.Data.WeaponCounter
	local TargetWeapon = self.Data.WeaponArsenal[CharWeaponCounter]
	EquipDebounce[Identifier] = true
	char:SetAttribute("IsTransforming", true)
	self.Data.WeaponSwapAnimation = hum:LoadAnimation(WeaponsAnimations.Transformations.Time.WeaponSwap)
	if not self.Data.WeaponSwapAnimation then
		return
	end
	self.Data.Connection = self.Data.WeaponSwapAnimation:GetMarkerReachedSignal("Swap"):Connect(function()
		self.Data.DidSwap = true
		for _, anim in ipairs(hum.Animator:GetPlayingAnimationTracks()) do
			if anim.Name == "Swing1" or anim.Name == "Swing2" or anim.Name == "Swing3" or anim.Name == "Swing4" then
				return
			end
		end
		if HelpfullModule.CheckForAttributes(char, true, true, false, true, true, true, true, nil, true) then
			return
		end
		char:SetAttribute("CurrentWeapon", TargetWeapon)
		for _, weapon in ipairs(WeaponsModels:GetChildren()) do
			local existing = char:FindFirstChild(weapon.Name)
			if existing then
				existing:Destroy()
			end
		end
		HelpfullModule.ChangeWeapon(Identifier, char, torso)
		if Welds[Identifier] then
			Welds[Identifier].Part0 = rightArm
			Welds[Identifier].C0 = WeaponsWeld[TargetWeapon].HoldingWeaponWeld.C0
		end
		IdleAnims[Identifier] = hum.Animator:LoadAnimation(WeaponsAnimations[TargetWeapon].Main.Idle)
		EquipAnims[Identifier] = hum.Animator:LoadAnimation(WeaponsAnimations[TargetWeapon].Main.Equip)
		char:SetAttribute("IsTransforming", false)
		EquipDebounce[Identifier] = false
		if IdleAnims[Identifier] then
			IdleAnims[Identifier]:Play()
		end
		self.Data.WeaponCounter = self.Data.WeaponCounter + 1
		if self.Data.WeaponCounter > 4 then
			self.Data.WeaponCounter = 1
		end

		if self.Data.Connection then
			self.Data.Connection:Disconnect()
		end

		self.Data.Connection = nil
	end)
	self.Data.WeaponSwapAnimation.Stopped:Connect(function()
		if self.Data.DidSwap then
			return
		end
		for _, anim in ipairs(hum.Animator:GetPlayingAnimationTracks()) do
			if anim.Name == "Swing1" or anim.Name == "Swing2" or anim.Name == "Swing3" or anim.Name == "Swing4" then
				return
			end
		end
		if HelpfullModule.CheckForAttributes(char, true, true, false, true, true, true, nil, nil, true) then
			return
		end
		char:SetAttribute("CurrentWeapon", TargetWeapon)
		for _, weapon in ipairs(WeaponsModels:GetChildren()) do
			local existing = char:FindFirstChild(weapon.Name)
			if existing then
				existing:Destroy()
			end
		end
		HelpfullModule.ChangeWeapon(Identifier, char, torso)
		if Welds[Identifier] then
			Welds[Identifier].Part0 = rightArm
			Welds[Identifier].C0 = WeaponsWeld[TargetWeapon].HoldingWeaponWeld.C0
		end
		IdleAnims[Identifier] = hum.Animator:LoadAnimation(WeaponsAnimations[TargetWeapon].Main.Idle)
		EquipAnims[Identifier] = hum.Animator:LoadAnimation(WeaponsAnimations[TargetWeapon].Main.Equip)
		char:SetAttribute("IsTransforming", false)
		EquipDebounce[Identifier] = false
		self.Data.DidSwap = false
		if IdleAnims[Identifier] then
			IdleAnims[Identifier]:Play()
		end
		self.Data.WeaponCounter = self.Data.WeaponCounter + 1
		if self.Data.WeaponCounter > 4 then
			self.Data.WeaponCounter = 1
		end
	end)
end

local function Mode1_Z(self: TimeObject, char: Model) end
local function Mode1_X(self: TimeObject, char: Model) end
local function Mode1_C(self: TimeObject, char: Model) end
local function Mode2_R(self: TimeObject, char: Model) end
local function Mode2_Z(self: TimeObject, char: Model) end
local function Mode2_X(self: TimeObject, char: Model) end
local function Mode2_C(self: TimeObject, char: Model) end
local function Mode1_V(self: TimeObject, char: Model) end
local function Mode2_V(self: TimeObject, char: Model) end

function Time:Innate(char: Model)
	print("Yol")
end

function Time:Mode1Init(char: Model) end

function Time:Mode2Init(char: Model)
	if not char then
		return
	end
	self.Data.Dodges = 21

	local function pickpart(): BasePart -- I know this is ineffeucet but lets leave it for now
		local Selection = {}
		for _, item in char:GetDescendants() do
			if item:IsA("BasePart") then
				table.insert(Selection, item)
			end
		end

		local poniter = math.random(1, #Selection)
		return Selection[poniter]
	end

	local hl1 = Instance.new("Highlight", RS)
	hl1.DepthMode = Enum.HighlightDepthMode.Occluded
	hl1.OutlineTransparency = 1
	hl1.FillColor = CONFIG.HilightColour
	hl1.OutlineColor = CONFIG.HilightColour
	hl1.FillTransparency = -74

	local hl2 = hl1:Clone()
	hl2.Parent = RS

	local hl3 = hl1:Clone()
	hl3.Parent = RS

	task.spawn(function()
		while char do
			local part1 = pickpart()
			local part2 = pickpart()
			local part3 = pickpart()

			while part1 == part2 do
				part2 = pickpart()
			end

			while part3 == part1 or part3 == part2 do
				part3 = pickpart()
			end

			hl1.Adornee = part1
			hl2.Adornee = part2
			hl3.Adornee = part3

			local rng = Random.new()
			local waitTime = rng:NextNumber(0.05, 0.1)
			task.wait(waitTime)
		end
	end)
end

function Time.DodgeRandomTP(Target: Model, Attacker: Model)
	if not Target or not Target:IsA("Model") then
		return
	end
	if not Attacker or not Attacker:IsA("Model") then
		return
	end
	local targetRoot = Target:FindFirstChild("HumanoidRootPart")
	local attackerRoot = Attacker:FindFirstChild("HumanoidRootPart")
	if not targetRoot or not attackerRoot then
		return
	end
	local MIN_RADIUS = 20
	local MAX_RADIUS = 50
	local originalParts = {}
	for _, part in ipairs(Target:GetDescendants()) do
		if part:IsA("BasePart") and part:IsDescendantOf(Target) then
			table.insert(originalParts, {
				Name = part.Name,
				CFrame = part.CFrame,
				Size = part.Size,
			})
		end
	end
	for _, data in ipairs(originalParts) do
		local clone = Instance.new("Part")
		clone.Name = "AfterImagePart"
		clone.Anchored = true
		clone.CanCollide = false
		clone.Color = Color3.new(1, 1, 1)
		clone.Material = Enum.Material.SmoothPlastic
		clone.Transparency = 0
		clone.Size = data.Size
		clone.CFrame = data.CFrame
		clone.Parent = workspace
		local yOffset = math.random(2, 5)
		local rotX = math.rad(math.random(-90, 90))
		local rotY = math.rad(math.random(-180, 180))
		local rotZ = math.rad(math.random(-90, 90))
		local tweenTime = math.random(15, 35) / 100
		local goal = {
			CFrame = data.CFrame * CFrame.new(0, yOffset, 0) * CFrame.Angles(rotX, rotY, rotZ),
			Transparency = 1,
		}
		local tweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		local tween = TweenService:Create(clone, tweenInfo, goal)
		tween:Play()
		tween.Completed:Connect(function()
			clone:Destroy()
		end)
	end
	local function getValidPosition()
		for _ = 1, 10 do
			local angle = math.random() * 2 * math.pi
			local distance = math.random(MIN_RADIUS, MAX_RADIUS)
			local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
			local newPos = attackerRoot.Position + offset
			return Vector3.new(newPos.X, targetRoot.Position.Y, newPos.Z)
		end
		return targetRoot.Position
	end
	targetRoot.CFrame = CFrame.new(getValidPosition())
end

function Time:RevengeCounter(char: Model, target: Model) end

function Time:R(char: Model)
	if char:GetAttribute("Mode2") then
		Mode2_R(self, char)
	elseif char:GetAttribute("Mode1") then
		Mode1_R(self, char)
	end
end

function Time:Z(char: Model)
	if char:GetAttribute("Mode2") then
		Mode2_Z(self, char)
	elseif char:GetAttribute("Mode1") then
		Mode1_Z(self, char)
	end
end

function Time:X(char: Model)
	if char:GetAttribute("Mode2") then
		Mode2_X(self, char)
	elseif char:GetAttribute("Mode1") then
		Mode1_X(self, char)
	end
end

function Time:C(char: Model)
	if char:GetAttribute("Mode2") then
		Mode2_C(self, char)
	elseif char:GetAttribute("Mode1") then
		Mode2_C(self, char)
	end
end

function Time:V(char: Model)
	if char:GetAttribute("Mode2") then
		Mode2_V(self, char)
	elseif char:GetAttribute("Mode1") then
		Mode1_V(self, char)
	end
end

return Time
