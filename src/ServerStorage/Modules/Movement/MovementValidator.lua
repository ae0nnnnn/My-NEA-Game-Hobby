--// MovementValidator
--// Server-authoritative sanity checks for client-fired MovementEvent actions.
--// Mirrors the authoritative Humanoid state (air/ground) and jump usage so the
--// server can reject state-spoofing/farming without replicating the whole
--// client-side movement simulation.

local module = {}

local RS = game:GetService("ReplicatedStorage")

local Movement = require(RS.Modules.Movement.Objects.Movement)
local ClientTypes = require(RS.Modules.ClientTypes)
local MovementData = require(RS.Modules.Movement.Data)
local FlowManager = require(RS.Modules.Movement.Ultils.Flow)

local States = setmetatable({}, { __mode = "k" })

local MAX_FLOW_BONUS = FlowManager.Config.MaxFlowBonus

local AIR_GRACE = 0.15

--// Minimum seconds between accepted attempts, per action. Tighter values kill
--// spam; anything closer is silently dropped (no kick).
local RATES = {
	SprintStart = 0.1,
	SprintEnd = 0.1,
	ExSprintStart = 0.4,
	ExSprintEnd = 0.4,
	WallRunStart = 0.2,
	WallRunEnd = 0.1,
	WallRunJump = 0.2,
	DoubleJump = 0.05,
	Climb = 0.3,
	Dodge = MovementData.Data.DodgeCooldown,
	Dive = MovementData.Data.DiveCooldown,
	DodgeCancel = MovementData.Data.DodgeCancelCooldown,
	CrouchStart = 0.1,
	CrouchEnd = 0.1,
	SlideStart = 0.1,
	SlideEnd = 0.1,
	LedgeHold = 0.5,
	ReleaseLedge = 0.5,
	FlowUpdate = 0.1,
}

--// Which failure reasons escalate to a kick. Anything not true here is
--// silently dropped.
local KICK_REASONS = {
	untracked = false,
	rate = false,
	blocked = false,
	spoof = true,
}

