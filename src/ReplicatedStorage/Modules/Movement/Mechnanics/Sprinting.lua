local Sprinting = {}
local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local RSModules = RS.Modules
local ClientTypes = require(RSModules.ClientTypes)
local FlowManager = require(RSModules.Movement.Ultils.Flow)
local MovementData = require(RSModules.Movement.Data)
local AnimationsFolder = RSModules.Movement.Objects.Movement.Animations

local Debounce = {}
local EX_Debounce = {}
local SprintConns = {}
local SpeedMods = require(RSModules.Movement.Ultils.Speed)
local cam = workspace.CurrentCamera

function Sprinting.CanSprint(MovementObj: ClientTypes.MovementObj)
	local char = MovementObj.char
	return not (
		char:GetAttribute("Stunned")
		or char:GetAttribute("IsRagdoll")
		or char:GetAttribute("IsBlocking")
		or char:GetAttribute("Attacking")
		or char:GetAttribute("IsCrouching")
		or MovementObj.IsActing.Climbing
		or MovementObj.IsActing.WallRunning
		or MovementObj.States.IsCrouching
	)
end

local function ResetSpeedCheck(MovementObj: ClientTypes.MovementObj)
	local char = MovementObj.char
	return not (
		char:GetAttribute("Stunned")
		or char:GetAttribute("IsBlocking")
		or char:GetAttribute("Attacking")
		or char:GetAttribute("IsCrouching")
		or MovementObj.IsActing.Climbing
		or MovementObj.IsActing.WallRunning
	)
end

local function selectionSprintAnim(MovementObj: ClientTypes.MovementObj)
	local Target = nil
	local char = MovementObj.char
	local Hum = char:FindFirstChildOfClass("Humanoid")

	if not char or not Hum then
		return
	end

	if MovementObj.InfoTable.Sprint.SprintAnim then
		MovementObj.InfoTable.Sprint.SprintAnim:Stop(0.1)
		MovementObj.InfoTable.Sprint.SprintAnim:Destroy()
		MovementObj.InfoTable.Sprint.SprintAnim = nil
	end

	if char:GetAttribute("Equipped") == true then
		if char:GetAttribute("InCombat") and char:GetAttribute("IsLow") then
			Target = AnimationsFolder.Weapons[char:GetAttribute("CurrentWeapon")].IsLow.Sprint
		else
			Target = AnimationsFolder.Weapons[char:GetAttribute("CurrentWeapon")].Sprint
		end
	elseif char:GetAttribute("InCombat") and char:GetAttribute("IsLow") then
		Target = AnimationsFolder.IsLow.Sprint
	else
		Target = AnimationsFolder.Sprint
	end

	MovementObj.InfoTable.Sprint.SprintAnim = Hum.Animator:LoadAnimation(Target)
	MovementObj.InfoTable.Sprint.SprintAnim:Play(0.25)
end

function Sprinting.ForceStopAllSprinting(MovementObj: ClientTypes.MovementObj)
	local char = MovementObj.char
	local Hum = char:FindFirstChildOfClass("Humanoid")

	MovementObj.IsActing.IsSprinting = false
	MovementObj.IsActing.IsEXSprinting = false

	if Hum and ResetSpeedCheck(MovementObj) then
		FlowManager.OnSprintStop(MovementObj, SpeedMods.GetMovementSpeed(char, "WalkSpeed", "Walk"))
	end

	TS:Create(cam, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { FieldOfView = MovementData.Data.BaseFov }):Play()

	if MovementObj.InfoTable.Sprint.SprintAnim then
		MovementObj.InfoTable.Sprint.SprintAnim:Stop(0.1)
		MovementObj.InfoTable.Sprint.SprintAnim:Destroy()
		MovementObj.InfoTable.Sprint.SprintAnim = nil
	end

	if SprintConns[MovementObj] then
		SprintConns[MovementObj]:Disconnect()
		SprintConns[MovementObj] = nil
	end

	MovementObj:ServerRequest("SprintEnd")
	MovementObj:ServerRequest("ExSprintEnd")
	MovementObj:UpdateWalkTracks()
end

function Sprinting.NormalToggle(MovementObj: ClientTypes.MovementObj)
	local char = MovementObj.char
	local Hum = char:FindFirstChildOfClass("Humanoid")

	if not Hum or not char or Debounce[MovementObj] then
		return
	end
	Debounce[MovementObj] = true

	if MovementObj.IsActing.IsSprinting or MovementObj.IsActing.IsEXSprinting then
		Sprinting.ForceStopAllSprinting(MovementObj)
		task.wait(0.1)
		Debounce[MovementObj] = false
	else
		pcall(function() MovementObj:CancelConflictingActions("SprintStart") end)
		if not Sprinting.CanSprint(MovementObj) then
			Debounce[MovementObj] = false
			return
		end

		MovementObj.IsActing.IsSprinting = true
		MovementObj:ServerRequest("SprintStart")

		-- IsLow+InCombat reduction is centralized in SpeedMods.GetIsLowFactor,
		-- so the low sprint keys are gone -- the getter applies the factor.
		local targetSpeed = SpeedMods.GetMovementSpeed(char, "SprintSpeed", "Sprint")
		-- FLOW ENGAGEMENT
		FlowManager.OnSprintStart(MovementObj, targetSpeed, false)
		if MovementObj.Flow then
			MovementObj.Flow.CurrentSpeed = targetSpeed -- Instant snap initialization
		end

		Hum.WalkSpeed = targetSpeed

		TS:Create(cam, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { FieldOfView = MovementData.Data.SprintFov })
			:Play()
		selectionSprintAnim(MovementObj)

		SprintConns[MovementObj] = RunService.Heartbeat:Connect(function()
			if not MovementObj.InfoTable.Sprint.SprintAnim then
				return
			end
			if MovementObj.States.IsInAir then
				MovementObj.InfoTable.Sprint.SprintAnim:AdjustSpeed(0.25)
			else
				MovementObj.InfoTable.Sprint.SprintAnim:AdjustSpeed(1)
			end
		end)

		MovementObj:ClearWalkAnims()
		task.wait(0.1)
		Debounce[MovementObj] = false
	end
