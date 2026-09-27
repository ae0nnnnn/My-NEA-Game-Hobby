--[Services]--
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local SFX = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local TS = game:GetService("TweenService")


local SoundsModule = require(RS.Modules.Combat.SoundsModule)
local Cast = require(RS.Modules.Cast)
local Movement = require(RS.Modules.Movement.Objects.Movement)
local Crouch = require(RS.Modules.Movement.Mechnanics.Crouch)
local Wallrun = require(RS.Modules.Movement.Mechnanics.Wallrun)
local Sprint = require(RS.Modules.Movement.Mechnanics.Sprinting)
local DoubleJump = require(RS.Modules.Movement.Mechnanics.DoubleJump)
local MovementData = require(RS.Modules.Movement.Data)
local SpeedMods = require(RS.Modules.Movement.Ultils.Speed)
local ClientHelpfull = require(RS.Modules.ClientHelpfull)

local VFXFolder = workspace:WaitForChild("VFX")
local NPCFolder = workspace:WaitForChild("NPC")
local CharactersFolder = workspace:WaitForChild("Characters")
--[Player Variables]--
local plr = Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local HRP: Part = char:WaitForChild("HumanoidRootPart")
local Hum = char:WaitForChild("Humanoid")
local cam = workspace.CurrentCamera

--[UI Variables]--
local playerGui = plr:WaitForChild("PlayerGui")
local MovementUI = playerGui:WaitForChild("MovementUI")
local top = MovementUI:WaitForChild("Top")
local bottom = MovementUI:WaitForChild("Bottom")
local Top_tilt = MovementUI:WaitForChild("Top_Tilt")
local Bottom_tilt = MovementUI:WaitForChild("Bottom_Tilt")

local Events = RS.Events
local MovementEvent = Events.Movement
local AccessoryEvent = Events.AccessoryEvent

-- Wait for CurrentWeapon and the movement object
local CurrentWeapon = char:GetAttribute("CurrentWeapon")
while CurrentWeapon == nil do
	CurrentWeapon = char:GetAttribute("CurrentWeapon")
	if CurrentWeapon then
		break
	end
	task.wait(0.3)
end

local object = Movement.new(plr)

--[Animation Setup]--
local WeaponAnimations = RS.Animations.Weapons
local MovementAnimationsFolder = WeaponAnimations[CurrentWeapon].Movement

local WallClimbAnim = Hum.Animator:LoadAnimation(MovementAnimationsFolder.WallClimb)

--[State]--
local canClimb = false
local lastClimbState = nil
local heldKeys = {}



local LastKeyPressTime = 0
local doubleTapThreshold = 0.3
local velocityDecay = 0.3


-- Offscreen positions (top slides up, bottom slides down)
local TOP_HIDDEN = UDim2.new(-0.001, 0, -0.4, 0)
local BOTTOM_HIDDEN = UDim2.new(-0.034, 0, 1.1, 0)

local Tilt_TOP_HIDDEN_LEFT = UDim2.new(-1.325, 0, -2, 0)
local Tilt_BOTTOM_HIDDEN_LEFT = UDim2.new(-1.325, 0, 2, 0)


-- Normal (resting) positions
local TOP_NORMAL = UDim2.new(-0.001, 0, -0.187, 0)
local BOTTOM_NORMAL = UDim2.new(-0.034, 0, 0.75, 0)

-- Breathe positions
local TOP_INHALE = UDim2.new(-0.001, 0, -0.15, 0)
local BOTTOM_INHALE = UDim2.new(-0.034, 0, 0.72, 0)

local tweenSlide = TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local tweenBreathe = TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

-- Set bars offscreen initially
top.Position = TOP_HIDDEN
bottom.Position = BOTTOM_HIDDEN

Top_tilt.Position = Tilt_TOP_HIDDEN_LEFT
Bottom_tilt.Position = Tilt_BOTTOM_HIDDEN_LEFT

Top_tilt.Rotation = 0
Bottom_tilt.Rotation = 0

