local Dodge = {}
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local RSModules = RS.Modules
local ClientTypes = require(RSModules.ClientTypes)
local FlowManager = require(RSModules.Movement.Ultils.Flow)
local MovementData = require(RSModules.Movement.Data)
local Sprinting = require(RSModules.Movement.Mechnanics.Sprinting)
local SpeedMods = require(RSModules.Movement.Ultils.Speed)

local WeaponAnims = RS.Animations.Weapons

local VFXFolder = workspace:WaitForChild("VFX")
local NPCFolder = workspace:WaitForChild("NPC")
local CharactersFolder = workspace:WaitForChild("Characters")

-- Camera read fresh at use-time: the CurrentCamera reference can swap (respawn,
-- cutscene, etc.), so capturing it at require-time is a footgun.
local function GetCamera()
	return workspace.CurrentCamera or workspace:FindFirstChildWhichIsA("Camera")
end

-- Wall-contact probe (anti-fling): MaxForce-inf movers driven into a wall
-- fling on penetration resolve. Probe ahead along the commanded dir each
-- tick; head-on contact (vel into the face past the dot gate) bonk-stops
-- the mover. Grazes/parallels pass so wallrun/wallbounce can still catch.
-- Returns true when the mover should die (LV destroyed by caller).
local WALL_STOP_DOT = -0.3
local WALL_PROBE_MARGIN = 2.5
local function HitWallHeadOn(char, origin: Vector3, dir: Vector3, speed: number, dt: number): boolean
	if dir.Magnitude < 0.05 or speed <= 0 then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char, VFXFolder, NPCFolder, CharactersFolder }
	local range = speed * math.max(dt, 0.001) * 2 + WALL_PROBE_MARGIN
	local result = workspace:Raycast(origin, dir.Unit * range, params)
	if not result then
		return false
	end
	return dir.Unit:Dot(result.Normal) < WALL_STOP_DOT
end

local function easeOutQuad(t: number): number
	return 1 - (1 - t) * (1 - t)
end

local function easeOutCubic(t: number): number
	local omt = 1 - t
	return 1 - omt * omt * omt
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local DodgeCoolDowns = {}
local CancelCoolDown = {}
local DiveCoolDowns = {}

local function SetIntent(char, intent)
	if not RunService:IsServer() then return end
	local SSModules = game:GetService("ServerStorage").Modules
	local IntentService = require(SSModules.Combat.IntentService)
	IntentService.SetIntent(char, nil, intent)
end



local function CalculateDodgeSpeed(MovementObj: ClientTypes.MovementObj, isAir: boolean): number?
    local char = MovementObj.char
    if not char then return nil end 
    local Element = char:GetAttribute("Element")
    -- AGL-scaled (softly) via SpeedMods, honoring the DodgeSpeedMultiplier attribute.
    local baseSpeed = SpeedMods.GetDodgeSpeed(char)
    local maxspeed = SpeedMods.GetMaxDodgeSpeed(char)
    if Element == "Astral" and char:GetAttribute("Mode2") then
        baseSpeed  = baseSpeed * 2
        maxspeed = maxspeed *2
    end
   
    if isAir then
        baseSpeed = baseSpeed * MovementData.Data.AirDodgeMultiplier -- you go little slower in the air 
    end

    return math.min(baseSpeed, maxspeed)
end

local function Get3DMovement(MovementObj: ClientTypes.MovementObj)
    local isServer = RunService:IsServer()
    if isServer then
        return Vector3.zero
    end

    local char = MovementObj.char
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then
        return Vector3.zero
    end

    local MoveInput = hum.MoveDirection
    local HeldKey = char:GetAttribute("CurrentMoveKey") or "None"

    -- Priority-resolved WASD intent beats the live MoveDirection blend: with
    -- W+A held the resolved key is "A" (see Keybinds.updateMovementAttribute),
    -- so the dodge goes clean left instead of a forward-left diagonal.
    if HeldKey ~= "None" then
        local cam = GetCamera()
        if cam then
            local camCF = cam.CFrame
            local forward = camCF.LookVector
            local right = camCF.RightVector

            -- Flatten vectors to prevent camera tilt from altering launch angles
            forward = Vector3.new(forward.X, 0, forward.Z).Unit
            right = Vector3.new(right.X, 0, right.Z).Unit

            if HeldKey == "W" then return forward end
            if HeldKey == "S" then return -forward end
            if HeldKey == "A" then return -right end
            if HeldKey == "D" then return right end
        end
    end

    if MoveInput.Magnitude > 0 then
        return MoveInput.Unit
    end

    local cam = GetCamera()
    if cam then
        local flatCam = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z).Unit
        return flatCam
    end

    return Vector3.zero
