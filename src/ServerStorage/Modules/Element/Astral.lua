local Astral = {}
Astral.__index = Astral

local SS = game:GetService("ServerStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerTypes = require(SS.Modules.ServerTypes)
local Helpful = require(ServerStorage.Modules.Other.Helpful)


type ElementBase = ServerTypes.ElementBase
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



type AstralData = {
	Mode1Weapon: string,
	Mode2Weapon: string,
	Dialogue: { string },
	Type: string
}

export type AstralObject = ElementBaseNoData & { Data: AstralData }

function Astral.new(): AstralObject
	print("Astra")
	local self = (
		setmetatable({
			Name = "Astral" :: "Astral",
			Data = {
				Mode1Weapon = "Fractured_Kunai",
				Mode2Weapon = "ShootingStar",
				Dialogue = { "Hello" },
				Type = "Elemental"
			},
		}, Astral) :: any
	) :: AstralObject
	return self
end


local function Mode1_R(self: AstralObject, char: Model)
	print(char, "Casted R Mode 1")
end
local function Mode1_Z(self: AstralObject, char: Model)
	print(char, "Casted Z Mode 1")
end
local function Mode1_X(self: AstralObject, char: Model)
	print(char, "Casted X Mode 1")
end
local function Mode1_C(self: AstralObject, char: Model)
	print(char, "Casted C Mode 1")
end
local function Mode2_R(self: AstralObject, char: Model)
	print(char, "Casted R Mode 2")
end
local function Mode2_Z(self: AstralObject, char: Model)
	print(char, "Casted Z Mode 2")
end
local function Mode2_X(self: AstralObject, char: Model)
	print(char, "Casted X Mode 2")
end
local function Mode2_C(self: AstralObject, char: Model)
	print(char, "Casted C Mode 2")
end
local function Mode1_V(self: AstralObject, char: Model)
	print(char, "Casted V Mode 1")
end
local function Mode2_V(self: AstralObject, char: Model)
	print(char, "Casted V Mode 2")
end

function Astral:Innate(char: Model)
	
end

function Astral:Mode1Init(char: Model)
	
end

function Astral:Mode2Init(char: Model)
	print("YO")
	Helpful.ApplyGlobalMult(char, "astral", 1.25)
	
end

function Astral:RevengeCounter(char: Model, target: Model) end

function Astral:R(char: Model)
	if char:GetAttribute("Mode2") then
		Mode2_R(self, char)
	elseif char:GetAttribute("Mode1") then
		Mode1_R(self, char)
	end
end

function Astral:Z(char: Model)
	if char:GetAttribute("Mode2") then
		Mode2_Z(self, char)
	elseif char:GetAttribute("Mode1") then
		Mode1_Z(self, char)
	end
end

function Astral:X(char: Model)
	if char:GetAttribute("Mode2") then
		Mode2_X(self, char)
	elseif char:GetAttribute("Mode1") then
		Mode1_X(self, char)
	end
end

function Astral:C(char: Model)
	if char:GetAttribute("Mode2") then
		Mode2_C(self, char)
	elseif char:GetAttribute("Mode1") then
		Mode1_C(self, char)
	end
end

function Astral:V(char: Model)
	if char:GetAttribute("Mode2") then
		Mode2_V(self, char)
	elseif char:GetAttribute("Mode1") then
		Mode1_V(self, char)
	end
end

return Astral