end

function Sprinting.OnCharStateChanged(MovementObj: ClientTypes.MovementObj)
	local char = MovementObj.char
	local HRP = char:FindFirstChild("HumanoidRootPart")

	if not HRP or not char.Parent then
		return
	end

	if not Sprinting.CanSprint(MovementObj) or HRP.Anchored then
		if MovementObj.IsActing.IsSprinting or MovementObj.IsActing.IsEXSprinting then
			MovementObj.IsActing.IsSprinting = false
			MovementObj.IsActing.IsEXSprinting = false

			local Hum = char:FindFirstChildOfClass("Humanoid")
			if Hum and ResetSpeedCheck(MovementObj) then
				FlowManager.OnSprintStop(MovementObj, SpeedMods.GetMovementSpeed(char, "WalkSpeed", "Walk"))
			end

			TS:Create(cam, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { FieldOfView = MovementData.Data.BaseFov })
				:Play()

			if MovementObj.InfoTable.Sprint.SprintAnim then
				MovementObj.InfoTable.Sprint.SprintAnim:Stop(0.1)
				MovementObj.InfoTable.Sprint.SprintAnim:Destroy()
				MovementObj.InfoTable.Sprint.SprintAnim = nil
			end

			if SprintConns[MovementObj] then
				SprintConns[MovementObj]:Disconnect()
				SprintConns[MovementObj] = nil
			end

			MovementObj:ServerRequest("SprintEnd")
			MovementObj:ServerRequest("ExSprintEnd")
			MovementObj:UpdateWalkTracks()
		end
	end
end

function Sprinting.ExToggle(MovementObj: ClientTypes.MovementObj)
	local char = MovementObj.char
	local Hum = char:FindFirstChildOfClass("Humanoid")

	if not Hum or not char or EX_Debounce[MovementObj] then
		return
	end
	EX_Debounce[MovementObj] = true

	-- IF ACTIVELY EX SPRINTING: Drop back down to normal sprint tier
	if MovementObj.IsActing.IsEXSprinting then
		MovementObj.IsActing.IsEXSprinting = false
		MovementObj:ServerRequest("ExSprintEnd")

		local targetSpeed = SpeedMods.GetMovementSpeed(char, "ExSprintFallbackSpeed", "Sprint")

		-- FLOW ENGAGEMENT: Update flow target back down to normal sprint specs
		FlowManager.OnSprintStart(MovementObj, targetSpeed, false)
		if MovementObj.Flow then
			MovementObj.Flow.CurrentSpeed = targetSpeed
		end

		selectionSprintAnim(MovementObj)
		TS:Create(cam, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { FieldOfView = MovementData.Data.SprintFov })
			:Play()

		task.wait(0.1)
		EX_Debounce[MovementObj] = false
	else
		-- IF NOT EX SPRINTING: Upgrade to ExSprint tier
		pcall(function() MovementObj:CancelConflictingActions("ExSprintStart") end)
		if not MovementObj.IsActing.IsSprinting or not Sprinting.CanSprint(MovementObj) then
			EX_Debounce[MovementObj] = false
			return
		end

		MovementObj.IsActing.IsEXSprinting = true

		local targetSpeed = SpeedMods.GetMovementSpeed(char, "ExSprintSpeed", "Sprint")

		-- FLOW ENGAGEMENT FIXED: Explicitly alert the Flow engine of your upgraded speed target!
		FlowManager.OnSprintStart(MovementObj, targetSpeed, true)
		if MovementObj.Flow then
			MovementObj.Flow.CurrentSpeed = targetSpeed -- Prevent slow acceleration curve gaps
		end

		Hum.WalkSpeed = targetSpeed

		TS:Create(cam, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { FieldOfView = MovementData.Data.ExSprintFov })
			:Play()
		selectionSprintAnim(MovementObj)

		task.spawn(function()
			while MovementObj.IsActing.IsEXSprinting and char.Parent do
				MovementObj:ServerRequest("ExSprintStart")
				task.wait(0.5)

				if char:GetAttribute("IsEXSprinting") == false then
					Sprinting.ForceStopAllSprinting(MovementObj)
					break
				end
			end
		end)

		task.wait(0.1)
		EX_Debounce[MovementObj] = false
	end
end

return Sprinting