end

function Dodge.Dodge(MovementObj: ClientTypes.MovementObj)
    if not MovementObj or not MovementObj.char or MovementObj.IsActing.Dodging then
        return
    end

    -- Tear down any previous mover before creating the new one (fixes ghost when spamming)
    pcall(function() MovementObj:CancelConflictingActions("Dodge") end)

    local char = MovementObj.char
    local HRP = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    local isServer = RunService:IsServer()

    if DodgeCoolDowns[MovementObj] and os.clock() - DodgeCoolDowns[MovementObj] < MovementData.Data.DodgeCooldown then
        return
    end
    if not HRP or not hum then
        return
    end

    if not isServer then
        local ClientHelpful = require(RSModules.ClientHelpfull)
        if ClientHelpful.CheckForAttributes(char, true, true, true, true, false, true, true, false) then
            return
        end
        if ClientHelpful.CheckStamina(char, "Dodge") then
            return
        end
    end

    local dashdir = Get3DMovement(MovementObj)
    local isAir = MovementObj.States.IsInAir


    ---  Introduce Moementum from previous actions in direction of dodge 

    local retained = Vector3.zero
    local dashMag = dashdir.Magnitude

    if dashMag > 0 then
        local incomingFlat = Vector3.new(HRP.AssemblyLinearVelocity.X,0,HRP.AssemblyLinearVelocity.Z)
        local dashflat = dashdir/dashMag
        retained = dashflat * (math.max(0,incomingFlat:Dot(dashflat)) * MovementData.Data.DodgeMomentumRetention)
    end

    if dashdir == Vector3.zero and isAir then
        return
    end

    local HeldKey = char:GetAttribute("CurrentMoveKey")
    local CurrentWeapon = char:GetAttribute("CurrentWeapon") or "BareFists"
    local DodgeAnim = nil :: Animation?

    FlowManager.OnDodgeStart(MovementObj)
    MovementObj.IsActing.Dodging = true
    SetIntent(char, "Dodge")

    if isAir then
        if HeldKey == nil or HeldKey == "None" then HeldKey = "W" end
        local animator = hum:FindFirstChildOfClass("Animator")
        if animator then
            local animObj = WeaponAnims[CurrentWeapon] and WeaponAnims[CurrentWeapon].Dodging and WeaponAnims[CurrentWeapon].Dodging.InAir and WeaponAnims[CurrentWeapon].Dodging.InAir[HeldKey]
                or WeaponAnims[CurrentWeapon] and WeaponAnims[CurrentWeapon].Dodging and WeaponAnims[CurrentWeapon].Dodging.InAir and WeaponAnims[CurrentWeapon].Dodging.InAir.W
                or WeaponAnims[CurrentWeapon] and WeaponAnims[CurrentWeapon].Dodging and WeaponAnims[CurrentWeapon].Dodging[HeldKey]
                or WeaponAnims[CurrentWeapon] and WeaponAnims[CurrentWeapon].Dodging and WeaponAnims[CurrentWeapon].Dodging.W
            if animObj then
                DodgeAnim = animator:LoadAnimation(animObj)
            end
        end
        MovementObj.InfoTable.Dodge.Type = "AirDodge"
    else
        if dashdir == Vector3.zero or HeldKey == "None" then
            HeldKey = "None"
            MovementObj.InfoTable.Dodge.Type = "SpotDodge"
        else
            if HeldKey == nil then HeldKey = "W" end
            MovementObj.InfoTable.Dodge.Type = "Normal"
        end
        if MovementObj.InfoTable.Dodge.Type ~= "SpotDodge" then
            local animObj2 = WeaponAnims[CurrentWeapon] and WeaponAnims[CurrentWeapon].Dodging and WeaponAnims[CurrentWeapon].Dodging[HeldKey]
                or WeaponAnims[CurrentWeapon] and WeaponAnims[CurrentWeapon].Dodging and WeaponAnims[CurrentWeapon].Dodging.W
            if animObj2 then
                DodgeAnim = hum:FindFirstChildOfClass("Animator"):LoadAnimation(animObj2)
            end
        end
    end

    if DodgeAnim then
        DodgeAnim:Play()
    end
    MovementObj.InfoTable.Dodge.Dir = dashdir

    if not isServer then
        MovementObj:ServerRequest("Dodge", retained.Magnitude) 
    end

    local shouldAlign = (HeldKey == "W" and MovementObj.InfoTable.Dodge.Type ~= "SpotDodge")
    local lv, algin
    if MovementObj.InfoTable.Dodge.Type ~= "SpotDodge" then
        local DodgeSpeed = CalculateDodgeSpeed(MovementObj, isAir)
        if not DodgeSpeed then return end

        -- DOUBLE JUMP -> AIR DODGE BONUS: fresh double jump makes the next air dodge faster
        if isAir and MovementObj.InfoTable.DoubleJump then
            local lastDoubleJump = MovementObj.InfoTable.DoubleJump.LastTime or 0
            if lastDoubleJump > 0 and os.clock() - lastDoubleJump < MovementData.Data.AirDodgeBonusWindow then
                DodgeSpeed = DodgeSpeed * MovementData.Data.AirDodgeBonusMultiplier
                MovementObj.InfoTable.DoubleJump.LastTime = 0 -- consume the bonus
            end
        end

        local att = HRP:FindFirstChild("DodgeAtt")
        if not att then
            att = Instance.new("Attachment")
            att.Parent = HRP
        end
        att.Name = "DodgeAtt"

        lv = Instance.new("LinearVelocity")
        lv.Name = "DashForce"
        lv.Attachment0 = att
        lv.MaxForce = math.huge

        -- Floaty curve setup (heartbeat-driven, not rectangle) - respects current movement speed so sprint dodge doesn't tweak
        local walkSpeed = SpeedMods.GetMovementSpeed(char, "WalkSpeed", "Walk")
        local curFlow = MovementObj.Flow and MovementObj.Flow.CurrentSpeed or walkSpeed
        local speedFactor = math.clamp(curFlow / math.max(1, walkSpeed), 0.85, 1.6) -- sprinting ~2x walk, but dodge only 1.6x faster
        local minCarry = walkSpeed * MovementData.Data.DodgeMinCarry
        local accel = MovementData.Data.DodgeAccelTime
        local decay = MovementData.Data.DodgeDecayTime
        local cruiseEnd = 0.15
        local totalDur = accel + 0.07 + decay -- 0.26 with new defaults (0.04+0.07+0.15)
        local retainedMag = retained.Magnitude
        local maxDodge = SpeedMods.GetMaxDodgeSpeed(char)
        local basePeak = DodgeSpeed * MovementData.Data.DodgePeakScale * speedFactor
        -- peak includes retained so total distance matches old budget
        local peak = math.min(maxDodge, basePeak + retainedMag)
        peak = math.max(peak, minCarry)
        local startPeakFraction = 0.75 -- even snappier: at 0.00 ~63 vs 84 peak, close to old instant 75

        -- Air specific: gravity and launch dir (pitch up-only)
        local gravityCounter = Vector3.zero
        local launchDir: Vector3 = if dashdir.Magnitude > 0 then dashdir.Unit else Vector3.zero
        local flatDashDir: Vector3 = Vector3.zero
        if isAir then
            gravityCounter = Vector3.new(0, workspace.Gravity * (MovementData.Data.DodgeDuration * 0.75), 0)
            flatDashDir = if dashdir.Magnitude > 0 then Vector3.new(dashdir.X, 0, dashdir.Z).Unit else Vector3.new(0, 0, 0)
            local cam = GetCamera()
            local pitch = 0
            if cam and cam.CFrame then
                -- Full pitch (up AND down): nose-down Q is a regular directional
                -- dash now that dive lives on E. Dive trigger never lived here.
                local lookY = math.clamp(cam.CFrame.LookVector.Y, -1, 1)
                pitch = math.rad(MovementData.Data.AirDodgeCamPitchAngle) * lookY
            end
            local flat = if flatDashDir.Magnitude > 0 then flatDashDir else Vector3.new(0, 0, 1)
            launchDir = (flat + Vector3.new(0, math.tan(pitch), 0)).Unit
        else
            launchDir = if dashdir.Magnitude > 0 then dashdir.Unit else Vector3.zero
        end

        lv.Parent = HRP

        if shouldAlign then
            if not isServer and hum then hum.AutoRotate = false end
            algin = Instance.new("AlignOrientation")
            algin.Name = "DashRotation"
            algin.Mode = Enum.OrientationAlignmentMode.OneAttachment
            algin.Attachment0 = att
            algin.MaxTorque = math.huge
            algin.Responsiveness = 18
            if isAir then
                algin.CFrame = CFrame.lookAlong(Vector3.zero, launchDir)
            else
                algin.CFrame = CFrame.lookAlong(Vector3.zero, Vector3.new(dashdir.X, 0, dashdir.Z).Unit)
            end
            algin.Parent = HRP
        end

        -- Immediate initial velocity so first frame already moves (vault table: 0.00 ~30)
        do
            local initRatio = startPeakFraction
            local initGrav = gravityCounter * initRatio
            lv.VectorVelocity = launchDir * (peak * initRatio) + initGrav
        end

        -- Heartbeat curve: accel (quad) -> cruise -> decay (cubic) -> handoff
        -- Start at ~0.4*peak (vault table: 0.00 ~30) so first frame already moves, not from 0
        local startT = os.clock()
        local conn: RBXScriptConnection? = nil
        conn = RunService.Heartbeat:Connect(function(dt)
            if not lv or not lv.Parent then
                if conn then conn:Disconnect() end
                return
            end
            local t = os.clock() - startT
            if t >= totalDur then
                if conn then conn:Disconnect() end
                return
            end
            local cur: number
            if t < accel then
                cur = lerp(peak * startPeakFraction, peak, easeOutQuad(t / accel))
            elseif t < cruiseEnd then
                local u = (t - accel) / (cruiseEnd - accel)
                cur = lerp(peak * 0.95, peak, u)
            else
                local u = (t - cruiseEnd) / decay
                u = math.clamp(u, 0, 1)
                cur = lerp(peak, minCarry, easeOutCubic(u))
            end
            -- Anti-fling: head-on wall contact kills the mover, anim/align
            -- finish via the scheduled Stop() (Dodging flag untouched).
            if HitWallHeadOn(char, HRP.Position, launchDir, cur, dt) then
                if conn then conn:Disconnect() end
                MovementObj.InfoTable.Dodge._CurveConn = nil
                lv:Destroy()
                return
            end
            local ratio = peak > 0 and cur / peak or 0
            local gravScaled = gravityCounter * ratio
            -- dashDir already includes direction, cur is total speed along it (peak includes retained)
            local vel = launchDir * cur + gravScaled
            -- Clamp to MaxForce semantics already via peak cap
            lv.VectorVelocity = vel
        end)
        -- Store for Stop() to disconnect
        ;MovementObj.InfoTable.Dodge._CurveConn = conn

        -- Stamina can regen after budget window (0.25) even though tail continues to 0.35
        task.delay(MovementData.Data.DodgeDuration, function()
            if MovementObj.IsActing.Dodging then
                MovementObj.IsActing.Dodging = false
                SetIntent(char, "None")
                -- Keep _CurveConn and lv alive for tail decay to 0.35
            end
        end)
    end

    if not isServer then
        local infoTable = { Action = "Dodge" }
        MovementObj:BarTween(infoTable)
    end

    local function Stop()
        -- Don't early-return on Dodging flag alone — tail may have already cleared it at 0.25 but lv still needs cleanup at 0.35
        if not MovementObj.IsActing.Dodging and not lv and not algin then return end

        local conn = MovementObj.InfoTable.Dodge._CurveConn :: RBXScriptConnection?
        if conn then
            pcall(function() conn:Disconnect() end)
            ;MovementObj.InfoTable.Dodge._CurveConn = nil
        end

        if DodgeAnim then DodgeAnim:Stop(); DodgeAnim:Destroy() end
        if algin and not isServer and hum and hum.Parent then pcall(function() hum.AutoRotate = true end) end
        if lv then lv:Destroy() end
        if algin then algin:Destroy() end

        MovementObj.IsActing.Dodging = false
        MovementObj.InfoTable.Dodge.Type = "None"
        SetIntent(char, "None")

        FlowManager.OnDodgeEnd(MovementObj, function()
            if isServer then return end 
            if MovementObj.IsActing.IsEXSprinting then
                MovementObj.IsActing.IsSprinting = false
                Sprinting.NormalToggle(MovementObj)
                MovementObj.IsActing.IsEXSprinting = false
                Sprinting.ExToggle(MovementObj)
            else
                MovementObj.IsActing.IsSprinting = false
                Sprinting.NormalToggle(MovementObj)
            end
        end)

        if not isServer then
            local infoTable = { Action = "Dodge" }
            MovementObj:BarTweenStop(infoTable)
        end
        DodgeCoolDowns[MovementObj] = os.clock()
    end

    MovementObj.InfoTable.Dodge.Stop = Stop

    local stopDur = MovementObj.InfoTable.Dodge.Type == "SpotDodge" and MovementData.Data.DodgeDuration or (MovementData.Data.DodgeAccelTime + 0.07 + MovementData.Data.DodgeDecayTime)
    task.delay(stopDur, function()
        Stop()
    end)
