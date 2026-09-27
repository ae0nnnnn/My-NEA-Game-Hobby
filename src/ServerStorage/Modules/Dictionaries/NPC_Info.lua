local NPC_Info = {}

---// END is misssing as npcs dont have to worry about stamina so its not needed adn for downtime they would always use the base time

local info = {
	["TestNPC"] = {
		Difficulty = "SmallFry",
		Race = "Anomaly",
		MobType = "Humanoid",
		Element = "Astral",
		Health = 100000,
		Skills = {},
		Talents = {},
		Drops = {},
		STAT_POINTS = {
			VIT = 10,
			Stamina = 255,
			MaxStamina = 255,
			STR = 10,
			SPT = 10,
			DEX = 10,
			AGL = 10,
			WPN = 10,
		},
	},

	["ShootingStar"] = {
		Difficulty = "SmallFry",
		Race = "Anomaly",
		MobType = "Humanoid",
		Element = "Astral",
		Health = 10000,
		Skills = {},
		Talents = {},
		Drops = {},
		STAT_POINTS = {
			VIT = 10,
			Stamina = 255,
			MaxStamina = 255,
			STR = 10,
			SPT = 10,
			DEX = 10,
			AGL = 10,
			WPN = 10,
		},
	},

	["FracturedKunai"] = {
		Difficulty = "SmallFry",
		Race = "Anomaly",
		MobType = "Humanoid",
		Element = "Astral",
		Health = 10000,
		Skills = {},
		Talents = {},
		Drops = {},
		STAT_POINTS = {
			VIT = 10,
			Stamina = 255,
			MaxStamina = 255,
			STR = 10,
			SPT = 10,
			DEX = 10,
			AGL = 10,
			WPN = 10,
		},
	},

	["TestNPC2"] = {
		Difficulty = "Elite",
		Race = "Anomaly",
		MobType = "Humanoid",
		Element = "Astral",
		Health = 10000,
		Skills = {},
		Talents = {},
		Drops = {},
		STAT_POINTS = {
			VIT = 10,
			Stamina = 255,
			MaxStamina = 255,
			STR = 10,
			SPT = 10,
			DEX = 10,
			AGL = 10,
			WPN = 10,
		},
	},

	["SlashStormSpammer"] = {
		Difficulty = "SlashStormSpammer",
		Race = "Anomaly",
		MobType = "Humanoid",
		Element = "Astral",
		Health = 10000,
		Skills = {},
		Talents = {},
		Drops = {},
		STAT_POINTS = {
			VIT = 10,
			Stamina = 255,
			MaxStamina = 255,
			STR = 10,
			SPT = 10,
			DEX = 10,
			AGL = 10,
			WPN = 10,
		},
	},

	["Bandit"] = {
		Difficulty = "Elite",
		Race = "Anomaly",
		MobType = "Humanoid",
		Element = "Astral",
		Chest = false,
		Health = 10000,
		Skills = {},
		Talents = {},
		Drops = {},
		STAT_POINTS = {
			VIT = 10,
			Stamina = 255,
			MaxStamina = 255,
			STR = 10,
			SPT = 10,
			DEX = 10,
			AGL = 10,
			WPN = 10,
		},
	},

	["Asmondaios"] = {
		Difficulty = "Boss",
		Race = "Celestial",
		MobType = "Humanoid",
		Element = "Time",
		Chest = true,
		ChestType = "...",
		Health = 10000,
		Skills = {},
		Talents = {},
		Drops = {},
		STAT_POINTS = {
			VIT = 10,
			Stamina = 255,
			MaxStamina = 255,
			STR = 10,
			SPT = 10,
			DEX = 10,
			AGL = 10,
			WPN = 10,
		},
	},
}

local AIParams = {
	SmallFry = {
		AggroRange = 36,
		AttackRange = 10,
		ReactionTime = 0.2215,
		LowHealthThreshold = 0.18,
		RetreatDuration = 1.0,
		BlockChance = 0.20,
		ParryChance = 0.32,
		HyprParryChance = 0.03,
		DodgeChance = 0.18,
	},
	MiniBoss = {
		AggroRange = 40,
		AttackRange = 10,
		ReactionTime = 0.35,
		LowHealthThreshold = 0.3,
		RetreatDuration = 1.2,
		BlockChance = 0.25,
		ParryChance = 0.4,
		HyprParryChance = 0.05,
		DodgeChance = 0.2,
	},
	Elite = {
		AggroRange = 50,
		AttackRange = 12,
		ReactionTime = 0.2,
		LowHealthThreshold = 0.35,
		RetreatDuration = 0.8,
		BlockChance = 0.4,
		ParryChance = 0.6,
		HyprParryChance = 0.08,
		DodgeChance = 0.3,
	},
	SuperEnemy = {
		AggroRange = 60,
		AttackRange = 14,
		ReactionTime = 0.15,
		LowHealthThreshold = 0.4,
		RetreatDuration = 0.4,
		BlockChance = 0.5,
		ParryChance = 0.7,
		HyprParryChance = 0.12,
		DodgeChance = 0.4,
	},

	Boss = {
		AggroRange = 60,
		AttackRange = 14,
		ReactionTime = 0.15,
		LowHealthThreshold = 0.4,
		RetreatDuration = 0, -- bosses likely never retreat
		BlockChance = 0.4,
		ParryChance = 0.6,
		DodgeChance = 0.3,
		HyprParryChance = 0.08,
	},
}

local Groups = {
	BanditGroup = {
		Leader = "TestNPC",
		Goons = "TestNPC",
		NumberOfGoons = 2,
	},
}

export type Npc_Info = typeof(info.TestNPC)
export type AI_info = typeof(AIParams.Elite)
export type GroupTemplate = typeof(Groups.BanditGroup)

function NPC_Info.getStats(npc):Npc_Info
	return info[npc]
end

-- NEW: lookup AI params by Difficulty tier
function NPC_Info.getAIParams(difficulty):AI_info
	return AIParams[difficulty]
end

function NPC_Info.getGroup(groupName: string): GroupTemplate?
	return Groups[groupName]
end

function NPC_Info.getAllGroups(): {[string]: GroupTemplate}
	return Groups
end

return NPC_Info