-------------------------------------------------
-- WALK  Cycles
-------------------------------------------------

char:GetAttributeChangedSignal("CurrentWeapon"):Connect(function()
	object:UpdateWalkTracks()
end)
char:GetAttributeChangedSignal("Equipped"):Connect(function()
	object:UpdateWalkTracks()
end)
char:GetAttributeChangedSignal("IsLow"):Connect(function()
	object:UpdateWalkTracks()
end)
char:GetAttributeChangedSignal("InCombat"):Connect(function()
	object:UpdateWalkTracks()
end)
AccessoryEvent.OnClientEvent:Connect(function(action)
	if action == "RefreshAnimations" then
		object:UpdateWalkTracks()
	end
end)

object:UpdateWalkTracks()






-------------------------------------------------
-- WALL CLIMB
-------------------------------------------------
local function slideOutBars()
	TS:Create(top, tweenSlide, { Position = TOP_HIDDEN }):Play()
	TS:Create(bottom, tweenSlide, { Position = BOTTOM_HIDDEN }):Play()
end

local function breatheFOV()
	if not object.States.IsOnWall then
		TS:Create(cam, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { FieldOfView = 70 }):Play()
		slideOutBars()
		return
	end

	-- FOV tweens
	local inhale = TS:Create(cam, tweenBreathe, { FieldOfView = 63 })
	local exhale = TS:Create(cam, tweenBreathe, { FieldOfView = 65 })

	-- Bar tweens (inhale = bars close in, exhale = bars open back)
	local barsInhale_Top = TS:Create(top, tweenBreathe, { Position = TOP_INHALE })
	local barsInhale_Bottom = TS:Create(bottom, tweenBreathe, { Position = BOTTOM_INHALE })
	local barsExhale_Top = TS:Create(top, tweenBreathe, { Position = TOP_NORMAL })
	local barsExhale_Bottom = TS:Create(bottom, tweenBreathe, { Position = BOTTOM_NORMAL })

	inhale:Play()
	barsInhale_Top:Play()
	barsInhale_Bottom:Play()

	inhale.Completed:Connect(function()
		if not object.States.IsOnWall then
			TS:Create(cam, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { FieldOfView = 70 })
				:Play()
			slideOutBars()
			return
		end

		exhale:Play()
		barsExhale_Top:Play()
		barsExhale_Bottom:Play()

		exhale.Completed:Connect(function()
			breatheFOV()
		end)
	end)
end

local function startBreath()
	-- Slide bars in first, then start breathing once they arrive
	TS:Create(top, tweenSlide, { Position = TOP_NORMAL }):Play()
	local slideIn = TS:Create(bottom, tweenSlide, { Position = BOTTOM_NORMAL })
	slideIn:Play()
	slideIn.Completed:Connect(function()
		if object.States.IsOnWall then
			breatheFOV()
		end
	end)
end

local climbBV = nil
local climbBusy = false
local climbSetTimer = nil
local HEAD_PROBE_HEIGHT = 3.5

local function GrabLedge(ledgeY: number, intoWallDir: Vector3)
	object.States.IsOnWall = true
	object.IsActing.Climbing = false
	climbBusy = false
	if climbSetTimer then
		task.cancel(climbSetTimer)
		climbSetTimer = nil
	end
	if object.InfoTable.Climb then
		object.InfoTable.Climb.Used = 0
	end

	if climbBV then
		climbBV:Destroy()
		climbBV = nil
	end

	if WallClimbAnim.IsPlaying then
		WallClimbAnim:Stop()
	end

	local ledgePos = Vector3.new(HRP.Position.X, ledgeY, HRP.Position.Z)
	MovementEvent:FireServer("LedgeHold", ledgePos, intoWallDir)

	task.delay(0.1, function()
		if object.States.IsOnWall then
			startBreath()
		end
	end)
end

