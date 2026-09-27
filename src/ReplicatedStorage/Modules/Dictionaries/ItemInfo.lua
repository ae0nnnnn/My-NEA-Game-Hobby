-- TODO: rather than having the stats decalred here have the maxium number of each rairty of pip for each item

--- alsp just dumping this here for now as one the npc drop and chest system is created it would be needed
local thing = {
["Corrupted"] = {
			Crit_RateBonus = 0,
            Crit_DamageBonus = 0,
            PEN = 0,
            Flat_HP_Bonus = 0,
            Percent_HP_Bonus = 0,
            Phyiscal_Resistance = 0,
            Magical_Resistance = 0,
            Speed_Bonus = 0
		},

		["Legendary"] = {
			Crit_RateBonus = 0,
            Crit_DamageBonus = 0,
            PEN = 0,
            Flat_HP_Bonus = 0,
            Percent_HP_Bonus = 0,
            Phyiscal_Resistance = 0,
            Magical_Resistance = 0,
            Speed_Bonus = 0
		},


		["Epic"] = {
			Crit_RateBonus = 0,
            Crit_DamageBonus = 0,
            PEN = 0,
            Flat_HP_Bonus = 0,
            Percent_HP_Bonus = 0,
            Phyiscal_Resistance = 0,
            Magical_Resistance = 0,
            Speed_Bonus = 0
		},

		["Rare"] = {
			Crit_RateBonus = 0,
            Crit_DamageBonus = 0,
            PEN = 0,
            Flat_HP_Bonus = 0,
            Percent_HP_Bonus = 0,
            Phyiscal_Resistance = 0,
            Magical_Resistance = 0,
            Speed_Bonus = 0
		},	
        
        
}

local ItemInfo = {}
local info = {
    ["Hat"] = {
        Type = "Accessory",
        EquipSlot = "Hat",
        StackType = "Non-Stackable",
        Stats = {
            Crit_RateBonus = 0.05,
            Crit_DamageBonus = 0.1,
            PEN = 0,
            Flat_HP_Bonus = 50,
            Percent_HP_Bonus = 0.1,
        },

        Skills = {
            ["Swift"] = {
                Description = "5% faster movement speed for 5 seconds after using a skill.",
                Cooldown = 10,
            },
            ["Resilient"] = {
                Description = "Reduces incoming damage by 15% for 3 seconds after taking damage.",
                Cooldown = 45,
            },
        }
    },

    ["Halo"] = {
        Type = "Accessory",
        EquipSlot = "Hat",
        StackType = "Non-Stackable",

        Stats = {
            Crit_RateBonus = 0.05,
            Crit_DamageBonus = 0.1,
            PEN = 0,
            Flat_HP_Bonus = 50,
            Percent_HP_Bonus = 0.1,
        },

         Skills = {
            ["Swift"] = {
                Description = "5% faster movement speed for 5 seconds after using a skill.",
                Cooldown = 10,
            },
            ["Resilient"] = {
                Description = "Reduces incoming damage by 15% for 3 seconds after taking damage.",
                Cooldown = 45,
            },
        }


    },


    ["Dumbbell"] = {
        Type = "TrainingItem",
        StackType = "Non-Stackable",
        Uses = 350,
    },

    ["Glock"] = {
        Type = "Material",
        StackType = "Stackable",
        MaxStack = 20,
    },

    ["Modifiers"] = {

        ["Template"] = {
            Bonus_Stats = {
                Crit_RateBonus = 0,
                Crit_DamageBonus = 0,
                PEN = 0,
                Flat_HP_Bonus = 0,
                Percent_HP_Bonus = 0,
                Phyiscal_Resistance = 0,
                Magical_Resistance = 0,
                Speed_Bonus = 0,
            }

        },
        ["Warding"] = {
            Bonus_Stats = {
                Crit_RateBonus = 0,
                Crit_DamageBonus = 0,
                PEN = 0,
                Flat_HP_Bonus = 10,
                Percent_HP_Bonus = 0,
                Phyiscal_Resistance = 1.1,  -- 101%
                Magical_Resistance = 1.1,
                Speed_Bonus = 0.95,  -- -5%
            }

        },

        ["Agile"] = {
            Bonus_Stats = {
                Crit_RateBonus = 0.05,
                Crit_DamageBonus = 0.1,
                PEN = 0,
                Flat_HP_Bonus = 0,
                Percent_HP_Bonus = 0,
                Phyiscal_Resistance = 0,
                Magical_Resistance = 0,
                Speed_Bonus = 0.05,
            }

        },





    }


}





export type ItemINFO = typeof(info.Hat) -- would tweak to handle the others later


function ItemInfo.getStats(item): ItemINFO
    return info[item]
end


return ItemInfo