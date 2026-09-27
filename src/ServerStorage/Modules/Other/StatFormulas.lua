local module = {}

local CONFIG = {
	VIT = {
		BASE_HEALTH = 250,
		VIT_HEALTH_MULTIPLIER = 1,
		LOW_HEALTH_THRESHOLD = 0.25,
	},

	MANA = {
		Floor = 80,
		Cap = 320,
		K = 0.045,
		Midpoint = 110,
		TailStart = 160,
	},

	MF = {
		Floor = 40,
		Cap = 120,
		K = 0.045,
		Midpoint = 110,
		TailStart = 160,
		BuildupRate = 0.5,
		END_SUB = {
			Floor = 0,
			Cap = 20,
			K = 0.05,
			Midpoint = 99,
			TailStart = 99,
		},
	},

	END = {
		Floor = 80,
		Cap = 240,
		K = 0.045,
		Midpoint = 110,
		TailStart = 160,
	},

	WPN = {
		Floor = 0,
		Cap = 160,
		K = 0.05,
		Midpoint = 99,
		TailStart = 99,
	},

	EXP = {
		k = 0.08,
		MidPoint = 50,
		Base = 100,
		Gain = 2300,
	},

	TRANSFORM = {
		StatMult = 2.5, -- 2.5x boost when using mode2
	},
}

local STAT_MULT_ATTRIBUTE = "StatMult"

local function Curve(x, cfg)
	local range = cfg.Cap - cfg.Floor

	if x <= cfg.TailStart then
		local e = math.exp(-cfg.K * (x - cfg.Midpoint))
		return cfg.Floor + range / (1 + e)
	end

	local d = 1 + math.exp(-cfg.K * (cfg.TailStart - cfg.Midpoint))
	local Value = cfg.Floor + range / d
	local Slope = range * cfg.K * math.exp(-cfg.K * (cfg.TailStart - cfg.Midpoint)) / (d * d)

	return Value + Slope * (x - cfg.TailStart)
end

function module.GetStat(char, stat, default)
	local base = char:GetAttribute(stat) or default or 0
	local mult = char:GetAttribute(STAT_MULT_ATTRIBUTE) or 1
	return math.ceil(base * mult)
end

function module.MaxMana(SPT)
	return math.ceil(Curve(SPT, CONFIG.MANA))
end

function module.MaxMF(SPT, END)
	return math.ceil(Curve(SPT, CONFIG.MF) + Curve(END, CONFIG.MF.END_SUB))
end

function module.MaxStamina(END)
	return math.ceil(Curve(END, CONFIG.END))
end

function module.WeaponPoints(WPN)
	return Curve(WPN, CONFIG.WPN)
end

function module.MaxHealth(VIT)
	return math.ceil(CONFIG.VIT.BASE_HEALTH + (VIT * CONFIG.VIT.VIT_HEALTH_MULTIPLIER))
end

function module.RequiredEXP(StatPoints)
	return CONFIG.EXP.Base
		+ (CONFIG.EXP.Gain / (1 + math.exp(-CONFIG.EXP.k * ((StatPoints + 1) - CONFIG.EXP.MidPoint))))
end

module.CONFIG = CONFIG
module.STAT_MULT_ATTRIBUTE = STAT_MULT_ATTRIBUTE

return module
