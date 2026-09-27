local module = {}

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local MovementData = require(RS.Modules.Movement.Data)
local StatFormulas = require(SS.Modules.Other.StatFormulas)
local Helpful = require(SS.Modules.Other.Helpful)

local Tracked = setmetatable({}, { __mode = "k" })

local AIRBORNE_STATES = {
	[Enum.HumanoidStateType.Jumping] = true,
	[Enum.HumanoidStateType.Freefall] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
}

local function GetFallReduction(char)
	local data = MovementData.Data
	local endStat = StatFormulas.GetStat(char, "END")
	local endReduction = data.FallReductionEndMax * math.clamp(endStat / data.FallEndStatMax, 0, 1)
	local talentBonus = char:GetAttribute("FallReductionBonus") or 0
	return math.min(data.FallReductionCap, endReduction + talentBonus)
end

function module.GetFallReduction(char)
	return GetFallReduction(char)
end

function module.Untrack(char)
	local record = Tracked[char]
	if record then
		for _, conn in ipairs(record.conns) do
			conn:Disconnect()
		end
		Tracked[char] = nil
	end
end

local function Bind(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then
		return
	end

	local record = {
		conns = {},
		airborne = false,
		peakY = 0,
	}

	-- Peak Y is tracked across the WHOLE airborne window (jump + double jump +
	-- freefall), so a double jump that lifts you mid-fall still counts its full
	-- height toward the fall instead of only measuring from first-Freefall-entry.
	local function onState(_, newState)
		if AIRBORNE_STATES[newState] then
			record.airborne = true
			record.peakY = math.max(record.peakY, hrp.Position.Y)
		elseif newState == Enum.HumanoidStateType.Landed and record.airborne then
			record.airborne = false

			local fallDistance = math.max(0, record.peakY - hrp.Position.Y)
			record.peakY = 0

			local data = MovementData.Data
			if fallDistance <= data.SafeFallDistance then
				return
			end

			local rawDamage = (fallDistance - data.SafeFallDistance) * data.FallDamagePerStud
			local damage = math.ceil(rawDamage * (1 - GetFallReduction(char)))
			if damage > 0 then
				Helpful.DamageDealer(char, damage)
			end
		end
	end

	table.insert(record.conns, hum.StateChanged:Connect(onState))
	table.insert(record.conns, RunService.Heartbeat:Connect(function()
		if record.airborne and hrp.Parent then
			record.peakY = math.max(record.peakY, hrp.Position.Y)
		end
	end))
	table.insert(record.conns, hum.Died:Connect(function()
		module.Untrack(char)
	end))
	table.insert(record.conns, char.AncestryChanged:Connect(function()
		if not char.Parent then
			module.Untrack(char)
		end
	end))

	Tracked[char] = record
end

function module.ResetPeak(char)
	local record = Tracked[char]
	if not record then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	record.peakY = hrp.Position.Y
end

function module.TrackCharacter(char)
	if Tracked[char] then
		return
	end
	Bind(char)
end

return module