local function startClimbPush(wallHit)
	pcall(function() object:CancelConflictingActions("Climb") end)
	if object.IsActing.WallRunning then
		return
	end
	if climbBusy then
		return
	end
	if not wallHit or wallHit.Instance:GetAttribute("NonClimable") then
		return
	end

	-- Set budget mirrors the DoubleJump pool: free up to the pool, hard-capped
	-- in combat, stamina-bought beyond the pool out of combat.
	local climbInfo = object.InfoTable.Climb
	local inCombat = char:GetAttribute("InCombat")
	if inCombat and climbInfo.Used >= climbInfo.FreeClimbs then
		return
	end
	if (inCombat or climbInfo.Used >= climbInfo.FreeClimbs)
		and ClientHelpfull.CheckStamina(char, "Climb") then
		return
	end

	climbInfo.Used += 1
	climbInfo.LastTime = os.clock()
	object:ServerRequest("Climb")

	local flatNormal = Vector3.new(wallHit.Normal.X, 0, wallHit.Normal.Z)
	if flatNormal.Magnitude > 0.1 then
		flatNormal = flatNormal.Unit
	else
		flatNormal = Vector3.new(HRP.CFrame.LookVector.X, 0, HRP.CFrame.LookVector.Z).Unit
	end
	local intoWallDir = -flatNormal

	object.States.IsGrounded = true
	object.IsActing.Climbing = true
	climbBusy = true

	WallClimbAnim:Play()

	-- Live per-push height so AGL/multiplier changes never go stale.
	local climbHeight = SpeedMods.GetMovementSpeed(char, "ClimbMaxHeight", "Climb")

	local bv = Instance.new("BodyVelocity")
	bv.Velocity = HRP.CFrame.LookVector + Vector3.new(0, climbHeight, 0)
	bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bv.Parent = HRP
	climbBV = bv
	Debris:AddItem(bv, velocityDecay)

	-- Expose a typed Stop so Movement:CancelConflictingActions("Dodge"/"WallRun"...) can
	-- cleanly tear down an in-flight climb and clear the local climbBusy flag.
	object.InfoTable.Climb.Stop = function()
		if climbBV then pcall(function() climbBV:Destroy() end) climbBV = nil end
		if climbSetTimer then pcall(function() task.cancel(climbSetTimer) end) climbSetTimer = nil end
		climbBusy = false
		object.IsActing.Climbing = false
		pcall(function() WallClimbAnim:Stop(0.1) end)
	end

	task.delay(0.2, function()
		SoundsModule.PlaySound(SFX.SFX.Movement.ClimbSound)
	end)

	-- Push window: the next push can queue once this expires.
	task.delay(velocityDecay, function()
		climbBusy = false
	end)

	-- Probe forward at head height. The moment it clears the top edge, grab.
	task.spawn(function()
		while object.IsActing.Climbing and char.Parent and climbBusy do
			local headY = HRP.Position.Y + HEAD_PROBE_HEIGHT

			local r = Cast.Ray({
				Origin = Vector3.new(HRP.Position.X, headY, HRP.Position.Z),
				Direction = intoWallDir,
				Range = 5,
				FilterList = { char, VFXFolder, NPCFolder, CharactersFolder },
			})

			if not r or r.Instance:GetAttribute("NonClimable") == true then
				GrabLedge(headY, intoWallDir)
				break
			end

			task.wait()
		end
	end)

	-- Set-death: no re-push within the window (push + input grace) ends the set.
	if climbSetTimer then
		task.cancel(climbSetTimer)
	end
	climbSetTimer = task.delay(velocityDecay + 0.3, function()
		object.IsActing.Climbing = false
		climbBusy = false
		if climbBV then
			climbBV:Destroy()
			climbBV = nil
		end
	end)
end

-------------------------------------------------
-- SPRINT SYSTEM
-------------------------------------------------


local baseSpeed = SpeedMods.GetMovementSpeed(char, "WalkSpeed", "Walk")






