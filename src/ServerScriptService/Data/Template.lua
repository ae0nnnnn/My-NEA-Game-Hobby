local ItemDataTemplate = {
	["Name"] = "", --> the actual name of the item
	["UID"] = "", -->  UILD for when inventory manager creates a new item
	["Stat_Rolls"] = {} :: {[string]: {[string]:number}}?, --> the rolls based on rarity that the item got basically for every tick in each rarity.Subsats the item us given those substat bonus (when created) per tic
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

local SettingsData = {
	["Something"] = {} 
}

--- Prep for later


export type ItemData = typeof(ItemDataTemplate)
export type SkillData = typeof(SkillData)
export type Settings = typeof(SettingsData)

local Template = {
	GENERAL = {
		IsAdmin = false,
		AdminLevel = "None",
		Number_of_Slots = 1,

		Bank = {} :: { ItemData }, --> banks cant hold skills only items, Location = nil here
		BankCash = {
			Gold = 0,
			Silver = 0,
			Copper = 0,
		},
		Number_of_Bankslots = 10,

		Banned = false,
		Ban_Reason = "...",
		Ban_Date = "...",
		Ban_Duration = "...",
		Settings = {} :: Settings,  --- These are the default settings that each slot would use 
	},

	SLOT_1 = {
		--- Actual Slot information
		Current_Slot = "1", -- lowkey not needed
		Difficulty = "...", -- Standard or Skill Check
		Is_Tainted = false, -- This Means if the slot is wiped or not
		LastLocation = {}, -- The last location the player was in, used for teleporting them back there when they log in
		SpawnLocation = "",
		Settings = {} :: Settings, --> this would overide the Global settings alowwing for per slot configs -- handy I know 

		--- Race and Customisation information

		Race = "Mortal",
		Character_Name = "...",
		Character_LastName = "...",
		Sub_Race = "...",
		Flaw = "...",
		Appearance = {
			Gender = "...",
			Eyes = "",
			Mouth = "",
			Skin_Tone = "",
			HairIDs = {} :: { number },
			Hair_Colour = {
				Red = 0,
				Green = 0,
				Blue = 0,
			},
			Clothing = "...",
		},

		--- Combat information
		Element = "...",
			Skills = {
			{
				Name = "SlashStorm",
				Location = 3,
				Modifiers = nil,
				Level = 1,
			},
		} :: { SkillData },
		Talents = {} :: { string },
		Classes = {}, --> might soon add class data type but after i have resolved how i am going to store it 
		PowerLevel = "Squire",

		Accessories = {
			Hat = nil :: ItemData?,
			Face = nil :: ItemData?,
			Torso = nil :: ItemData?,
			Legs = nil :: ItemData?,
			Artefacts = nil :: ItemData?,
			Rings = nil :: ItemData?,
			Collar = nil :: ItemData?,
		},

		Skill_Slots = {
			Combat = {
				Slot1 = nil :: string?, --- now refrences by name to the skills table
				Slot2 = nil :: string?,
				Slot3 = nil :: string?,
				Slot4 = nil :: string?,
			},

			Mobility = {
				Slot1 = nil :: string?,
			},

			Support = {
				Slot1 = nil :: string?,
				Slot2 = nil :: string?,
			},

			WildCard = {
				Slot1 = nil :: string?,
			},
		},

		-- Inventory information
		Inventory = {
			{
				Name = "Hat",
				UID = "test-hat-001",
				Stat_Rolls = {},
				Count = 1,
				Location = -1,
				Modifiers = nil,
				ArtefactType = "Normal",
				IsBound = false,
				BoundUserId = nil,
			},
	
			{
				Name = "Glock",
				UID = "test-glock-003",
				Stat_Rolls = {},
				Count = 18,
				Location = 2,
				Modifiers = nil,
				ArtefactType = nil,
				IsBound = false,
				BoundUserId = nil,
			},
			{
				Name = "Glock",
				UID = "test-glock-004",
				Stat_Rolls = {},
				Count = 5,
				Location = -1,
				Modifiers = nil,
				ArtefactType = nil,
				IsBound = false,
				BoundUserId = nil,
			},
		} :: { ItemData }, -- hotbar is now going to be considered by the new type varible called lcoation
		Cash = {
			Gold = 0,
			Silver = 0,
			Copper = 0,
		},

		-- EXP and Level Information
		GeneralExp = 0, -- The Genaral EXP used for leveling up and converting to Atrribute EXP
		Level = 1, -- Player Level
		FreePoints = 0, -- Free Points to spend on Attributes without the need for EXP
		SkillPoints = 0, -- Points used to unlock skills and talents
		AttributeExp = {
			VIT = 0,
			END = 0,
			STR = 0,
			SPT = 0,
			DEX = 0,
			AGL = 0,
			WPN = 0,
		},

		-- Stats information
		STAT_POINTS = {
			VIT = 10,
			END = 10,
			STR = 10,
			SPT = 10,
			DEX = 10,
			AGL = 10,
			WPN = 10,
		},
	},
}

export type SlotData = typeof(Template.SLOT_1)
export type ProfileData = typeof(Template)
export type GeneralData = typeof(Template.GENERAL)


return Template
