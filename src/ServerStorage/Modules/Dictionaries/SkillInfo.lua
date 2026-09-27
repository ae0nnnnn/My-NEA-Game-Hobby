local SkillInfo = {}

SkillInfo.Elements = {
	Astral = {
		R = {
			Mode1 = { 
				Name = "", 
				Type = "Heavy", 
				DamageType = "Phys",
				ParryInterupt = true,
				CanParry = true,
				CanHyprParry = false,
		 },

			Mode2 = {
				 Name = "",
				 Type = "Heavy",
				 ParryInterupt = true 
				},
		},
		Z = {
			Mode1 = { Name = "", Type = "Light", ParryInterupt = true },
			Mode2 = { Name = "", Type = "Light", ParryInterupt = true },
		},
		X = {
			Mode1 = { Name = "", Type = "Light", ParryInterupt = true },
			Mode2 = { Name = "", Type = "Light", ParryInterupt = true },
		},
		C = {
			Mode1 = { Name = "", Type = "Heavy", ParryInterupt = true },
			Mode2 = { Name = "", Type = "Heavy", ParryInterupt = true },
		},
		V = {
			Mode1 = { Name = "", Type = "Heavy", ParryInterupt = true },
			Mode2 = { Name = "", Type = "Heavy", ParryInterupt = true },
		},
	},
	Time = {
		R = {
			Mode1 = { Name = "WeaponSwap", Type = "None", ParryInterupt = false },
			Mode2 = { Name = "", Type = "Heavy", ParryInterupt = true },
		},
		Z = {
			Mode1 = { Name = "", Type = "Light", ParryInterupt = true },
			Mode2 = { Name = "", Type = "Light", ParryInterupt = true },
		},
		X = {
			Mode1 = { Name = "", Type = "Light", ParryInterupt = true },
			Mode2 = { Name = "", Type = "Light", ParryInterupt = true },
		},
		C = {
			Mode1 = { Name = "", Type = "Heavy", ParryInterupt = true },
			Mode2 = { Name = "", Type = "Heavy", ParryInterupt = true },
		},
		V = {
			Mode1 = { Name = "", Type = "Heavy", ParryInterupt = true },
			Mode2 = { Name = "", Type = "Heavy", ParryInterupt = true },
		},
	},
}

SkillInfo.Stats = {
	WPN = {
		SlashStorm = {
			Name = "SlashStorm",
			Type = "Light",
			DamageType = "Phys",
			ParryInterupt = false,
			CanParry = true,
			CanHyprParry = false,
			Costs = {
				Stamina = 15,
			},
		},
	},
	DEX = {},
	STR = {},
	AGL = {},
	SPT = {},
}

function SkillInfo.getSkill(skillName)
	for _, statFolder in pairs(SkillInfo.Stats) do
		if statFolder[skillName] then
			return statFolder[skillName]
		end
	end

	for _, element in pairs(SkillInfo.Elements) do
		for _, slot in pairs(element) do
			for _, mode in pairs(slot) do
				if mode.Name == skillName then
					return mode
				end
			end
		end
	end

	return nil
end

-- NPC skills keyed by mob name (populate when mobs are added)
-- SkillInfo.NPCs = {
-- 	["MobName"] = {
-- 		SkillName =  {
--            Type = "Light" , CanParry = false, CanHyprParry = true
--        }
--
-- 	},
-- }

return SkillInfo