end

Dodge.CalculateDodgeSpeed = CalculateDodgeSpeed

-- DIVE (E + IsInAir): accelerating forward-then-tips-down stance.
-- No time limit: the mover lives until Landed / DoubleJump (which routes
-- through CancelConflictingActions -> InfoTable.Dodge.Stop) or a dead-man
-- failsafe (death / teardown). Never consumes the DoubleJump air-bonus.
function Dodge.Dive(MovementObj: ClientTypes.MovementObj)
    if not MovementObj or not MovementObj.char or MovementObj.IsActing.Dodging then
        return
    end

    pcall(function() MovementObj:CancelConflictingActions("Dive") end)

    local char = MovementObj.char
    local HRP = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    local isServer = RunService:IsServer()

    if DiveCoolDowns[MovementObj] and os.clock() - DiveCoolDowns[MovementObj] < MovementData.Data.DiveCooldown then
        return
    end
    if not HRP or not hum then
        return
    end
    -- Double-guard: the E resolver already gates on IsInAir, this covers
    -- server/client state races (grounded E must equip, never dive).
    if not MovementObj.States.IsInAir then
        return
    end

    if not isServer then
        local ClientHelpful = require(RSModules.ClientHelpfull)
        if ClientHelpful.CheckForAttributes(char, true, true, true, true, false, true, true, false) then
            return
        end
        -- Same 20 stamina price as a dodge, shared pool.
        if ClientHelpful.CheckStamina(char, "Dodge") then
            return
        end
    end

    -- Commit the forward line once: camera flat at entry, HRP flat fallback.
    local flatDir = Vector3.new(0, 0, 1)
    do
        local cam = GetCamera()
        if cam and cam.CFrame then
            local f = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
            if f.Magnitude > 0.05 then
                flatDir = f.Unit
            end
        end
        if flatDir == Vector3.new(0, 0, 1) then
            local hf = Vector3.new(HRP.CFrame.LookVector.X, 0, HRP.CFrame.LookVector.Z)
            if hf.Magnitude > 0.05 then
                flatDir = hf.Unit
            end
        end
    end
    local downDir = Vector3.new(0, -1, 0)

    -- Entry speed: same AGL-aware base as air dodge, boosted, plus retained
    -- incoming flat momentum along the dive line. Capped to DiveMaxSpeed so
    -- the validator has a provable ceiling.
    local walkSpeed = SpeedMods.GetMovementSpeed(char, "WalkSpeed", "Walk")
    local curFlow = MovementObj.Flow and MovementObj.Flow.CurrentSpeed or walkSpeed
    local speedFactor = math.clamp(curFlow / math.max(1, walkSpeed), 0.85, 1.6)
    local baseSpeed = CalculateDodgeSpeed(MovementObj, true)
    if not baseSpeed then return end
    local incomingFlat = Vector3.new(HRP.AssemblyLinearVelocity.X, 0, HRP.AssemblyLinearVelocity.Z)
    local retainedMag = math.max(0, incomingFlat:Dot(flatDir)) * MovementData.Data.DodgeMomentumRetention
    local cur = math.min(
        MovementData.Data.DiveMaxSpeed,
        baseSpeed * MovementData.Data.DiveSpeedBoost * speedFactor + retainedMag
    )
    cur = math.max(cur, walkSpeed * MovementData.Data.DodgeMinCarry)

    FlowManager.OnDive(MovementObj)
    MovementObj.IsActing.Dodging = true
    SetIntent(char, "Dodge")
    MovementObj.InfoTable.Dodge.Type = "Dive"
    MovementObj.InfoTable.Dodge.Dir = flatDir

    if not isServer then
        MovementObj:ServerRequest("Dive", retainedMag)
    end

    local att = HRP:FindFirstChild("DodgeAtt")
    if not att then
        att = Instance.new("Attachment")
        att.Parent = HRP
    end
    att.Name = "DodgeAtt"

    local lv = Instance.new("LinearVelocity")
    lv.Name = "DashForce"
    lv.Attachment0 = att
    lv.MaxForce = math.huge
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.Parent = HRP

    -- Dive always faces its fall line (not W-only like Q dash).
    -- Pose compensation: the dive anim is authored face-up, so the root
    -- carries an extra local-X pitch putting the body headfirst along dir.
    local posePitch = math.rad(MovementData.Data.DivePosePitch)
    if not isServer and hum then hum.AutoRotate = false end
    local align = Instance.new("AlignOrientation")
    align.Name = "DashRotation"
    align.Mode = Enum.OrientationAlignmentMode.OneAttachment
    align.Attachment0 = att
    align.MaxTorque = math.huge
    align.Responsiveness = 18
    align.CFrame = CFrame.lookAlong(Vector3.zero, flatDir) * CFrame.Angles(posePitch, 0, 0)
    align.Parent = HRP

    -- Per-weapon Dive anim: RS.Animations.Weapons.<Weapon>.Movement.Dive.
    local CurrentWeapon = char:GetAttribute("CurrentWeapon") or "BareFists"
    local animObj = WeaponAnims[CurrentWeapon].Movement.Dive
    local DiveAnim = nil
    if animObj then
        local animator = hum:FindFirstChildOfClass("Animator")
        if animator then
            local okLoad, track = pcall(function() return animator:LoadAnimation(animObj) end)
            if okLoad and track then DiveAnim = track end
        end
    end
    if DiveAnim then
        pcall(function() DiveAnim:Play(0.1) end)
    end

    local entryBias = MovementData.Data.DiveEntryBias
    local endBias = MovementData.Data.DiveEndBias
    local arcTime = math.max(0.05, MovementData.Data.DiveArcTime)
    local accel = MovementData.Data.DiveAccel
    local maxSpeed = MovementData.Data.DiveMaxSpeed
    local t = 0

    local conn: RBXScriptConnection? = nil
    local diedConn: RBXScriptConnection? = nil
    local stopped = false

    local function Stop()
        if stopped then return end
        stopped = true
        if conn then
            pcall(function() (conn :: RBXScriptConnection):Disconnect() end)
            conn = nil
        end
        if diedConn then
            pcall(function() (diedConn :: RBXScriptConnection):Disconnect() end)
            diedConn = nil
        end
        MovementObj.InfoTable.Dodge._CurveConn = nil
        if DiveAnim then
            pcall(function() (DiveAnim :: AnimationTrack):Stop() end)
            pcall(function() (DiveAnim :: AnimationTrack):Destroy() end)
            DiveAnim = nil
        end
        if align and not isServer and hum and hum.Parent then
            pcall(function() hum.AutoRotate = true end)
        end
        if lv then
            pcall(function() lv:Destroy() end)
        end
        if align then
            pcall(function() align:Destroy() end)
        end

        MovementObj.IsActing.Dodging = false
        MovementObj.InfoTable.Dodge.Type = "None"
        SetIntent(char, "None")

        FlowManager.OnDodgeEnd(MovementObj, function()
            if isServer then return end
            if MovementObj.IsActing.IsEXSprinting then
                MovementObj.IsActing.IsSprinting = false
                Sprinting.NormalToggle(MovementObj)
                MovementObj.IsActing.IsEXSprinting = false
                Sprinting.ExToggle(MovementObj)
            else
                MovementObj.IsActing.IsSprinting = false
                Sprinting.NormalToggle(MovementObj)
            end
        end)

        if not isServer then
            local infoTable = { Action = "Dodge" }
            MovementObj:BarTweenStop(infoTable)
        end
        DiveCoolDowns[MovementObj] = os.clock()
    end

    MovementObj.InfoTable.Dodge.Stop = Stop

    -- Dead-man failsafe: orphaned dive LV on a dead char is a fling bug.
    diedConn = hum.Died:Connect(function()
        Stop()
    end)

    conn = RunService.Heartbeat:Connect(function(dt)
        if stopped then return end
        if not lv or not (lv :: LinearVelocity).Parent or not char.Parent then
            Stop()
            return
        end
        t += dt
        local u = math.clamp(t / arcTime, 0, 1)
        -- easeInQuad: slow tip at first (leap read), commits late.
        local k = lerp(entryBias, endBias, u * u)
        local dir = (flatDir * (1 - k) + downDir * k).Unit
        cur = math.min(maxSpeed, cur + accel * dt)
        -- Anti-fling: head-on wall contact kills the mover only. Stance
        -- (Type Dive), align, and anim survive until Landed per design.
        if HitWallHeadOn(char, HRP.Position, dir, cur, dt) then
            pcall(function() (lv :: LinearVelocity):Destroy() end)
            if conn then
                pcall(function() (conn :: RBXScriptConnection):Disconnect() end)
                conn = nil
            end
            MovementObj.InfoTable.Dodge._CurveConn = nil
            return
        end
        ;(lv :: LinearVelocity).VectorVelocity = dir * cur
        if align and (align :: AlignOrientation).Parent then
            pcall(function()
                (align :: AlignOrientation).CFrame = CFrame.lookAlong(Vector3.zero, dir) * CFrame.Angles(posePitch, 0, 0)
            end)
        end
        if DiveAnim then
            pcall(function()
                (DiveAnim :: AnimationTrack):AdjustSpeed(0.9 + 0.5 * (cur / maxSpeed))
            end)
        end
    end)
    MovementObj.InfoTable.Dodge._CurveConn = conn

    if not isServer then
        local infoTable = { Action = "Dodge" }
        MovementObj:BarTween(infoTable)
    end