MovementEvent.OnClientEvent:Connect(function(action, forced)
    if action == "ForceAction" and forced == "StopSprint" then
        Sprint.ForceStopAllSprinting(object)
        return
    end

    if action == "AstralDodge" then
        local WasSprinting = object.IsActing.IsSprinting
        local WasExSprinting = object.IsActing.IsEXSprinting

        if WasSprinting or WasExSprinting then
            Sprint.NormalToggle(object)
        end

        local dodgeSpeed = baseSpeed * 5
        Hum.WalkSpeed = dodgeSpeed
        TS:Create(cam, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { FieldOfView = 160 }):Play()

        task.delay(5, function()
            if not object.IsActing.IsSprinting and not object.IsActing.IsEXSprinting then
                Hum.WalkSpeed = baseSpeed
                TS:Create(cam, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { FieldOfView = 70 }):Play()

                if WasSprinting then
                    Sprint.NormalToggle(object)
                    if WasExSprinting then
                        Sprint.ExToggle(object)
                    end
                end
            end
        end)
    end
end)


char:GetAttributeChangedSignal("Attacking"):Connect(function()
    Sprint.OnCharStateChanged(object)
end)

char:GetAttributeChangedSignal("Stunned"):Connect(function()
    Sprint.OnCharStateChanged(object)
end)

char:GetAttributeChangedSignal("IsBlocking"):Connect(function()
    Sprint.OnCharStateChanged(object)
end)

-------------------------------------------------
-- RENDER STEPPED — Walk weights
-------------------------------------------------
RunService.RenderStepped:Connect(function()
	object:WalkCycle()
end)


local function FindFowardwall(char)
	local HRP = char.HumanoidRootPart
	if not HRP then
		return nil
	end

	local hitClimable = false
	local hitResult = nil

	local offsets = {
		Vector3.new(0, 0, 0), -- Center
		Vector3.new(0, 1.5, 0), -- Upper
		Vector3.new(0, -1.5, 0), -- Lower
	}

	for _, offset in ipairs(offsets) do
		local origin = HRP.Position + offset

		local result = Cast.Ray({
			Origin = origin,
			Direction = HRP.CFrame.LookVector,
			Range = MovementData.Data.ClimbDetectionRange,
			FilterList = { char, VFXFolder, NPCFolder, CharactersFolder },
		})

		if result and result.Instance:GetAttribute("NonClimable") ~= true then
			hitClimable = true
			hitResult = result
			break
		end
	end

	canClimb = hitClimable
	if hitClimable ~= lastClimbState then
		lastClimbState = hitClimable
	end

	return hitResult
end


RunService.Heartbeat:Connect(function()
	Wallrun.Start(object)
end)

