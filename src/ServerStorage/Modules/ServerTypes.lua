local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ClientTypes = require(RS.Modules.ClientTypes)
local DataManager = require(ServerScriptService.Data.Modules.DataManager)
local Template = require(ServerScriptService.Data.Template)

local module = {}

-- Re-export shared base types
export type MovementObjData = ClientTypes.MovementObjData
export type MovementObjMethods = ClientTypes.MovementObjMethods
export type MovementObj = ClientTypes.MovementObj

---------------------------------------------
-- Element
---------------------------------------------

export type ElementBase<Data = { [string]: any }> = {
	Name: string,
	Data: Data,
	R: (self: ElementBase<Data>, char: Model) -> (),
	Z: (self: ElementBase<Data>, char: Model) -> (),
	X: (self: ElementBase<Data>, char: Model) -> (),
	C: (self: ElementBase<Data>, char: Model) -> (),
	V: (self: ElementBase<Data>, char: Model) -> (),
	Innate: ((self: ElementBase<Data>, char: Model) -> ())?,
	Mode1Init: ((self: ElementBase<Data>, char: Model) -> ())?,
	Mode2Init: ((self: ElementBase<Data>, char: Model) -> ())?,
	RevengeCounter: ((self: ElementBase<Data>, char: Model, target: Model) -> ())?,
}

export type ElementObject = ElementBase<any>
---------------------------------------------
-- PLR
---------------------------------------------

export type PLRData = {
	_cleaned: boolean?,
	IsReady: boolean,
	Highlight: Highlight?,
	HasMoved: boolean,
	Player: Player,
	Data: DataManager.SlotData,
	GlobalData: DataManager.GenData,
	Settings: DataManager.Settings,
	Character: Model,
	CurrentSlot: string,
	FirstName: string,
	LastName: string,
	HairColor: Color3,
	Element: ElementObject,
	MovementObj: MovementObj,
	Intent: string,
	Stats: {
		VIT: number,
		END: number,
		STR: number,
		SPT: number,
		DEX: number,
		AGL: number,
		WPN: number,
	},
	SubStats: {
		PhysPEN: number,
		MagicPEN: number,
		PhysArmour: number,
		MagicArmour: number,
		MaxStamina: number,
		MaxMana: number,
		MaxMF: number,
		CritRate: number,
		CritDmg: number,
		LuckBonus: number,
		SpeedBonus: number,
	},
	Talents: {},
	Skills: {},
}

export type PLRMethods = {
	Cleanup: (self: PLR) -> (),
	Destroy: (self: PLR) -> (),
	IncreaseStat: (self: PLR, statName: string, amount: number) -> (),
	EquipAccessory: (self: PLR, accessoryType: string, accessoryItem: Template.ItemData?) -> (),
	UnequipAccessory: (self: PLR, accessoryType: string) -> (),
	FirstMovement: (self: PLR) -> (),
}

export type PLR = PLRData & PLRMethods

---------------------------------------------
-- NPC
---------------------------------------------

export type NPCData = {
	FirstName: string,
	LastName: string,
	Difficulty: string,
	MobType: string,
	Character: Model,
	Element: ElementObject?,
	Brain: Script,
	Talents: {},
	Skills: {},
	Stats: {},
	SubStats: {
		PhysPEN: number,
		MagicPEN: number,
		PhysArmour: number,
		MagicArmour: number,
		MaxStamina: number,
		MaxMana: number,
		MaxMF: number,
		CritRate: number,
		CritDmg: number,
		LuckBonus: number,
		SpeedBonus: number,
	},
	drops: {},
	MovementObj: MovementObj,
	Intent: string,
	AIObject: {}?,
}

export type NPCMethods = {
	Destroy: (self: NPC) -> (),
	EquipWeapon: (self: NPC) -> (),
	UnequipWeapon: (self: NPC) -> (),
	Start: (self: NPC) -> (),
	Idle: (self: NPC) -> (),
	Attack: (self: NPC) -> (),
	Block: (self: NPC) -> (),
	Unblock: (self: NPC) -> (),
	Dodge: (self: NPC) -> (),
	Parry: (self: NPC) -> (),
	Phase2: (self: NPC) -> (),
	CancelAttack: (self: NPC) -> (),
	CastAblity: (self: NPC) -> (),
	Climb: (self: NPC) -> (),
	WallRun: (self: NPC) -> (),
	AssignGroup: (self: NPC, groupName: string, role: string?) -> (),
	GetGroupName: (self: NPC) -> string?,
}

export type NPC = NPCData & NPCMethods

return module