end

function Dodge.DodgeCancel(MovementObj: ClientTypes.MovementObj)
    if not MovementObj or not MovementObj.IsActing.Dodging then return end
    -- Dive is a committed stance: only Landed / DoubleJump kill it, RMB aborts Q dashes only.
    if MovementObj.InfoTable.Dodge.Type == "Dive" then return end
    local isServer = RunService:IsServer()
    local cooldownTime = isServer and os.clock() or tick()

    if CancelCoolDown[MovementObj] and (cooldownTime - CancelCoolDown[MovementObj] < MovementData.Data.DodgeCancelCooldown) then return end

    local char = MovementObj.char
    local hum = char:FindFirstChildOfClass("Humanoid")
    local currentWeapon = char:GetAttribute("CurrentWeapon")
    local DodgeCancelAnim = hum.Animator:LoadAnimation(WeaponAnims[currentWeapon].Dodging.DodgeCancel)

    if typeof(MovementObj.InfoTable.Dodge.Stop) == "function" then
        MovementObj.InfoTable.Dodge.Stop()
    end

    DodgeCancelAnim:Play()
    CancelCoolDown[MovementObj] = cooldownTime
    DodgeCoolDowns[MovementObj] = 0

    if not isServer then
        MovementObj:ServerRequest("DodgeCancel")
    end
end

return Dodge