-------------------------------------------------
-- INPUT
-------------------------------------------------
UIS.InputBegan:Connect(function(input, isTyping)
    if isTyping then
        return
    end
    local key = input.KeyCode

    if key == Enum.KeyCode.W then
        heldKeys.W = true

        if Sprint.CanSprint(object) then
            local currentTime = tick()
            if currentTime - LastKeyPressTime <= doubleTapThreshold then
                Sprint.NormalToggle(object)
            end
            LastKeyPressTime = currentTime
        end
    elseif key == Enum.KeyCode.LeftShift then
        Sprint.ExToggle(object)
    elseif key == Enum.KeyCode.S then
        if object.States.IsOnWall then
            object.States.IsOnWall = false
            MovementEvent:FireServer("ReleaseLedge", false)
            TS:Create(cam, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { FieldOfView = 70 }):Play()
            return
        end
    end

    if key == Enum.KeyCode.Space then
        if object.States.IsOnWall then
            object.States.IsOnWall = false
            MovementEvent:FireServer("ReleaseLedge", true)
            TS:Create(cam, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = 95 }):Play()

            if top.Position ~= TOP_HIDDEN then
                slideOutBars()
            end
            task.delay(0.15, function()
                TS:Create(cam, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { FieldOfView = 70 }):Play()
            end)
            return
        end

        local wallHit = FindFowardwall(char)

        if object.States.IsInAir and heldKeys.W and canClimb and not object.IsActing.WallRunning then
            if not object.IsActing.Climbing then
                if object.IsActing.IsSprinting or object.IsActing.IsEXSprinting then
                    Sprint.NormalToggle(object)
                    task.wait(0.15)
                end
            end
            startClimbPush(wallHit)
        end

        if object.IsActing.WallRunning then
            Wallrun.Jump(object)
        elseif object.States.IsInAir and not object.IsActing.Climbing then
            -- Free pool (declarable via InfoTable.DoubleJump.FreeJumps) is free
            -- out of combat; jumps past it cost stamina. In combat the pool is
            -- a hard cap AND every jump costs stamina. Server enforces both --
            -- this is the client pre-check so we don't waste the jump visual.
            local djInfo = object.InfoTable and object.InfoTable.DoubleJump
            local freeJumps = (djInfo and djInfo.FreeJumps) or MovementData.Data.DoubleJumps
            local inCombat = char:GetAttribute("InCombat")
            if inCombat and djInfo and djInfo.Used >= freeJumps then
                return
            end
            if (inCombat or (djInfo and djInfo.Used >= freeJumps))
                and ClientHelpfull.CheckStamina(char, "DoubleJump") then
                return
            end
            DoubleJump.Start(object)
        end
    end

    if key == Enum.KeyCode.LeftControl then
        Crouch.Start(object)
    end
end)

UIS.InputEnded:Connect(function(input, isTyping)
    if isTyping then
        return
    end
    local key = input.KeyCode

    if key == Enum.KeyCode.W then
        heldKeys.W = nil
        if object.IsActing.IsSprinting or object.IsActing.IsEXSprinting then
            Sprint.NormalToggle(object)
        end
        if object.States.ISSliding then
            object.InfoTable.Slide.Stop()
        end
    elseif key == Enum.KeyCode.LeftAlt then
        if object.IsActing.IsEXSprinting then
            Sprint.ExToggle(object)
        end
        if object.States.ISSliding and not object.IsActing.IsEXSprinting then
            object.InfoTable.Slide.Stop()
        end
    end
end)

-------------------------------------------------
-- HUMANOID STATE
-------------------------------------------------
Hum.StateChanged:Connect(function(_, newState) -- other state stuff
	if newState == Enum.HumanoidStateType.Freefall or newState == Enum.HumanoidStateType.Jumping then
		object.States.IsInAir = true 
		object.States.IsGrounded = false
	elseif newState == Enum.HumanoidStateType.Landed then
		object.States.IsInAir = false
		object.States.IsGrounded = true
		-- Dive dies on landing: tear down the stance mover before reset.
		-- (DoubleJump already kills it mid-air via CancelConflictingActions.)
		if object.InfoTable.Dodge and object.InfoTable.Dodge.Type == "Dive" then
			pcall(function() (object.InfoTable.Dodge.Stop :: () -> ())() end)
		end
		DoubleJump.Reset(object)
		if object.InfoTable.Climb then
			object.InfoTable.Climb.Used = 0
		end
		if climbSetTimer then
			task.cancel(climbSetTimer)
			climbSetTimer = nil
		end
		object.IsActing.Climbing = false
		climbBusy = false
	end
end)

function CrouchStatesChecker(_, Newstates)
	if object.States.IsCrouching then
		if
			Newstates == Enum.HumanoidStateType.Dead
			or Newstates == Enum.HumanoidStateType.Climbing
			or Newstates == Enum.HumanoidStateType.Swimming
			or Newstates == Enum.HumanoidStateType.Seated
			or Newstates == Enum.HumanoidStateType.Physics
		then
			object.InfoTable.Crouch.Stop()
		end
	end
	if object.States.ISSliding then
		if Newstates ~= Enum.HumanoidStateType.Running then
			object.InfoTable.Slide.Stop()
		end
	end
end

Hum.StateChanged:Connect(CrouchStatesChecker)