local function WasRecentlyAirborne(state, char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.FloorMaterial == Enum.Material.Air then
		return true
	end
	if state.air then
		return true
	end
	-- Fresh upward velocity = just jumped (covers the server-state lag window
	-- on rapid double-jumps, same secondary check the old dodge code used).
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp and hrp.AssemblyLinearVelocity.Y > 5 then
		return true
	end
	return state.lastAirborneAt and (os.clock() - state.lastAirborneAt) < AIR_GRACE
end

local function CheckAction(state, char, MovementObj:ClientTypes.MovementObj, action, ...)
	local acting = MovementObj.IsActing
	local states = MovementObj.States

	--// "blocked" = real state conflicts that can also happen from harmless
	--// client/server timing races (e.g. buffered inputs during an attack).
	--// Never kick for these. "spoof" = provable exploit/farming; kick.
	if char:GetAttribute("Stunned") then return false, "blocked" end
	if char:GetAttribute("IsRagdoll") then return false, "blocked" end
	if char:GetAttribute("IsBlocking") then return false, "blocked" end
	if char:GetAttribute("Attacking") then return false, "blocked" end

	if action == "SprintStart" then
		if acting.IsSprinting or acting.IsEXSprinting then return false, "blocked" end
		if acting.Climbing or acting.WallRunning or acting.Dodging then return false, "blocked" end
		if states.IsCrouching then return false, "blocked" end
		-- Note: no grounded check. The client legitimately starts sprinting while
		-- airborne (double-tap W buffering a landing), and client/server landing
		-- state can diverge, so a grounded heuristic is not provable.
	elseif action == "SprintEnd" then
		if not acting.IsSprinting and not acting.IsEXSprinting then return false, "blocked" end
	elseif action == "Climb" then
		if acting.WallRunning or acting.Dodging then return false, "blocked" end 
		if not WasRecentlyAirborne(state, char) then return false, "blocked" end 

		if char:GetAttribute("InCombat") then
			local info = MovementObj.InfoTable and MovementObj.InfoTable.Climb
			local freeClimbs = (info and info.FreeClimbs) or MovementData.Data.MaxClimbsPerSet
			if state.climbsUsed >= freeClimbs then return false, "spoof" end 
		end
	elseif action == "ExSprintStart" then
		if not acting.IsSprinting or acting.IsEXSprinting then return false, "blocked" end
	elseif action == "ExSprintEnd" then
		if not acting.IsEXSprinting then return false, "blocked" end
	elseif action == "WallRunStart" then
		if acting.WallRunning or acting.Climbing or acting.Dodging then return false, "blocked" end
		-- Airborne mismatch is a client/server state race (e.g. low wall runs
		-- where the server humanoid grounds out first), not proof of a cheat.
		if not WasRecentlyAirborne(state, char) then return false, "blocked" end
	elseif action == "WallRunEnd" then
		if not acting.WallRunning then return false, "blocked" end
	elseif action == "WallRunJump" then
		-- The boost is client-side; the mirror check is consistency only, and the
		-- client tears down the wall run before the jump remote arrives. Never kick.
		if not acting.WallRunning then return false, "blocked" end
		if not WasRecentlyAirborne(state, char) then return false, "blocked" end
	elseif action == "DoubleJump" then
		if acting.Climbing or acting.WallRunning or acting.Dodging then return false, "blocked" end
		-- Airborne mismatch is a state race; the jump-count is the hard gate.
		if not WasRecentlyAirborne(state, char) then return false, "blocked" end
		-- Free pool is declarable per character (talents write
		-- MovementObj.InfoTable.DoubleJump.FreeJumps). In combat the pool is a
		-- HARD cap -- no stamina-purchased jumps. Out of combat, jumps past the
		-- pool are paid for with stamina server-side (MovementServer), so the
		-- validator only needs the combat ceiling.
		if char:GetAttribute("InCombat") then
			local info = MovementObj.InfoTable and MovementObj.InfoTable.DoubleJump
			local freeJumps = (info and info.FreeJumps) or MovementData.Data.DoubleJumps
			if state.jumpsUsed >= freeJumps then return false, "spoof" end
		end
	elseif action == "Dodge" then
		if acting.Dodging then return false, "spoof" end
	elseif action == "Dive" then
		-- Dive is a stance, not a burst: entry-gated on air + not already
		-- diving. Air mismatch is a state race -> blocked, never kick.
		if acting.Dodging then return false, "blocked" end
		if not WasRecentlyAirborne(state, char) then return false, "blocked" end
	elseif action == "DodgeCancel" then
		if not acting.Dodging and not char:GetAttribute("Dodging") then return false, "blocked" end
	elseif action == "CrouchStart" then
		if states.IsCrouching then return false, "blocked" end
		if acting.Dodging or acting.Climbing or acting.WallRunning then return false, "blocked" end
	elseif action == "CrouchEnd" then
		if not states.IsCrouching then return false, "blocked" end
	elseif action == "SlideStart" then
		if states.ISSliding then return false, "blocked" end
		if acting.Dodging or acting.Climbing or acting.WallRunning then return false, "blocked" end
		if not acting.IsSprinting and not acting.IsEXSprinting then return false, "blocked" end
	elseif action == "SlideEnd" then
		if not states.ISSliding then return false, "blocked" end
	elseif action == "LedgeHold" then
		if acting.Climbing then return false, "blocked" end
		if not WasRecentlyAirborne(state, char) then return false, "blocked" end
	elseif action == "ReleaseLedge" then
		-- Harmless either way; rate-limit handles abuse.
		return true, "ok"
	elseif action == "FlowUpdate" then
		local value = ...
		if type(value) ~= "number" or value < 1.0 or value > MAX_FLOW_BONUS + 0.01 then
			return false, "spoof"
		end
	end

	return true, "ok"
end

function module.Validate(player, action, ...)
	local state = States[player]
	if not state then return false, "untracked" end
	local char = state.char
	if not char or not char.Parent then return false, "untracked" end

	local rate = RATES[action]
	if rate then
		local now = os.clock()
		local last = state.lastAction[action] or 0
		if now - last < rate then
			return false, "rate"
		end
	end

	local MovementObj = Movement.GetMovementObj(player)
	if not MovementObj then return false, "untracked" end

	local ok, reason = CheckAction(state, char, MovementObj, action, ...)
	if not ok then return false, reason end

	state.lastAction[action] = os.clock()

	if action == "DoubleJump" then
		state.jumpsUsed = state.jumpsUsed + 1
	end

	if action == "Climb" then
		state.climbsUsed = state.climbsUsed + 1
	end

	return true, "ok"
end

function module.ShouldKick(reason)
	return KICK_REASONS[reason] == true
end

function module.Track(player)
	if States[player] then return end
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	local state = {
		char = char,
		lastAction = {},
		air = false,
		jumpsUsed = 0,
		climbsUsed = 0,
		lastAirborneAt = 0,
		connection = nil,
	}

	state.connection = hum.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Freefall
			or newState == Enum.HumanoidStateType.Jumping
			or newState == Enum.HumanoidStateType.Climbing then
			state.air = true
			state.lastAirborneAt = os.clock()
		elseif newState == Enum.HumanoidStateType.Landed
			or newState == Enum.HumanoidStateType.Running then
			state.air = false
			state.jumpsUsed = 0
			state.climbsUsed = 0
		end
	end)

	States[player] = state
end

function module.Untrack(player)
	local state = States[player]
	if state then
		if state.connection then state.connection:Disconnect() end
		States[player] = nil
	end
end

function module.IsAirborne(player)
	local state = States[player]
	return state and state.air or false
end

function module.ResetJumps(player)
	local state = States[player]
	if state then
		state.jumpsUsed = 0
	end
end

function module.GetJumpsUsed(player)
	local state = States[player]
	return state and state.jumpsUsed or 0
end

function module.GetClimbsUsed(player)
	local state = States[player]
	return state and state.climbsUsed or 0
end

return module
