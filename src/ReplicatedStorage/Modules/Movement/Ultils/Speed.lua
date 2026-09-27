local SpeedModule = {}
local RS = game:GetService("ReplicatedStorage")
local MovementData = require(RS.Modules.Movement.Data)

local CONFIG = {
	AGL = {
		Floor = 1.0,
		Cap = 2.5,
		K = 0.06,
		Midpoint = 40,
		TailStart = 70,
	},
	-- Only 75% of the raw curve bonus applies to speeds (25% global reduction).
	BonusReduction = 0.75,
	-- Dodge scales at a fraction of the (already reduced) AGL curve so it stays
	-- powerful but never runaway.
	DodgeAGLStrength = 0.25,
}

local BASE_AGL = 10 -- Starting stat point value; Data.lua speeds are tuned here (mult = 1.0)

local ACTION_ATTRIBUTE = {
	Walk = "SpeedMultiplier",
	Sprint = "SpeedMultiplier",
	ExSprint = "SpeedMultiplier",
	WallRun = "SpeedMultiplier",
	Crouch = "SpeedMultiplier",
	Climb = "SpeedMultiplier",
	Vault = "SpeedMultiplier",
	Jump = "JumpSpeedMultiplier",
	Dodge = "DodgeSpeedMultiplier",
	Attack = "AttackSpeedMultiplier",
}

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

--- Diminishing AGL -> speed multiplier. Normalized so the starting stat value
--- (BASE_AGL) yields exactly 1.0, keeping Data.lua speeds untouched at base stats.
--- Only CONFIG.BonusReduction (85%) of the curve bonus is applied.
function SpeedModule.AGLMult(AGL)
	local a = AGL or BASE_AGL
	return 1 + CONFIG.BonusReduction * (Curve(a, CONFIG.AGL) - Curve(BASE_AGL, CONFIG.AGL))
end

--- Per-action speed multiplier attribute, falling back to the global
--- SpeedMultiplier attribute, then 1.
function SpeedModule.GetSpeedMult(char, action)
	if not char then
		return 1
	end

	local attr = ACTION_ATTRIBUTE[action] or "SpeedMultiplier"
	return char:GetAttribute(attr) or char:GetAttribute("SpeedMultiplier") or 1
end

--- Global speed multiplier (for passives / NPC parry-block slow). Single source
--- is char:GetAttribute("GlobalSpeedMult"), mirrored to Flow.GlobalSpeedMult on client.
function SpeedModule.GetGlobalSpeedMult(char)
	if not char then return 1 end
	return char:GetAttribute("GlobalSpeedMult") or 1
end

--- IsLow + InCombat penalty: 65% of normal speed while both low health and in
--- combat (same gate the old ResetMobility low-penalty used, now centralized so
--- EVERY speed source honors it). Returns 1 otherwise.
function SpeedModule.GetIsLowFactor(char)
	if not char then
		return 1
	end
	if char:GetAttribute("IsLow") and char:GetAttribute("InCombat") then
		return 0.5
	end
	return 1
end

--- Movement speed for an action, scaled by AGL and the action's speed multiplier.
function SpeedModule.GetMovementSpeed(char, dataKey, action)
	local value = MovementData.Data[dataKey]
	if not value then
		warn(string.format("[Speed] Unknown movement data key '%s'", tostring(dataKey)))
		return nil
	end

	local AGL = char and char:GetAttribute("AGL") or 0
	return value * SpeedModule.AGLMult(AGL) * SpeedModule.GetSpeedMult(char, action or dataKey) * SpeedModule.GetIsLowFactor(char)
end

--- Jump-power speed (vertical action speed), scaled by AGL and the Jump multiplier.
function SpeedModule.GetJumpSpeed(char, dataKey)
	local value = MovementData.Data[dataKey]
	if not value then
		warn(string.format("[Speed] Unknown jump data key '%s'", tostring(dataKey)))
		return nil
	end

	local AGL = char and char:GetAttribute("AGL") or 0
	return value * SpeedModule.AGLMult(AGL) * SpeedModule.GetSpeedMult(char, "Jump") * SpeedModule.GetIsLowFactor(char)
end

--- Max momentum pool, scaled by AGL. Normalized so base AGL yields exactly 100
--- (the Momentum system's base pool), keeping the default fill feel untouched.
function SpeedModule.GetMaxMomentum(char)
	local AGL = char and char:GetAttribute("AGL") or BASE_AGL
	return 100 * SpeedModule.AGLMult(AGL) * SpeedModule.GetIsLowFactor(char)
end

--- Dodge speed, scaled softly by AGL (CONFIG.DodgeAGLStrength) plus the Dodge
--- multiplier attribute. Kept weaker than movement speeds by design.
function SpeedModule.GetDodgeSpeed(char)
	local AGL = char and char:GetAttribute("AGL") or BASE_AGL
	local dodgeMult = 1 + CONFIG.DodgeAGLStrength * (SpeedModule.AGLMult(AGL) - 1)
	return MovementData.Data.DodgeSpeed * dodgeMult * SpeedModule.GetSpeedMult(char, "Dodge") * SpeedModule.GetIsLowFactor(char)
end

--- Dodge speed cap, scaled the same soft way as GetDodgeSpeed.
function SpeedModule.GetMaxDodgeSpeed(char)
	local AGL = char and char:GetAttribute("AGL") or BASE_AGL
	local dodgeMult = 1 + CONFIG.DodgeAGLStrength * (SpeedModule.AGLMult(AGL) - 1)
	return MovementData.Data.MaxDodgeSpeed * dodgeMult * SpeedModule.GetSpeedMult(char, "Dodge") * SpeedModule.GetIsLowFactor(char)
end

--- Attack animation speed, softly scaled by AGL so high AGL feels faster but never runaway.
--- Uses 25% of the AGL curve bonus, capped at 1.2. Respects AttackSpeedMultiplier attribute and IsLow.
--- Nerf lever: reduce 0.25 to 0.15 or lower cap if too strong.
function SpeedModule.GetAttackSpeed(char)
	local AGL = char and char:GetAttribute("AGL") or BASE_AGL
	local aglMult = SpeedModule.AGLMult(AGL)
	local attackMult = 1 + 0.20 * (aglMult - 1)
	if attackMult > 1.2 then attackMult = 1.2 end
	if attackMult < 1 then attackMult = 1 end
	return attackMult * SpeedModule.GetSpeedMult(char, "Attack") * SpeedModule.GetIsLowFactor(char)
end

SpeedModule.CONFIG = CONFIG
SpeedModule.BASE_AGL = BASE_AGL

return SpeedModule
