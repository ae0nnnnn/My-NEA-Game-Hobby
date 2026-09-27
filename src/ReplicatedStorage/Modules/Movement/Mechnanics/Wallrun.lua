local Wallrun = {}
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local RSModules = RS.Modules

local Cast = require(RSModules.Cast)
local ClientTypes = require(RSModules.ClientTypes)
local FlowManager = require(RSModules.Movement.Ultils.Flow)
local Sprinting = require(RSModules.Movement.Mechnanics.Sprinting)
local MovementData = require(RSModules.Movement.Data)
local SpeedMods = require(RSModules.Movement.Ultils.Speed)

local WeaponAnimations = RS.Animations.Weapons

local function easeOutCubic(t: number): number
	local omt = 1 - t
	return 1 - omt * omt * omt
end

local function wjLerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Anti-fling (mirrors Dodge HitWallHeadOn): head-on wall contact bonk-stops
-- the jump mover; the Wallhop anim has no stop handle and finishes naturally.
-- Grazes/parallels pass so a side approach can still start a wallrun.
local JUMP_WALL_STOP_DOT = -0.3
local JUMP_WALL_PROBE_MARGIN = 2.5

local VFXFolder = workspace:WaitForChild("VFX")
local NPCFolder = workspace:WaitForChild("NPC")
local CharactersFolder = workspace:WaitForChild("Characters")

local WallrunCooldowns = {}

local AnimationCache = setmetatable({}, { __mode = "k" })

-- Helper function to fetch or cache animation tracks safely
local function GetCachedTrack(MovementObj, Hum, weapon, animType)
	if not AnimationCache[MovementObj] then
		AnimationCache[MovementObj] = {}
	end

	local cacheKey = weapon .. "_" .. animType
	if not AnimationCache[MovementObj][cacheKey] then
		local animAsset = WeaponAnimations[weapon].Movement[animType]
		AnimationCache[MovementObj][cacheKey] = Hum.Animator:LoadAnimation(animAsset)
	end

	return AnimationCache[MovementObj][cacheKey]
end

local function WallChecker(char)
	local HRP: BasePart = char.HumanoidRootPart
	if not HRP then
		return
	end

	local range = MovementData.Data.WallRunCheckRange
	local leniency = MovementData.Data.WallRunFacingLeniency
	local filter = { char, VFXFolder, NPCFolder, CharactersFolder }

	local lookVector = HRP.CFrame.LookVector
	local rightVector = HRP.CFrame.RightVector

	local function CastDir(origin, direction)
		return Cast.Ray({
			Origin = origin,
			Direction = direction,
			Range = range,
			FilterList = filter,
		})
	end

	local forwardClearance = CastDir(HRP.Position, lookVector)
	local forwardPush = forwardClearance and math.min(range * 0.5, forwardClearance.Distance * 0.5) or range * 0.5
	local forwardOrigin = HRP.Position + lookVector * forwardPush

	-- Perpendicular side rays: exact facing, highest priority.
	local LeftResult = CastDir(HRP.Position, -rightVector)
	local RightResult = CastDir(HRP.Position, rightVector)

	if LeftResult and math.abs(LeftResult.Normal.Y) < 0.2 then
		return LeftResult, -1
	elseif RightResult and math.abs(RightResult.Normal.Y) < 0.2 then
		return RightResult, 1
	end

	-- Gentle facing leniency: forward-leaning diagonal per side, so the player
	-- can stick slightly before being fully perpendicular to the wall.
	local LeftLean = CastDir(forwardOrigin, (-rightVector + lookVector * leniency).Unit)
	local RightLean = CastDir(forwardOrigin, (rightVector + lookVector * leniency).Unit)

	local facingMax = MovementData.Data.WallRunFacingMax

	if LeftLean and math.abs(LeftLean.Normal.Y) < 0.2 and math.abs(lookVector:Dot(LeftLean.Normal)) < facingMax then
		return LeftLean, -1
	elseif
		RightLean
		and math.abs(RightLean.Normal.Y) < 0.2
		and math.abs(lookVector:Dot(RightLean.Normal)) < facingMax
	then
		return RightLean, 1
	end

	return nil
end

local function StartWallRun(MovementObj: ClientTypes.MovementObj, hit: RaycastResult, side)
	if not MovementObj or not MovementObj.char or not MovementObj.identifer then
		return
	end
	-- Opt A: ignore re-trigger while already wallrunning — don't nuke the active movers
	if MovementObj.IsActing.WallRunning then
		return
	end
	-- Kill any lingering jump-tail mover so wallrun never stacks on it
	do
		local prevConn = MovementObj.InfoTable.Wallrun._JumpConn :: RBXScriptConnection?
		if prevConn then
			pcall(function()
				prevConn:Disconnect()
			end)
			MovementObj.InfoTable.Wallrun._JumpConn = nil
		end
		local prevLV = MovementObj.InfoTable.Wallrun._JumpLV :: LinearVelocity?
		if prevLV and prevLV.Parent then
			pcall(function()
				prevLV:Destroy()
			end)
		end
		MovementObj.InfoTable.Wallrun._JumpLV = nil
	end
	pcall(function()
		MovementObj:CancelConflictingActions("WallRunStart")
	end)

	local char = MovementObj.char
	local CurrentWeapon = char:GetAttribute("CurrentWeapon")
	local Hum = char.Humanoid
	local HRP: Part = char.HumanoidRootPart
	local WallrunSpeed = SpeedMods.GetMovementSpeed(char, "WallRunSpeed", "WallRun")

	if not Hum or not HRP then
		return
	end

	if MovementObj.IsActing.IsSprinting then
		WallrunSpeed = SpeedMods.GetMovementSpeed(char, "WallRunSprintSpeed", "WallRun")
	elseif MovementObj.IsActing.IsEXSprinting then
		WallrunSpeed = SpeedMods.GetMovementSpeed(char, "WallRunExSprintSpeed", "WallRun")
	end

	local Sprintflag = MovementObj.IsActing.IsSprinting or MovementObj.IsActing.IsEXSprinting
	local finalespeed = FlowManager.OnWallRunStart(MovementObj, WallrunSpeed, Sprintflag)

	WallrunSpeed = finalespeed

	local conn

	local Normal = hit.Normal.Unit

	local R_anim = GetCachedTrack(MovementObj, Hum, CurrentWeapon, "WallrunR")
	local L_anim = GetCachedTrack(MovementObj, Hum, CurrentWeapon, "WallrunL")

	if AnimationCache[MovementObj] then
		local hopR = AnimationCache[MovementObj][CurrentWeapon .. "_WallhopR"]
		local hopL = AnimationCache[MovementObj][CurrentWeapon .. "_WallhopL"]

		if hopR and hopR.IsPlaying then
			hopR:Stop(0.15)
		end
		if hopL and hopL.IsPlaying then
			hopL:Stop(0.15)
		end
	end

	if math.abs(Normal.Y) > 0.2 then
		warn("[Wallrun Module] = Normal Y failed to be in range")
	end

	local WallDir = Normal:Cross(Vector3.new(0, 1, 0)).Unit

	if WallDir:Dot(HRP.CFrame.LookVector) < 0 then
		WallDir = -WallDir
	end

	local entryvel = HRP.AssemblyLinearVelocity
	MovementObj.InfoTable.Wallrun.Side = side

	local playerFlag = MovementObj.identifer
	if playerFlag:IsA("Player") then
		local infotable = {
			Action = "Wallrun",
		}

		MovementObj:BarTween(infotable)
	end

	char:SetAttribute("IsWallRunning", true) -- for server to tell clients
	MovementObj.IsActing.WallRunning = true -- for the client to know they are wallrunning

	if not RunService:IsServer() then
		MovementObj:ServerRequest("WallRunStart")
	end

	if MovementObj.InfoTable.DoubleJump then
		MovementObj.InfoTable.DoubleJump.Used = 0
	end

	local Att = HRP:FindFirstChild("WallRunAttachment")

	if not Att then
		Att = Instance.new("Attachment")
		Att.Name = "WallRunAttachment"
		Att.Parent = HRP
	end

	local vel = Instance.new("LinearVelocity")
	vel.Attachment0 = Att
	vel.RelativeTo = Enum.ActuatorRelativeTo.World
	vel.Parent = HRP
	vel.ForceLimitsEnabled = true
	vel.ForceLimitMode = Enum.ForceLimitMode.PerAxis

	local mass = HRP.AssemblyMass * 1500
	vel.MaxAxesForce = Vector3.new(mass, mass, mass)

	local algin = Instance.new("AlignOrientation")
	algin.Attachment0 = Att
	algin.Mode = Enum.OrientationAlignmentMode.OneAttachment
	algin.Responsiveness = 50
	algin.Parent = HRP

	Hum.AutoRotate = false

	if side == 1 then
		R_anim:Play()
	elseif side == -1 then
		L_anim:Play()
	end

	local duration = MovementData.Data.WallRunDuration
	local elapsed = 0

	local function StopWallRun(reason)
		conn:Disconnect()

		if not MovementObj.IsActing.WallRunning then
			return
		end

		WallrunCooldowns[MovementObj] = tick()

		if reason ~= "Jump" then
			HRP.AssemblyLinearVelocity += Normal * MovementData.Data.WallRunEntryPush
		end

		vel.Enabled = false
		algin.Enabled = false

		vel:Destroy()
		algin:Destroy()
		Att:Destroy()

		Hum.AutoRotate = true
		MovementObj.IsActing.WallRunning = false
		char:SetAttribute("IsWallRunning", false)

		if not RunService:IsServer() then
			MovementObj:ServerRequest("WallRunEnd")
		end

		R_anim:Stop()
		L_anim:Stop()

		FlowManager.OnWallRunEnd(MovementObj, function()
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

		MovementObj:UpdateWalkTracks()
		MovementObj:BarTweenStop({
			Action = "Wallrun",
		})
	end

	conn = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt

		-- Ragdoll gate: eject mid-run if ragdolled/stunned (covers both entry + active)
		if char:GetAttribute("IsRagdoll") or char:GetAttribute("Stunned") then
			StopWallRun("Ragdoll")
			return
		end

		if elapsed >= duration then
			StopWallRun()
			return
		end

		if Hum.FloorMaterial ~= Enum.Material.Air then
			StopWallRun()
			return
		end

		local check = Cast.Ray({
			Origin = HRP.Position,
			Direction = -Normal,
			Range = MovementData.Data.WallRunContactRange,
			FilterList = { char, VFXFolder, NPCFolder, CharactersFolder },
		})

		if not check then
			local FPS = workspace:GetRealPhysicsFPS()
			local coyotetime = (1 / FPS) * 5
			local frozenNormal = Normal

			task.delay(coyotetime, function()
				if not MovementObj.IsActing.WallRunning then
					return
				end

				local checkv2 = Cast.Ray({
					Origin = HRP.Position,
					Direction = -frozenNormal,
					Range = MovementData.Data.WallRunContactRange,
					FilterList = { char, VFXFolder, NPCFolder, CharactersFolder },
				})

				if not checkv2 then
					StopWallRun()
				end
			end)
			return
		end

		-- FOLLOW WALL CURVATURE: re-derive the wall direction from the fresh hit
		local freshNormal = check.Normal.Unit
		if math.abs(freshNormal.Y) > 0.2 then
			StopWallRun()
			return
		end

		local freshWallDir = freshNormal:Cross(Vector3.new(0, 1, 0)).Unit
		if freshWallDir:Dot(HRP.CFrame.LookVector) < 0 then
			freshWallDir = -freshWallDir
		end

		-- Drop the run on corners sharper than the allowed curve
		local angleChange = math.deg(math.acos(math.clamp(WallDir:Dot(freshWallDir), -1, 1)))
		if angleChange > MovementData.Data.WallRunCurveMaxAngle then
			StopWallRun()
			return
		end

		local steerAlpha = 1 - math.exp(-MovementData.Data.WallRunCurveSteerRate * dt)
		WallDir = WallDir:Lerp(freshWallDir, steerAlpha).Unit
		Normal = Normal:Lerp(freshNormal, steerAlpha).Unit

		local gforce = Vector3.new(0, -workspace.Gravity * MovementData.Data.WallRunGravityScale, 0)

		vel.VectorVelocity = WallDir * WallrunSpeed + gforce * dt + entryvel * MovementData.Data.WallRunCarry
		algin.CFrame = CFrame.lookAt(HRP.Position, HRP.Position + WallDir, Vector3.new(0, 1, 0))
		MovementObj.InfoTable.Wallrun.Stop = StopWallRun
		MovementObj.InfoTable.Wallrun.Side = side
		MovementObj.InfoTable.Wallrun.Normal = Normal
	end)
end

function Wallrun.Start(MovementObj: ClientTypes.MovementObj)
	local char = MovementObj.char
	if not char then
		return
	end
	local hum = char.Humanoid
	if not hum then
		return
	end

	-- Ragdoll gate: never start wallrun while ragdolled/stunned
	if char:GetAttribute("IsRagdoll") or char:GetAttribute("Stunned") then
		return
	end

	if hum.FloorMaterial ~= Enum.Material.Air then
		return
	end

	if
		MovementObj.IsActing.WallRunning
		or MovementObj.IsActing.Climbing
		or MovementObj.IsActing.Dodging
		or MovementObj.States.IsOnWall
		or MovementObj.States.IsCrouching
	then
		return
	end

	-- Opt A: only sweep after confirming we're not already wallrunning
	pcall(function()
		MovementObj:CancelConflictingActions("WallRunStart")
	end)

	if WallrunCooldowns[MovementObj] and tick() - WallrunCooldowns[MovementObj] < MovementData.Data.WallRunCooldown then
		return
	end

	local hit, side = WallChecker(char)
	if not hit then
		return
	end

	MovementObj:ClearWalkAnims()

	StartWallRun(MovementObj, hit, side)
end

function Wallrun.Jump(MovementObj: ClientTypes.MovementObj)
	if not MovementObj or not MovementObj.IsActing.WallRunning then
		return
	end

	local char = MovementObj.char
	if char and (char:GetAttribute("IsRagdoll") or char:GetAttribute("Stunned")) then
		return
	end
	local Hum = char.Humanoid
	local HRP = char.HumanoidRootPart
	local CurrentWeapon = char:GetAttribute("CurrentWeapon")
	if not HRP then
		return
	end

	MovementObj:ServerRequest("WallRunJump")
	if type(MovementObj.InfoTable.Wallrun.Stop) == "function" then
		pcall(function()
			MovementObj.InfoTable.Wallrun.Stop("Jump")
		end)
	else
		MovementObj.InfoTable.Wallrun.Stop("Jump")
	end

	FlowManager.OnMechanicJump(MovementObj, "WallRunJump")

	local R_animJump = GetCachedTrack(MovementObj, Hum, CurrentWeapon, "WallhopR")
	local L_animJump = GetCachedTrack(MovementObj, Hum, CurrentWeapon, "WallhopL")
	local side = MovementObj.InfoTable.Wallrun.Side
	local Normal = MovementObj.InfoTable.Wallrun.Normal

	if not side or not Normal then
		return
	end

	local D = MovementData.Data

	local WallDir = Normal:Cross(Vector3.new(0, 1, 0)).Unit
	if WallDir:Dot(HRP.CFrame.LookVector) < 0 then
		WallDir = -WallDir
	end

	local uppower = SpeedMods.GetJumpSpeed(char, "WallJumpUp")
	local forwardPower = SpeedMods.GetJumpSpeed(char, "WallJumpForward")

	-- Preserve horizontal velocity and layer the launch on top of it
	local flatVel = Vector3.new(HRP.AssemblyLinearVelocity.X, 0, HRP.AssemblyLinearVelocity.Z)

	-- Camera-only launch with a hint of wall direction so it never dives into the wall
	local launchDir = WallDir
	local cam = workspace.CurrentCamera
	if not RunService:IsServer() and cam then
		local camLook = cam.CFrame.LookVector
		local camFlat = Vector3.new(camLook.X, 0, camLook.Z)
		if camFlat.Magnitude > 0.1 then
			launchDir = camFlat.Unit:Lerp(WallDir, D.WallJumpWallDirBlend).Unit
		end
	end

	-- Input decides whether we hop to the next wall (pushing away from it) or
	-- just launch forward. S and D intentionally do nothing lateral.
	local inputDir = Vector3.new(Hum.MoveDirection.X, 0, Hum.MoveDirection.Z)
	local hop = Vector3.zero
	local forwardScale = 1
	if inputDir.Magnitude > 0.1 then
		inputDir = inputDir.Unit
		if inputDir:Dot(Normal) > 0.1 then
			hop = Normal * SpeedMods.GetJumpSpeed(char, "WallJumpHop")
			forwardScale = 0.8
		end
	end

	local boostFlat = flatVel + launchDir * (forwardPower * forwardScale) + hop
	local launchVect = boostFlat + Vector3.new(0, uppower, 0)

	if side == 1 then
		R_animJump:Play(0)
	elseif side == -1 then
		L_animJump:Play(0)
	end

	local attachment = HRP:FindFirstChild("RootAttachment") or Instance.new("Attachment", HRP)

	-- Kill any previous jump tail before launching (spam-safe)
	do
		local prevConn = MovementObj.InfoTable.Wallrun._JumpConn :: RBXScriptConnection?
		if prevConn then
			pcall(function()
				prevConn:Disconnect()
			end)
			MovementObj.InfoTable.Wallrun._JumpConn = nil
		end
		local prevLV = MovementObj.InfoTable.Wallrun._JumpLV :: LinearVelocity?
		if prevLV and prevLV.Parent then
			pcall(function()
				prevLV:Destroy()
			end)
		end
		MovementObj.InfoTable.Wallrun._JumpLV = nil
	end

	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = attachment
	lv.MaxForce = math.huge
	lv.VectorVelocity = launchVect
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = HRP
	MovementObj.InfoTable.Wallrun._JumpLV = lv

	local boostDuration = D.WallJumpBoostDuration
	local decayTime = D.WallJumpDecayTime
	local totalDur = boostDuration + decayTime

	-- Decay end-point: lose 40% of launch velocity over decay, Y is cut (gravity wins)
	local walkSpeed = SpeedMods.GetMovementSpeed(char, "WalkSpeed", "Walk") or 16
	local launchFlat = Vector3.new(launchDir.X, 0, launchDir.Z)
	local startFlat = Vector3.new(boostFlat.X, 0, boostFlat.Z)
	local retainFactor = D.WallJumpRetainFactor or 0.6
	local endFlat: Vector3
	if startFlat.Magnitude > 0.1 then
		local retained = startFlat * retainFactor
		if retained.Magnitude >= walkSpeed then
			endFlat = retained
		elseif launchFlat.Magnitude > 0.1 then
			endFlat = launchFlat.Unit * walkSpeed
		else
			endFlat = startFlat.Unit * walkSpeed
		end
	elseif launchFlat.Magnitude > 0.1 then
		endFlat = launchFlat.Unit * walkSpeed
	else
		endFlat = Vector3.zero
	end

	local startT = os.clock()
	local jumpConn: RBXScriptConnection? = nil
	jumpConn = RunService.Heartbeat:Connect(function(dt)
		if not lv or not lv.Parent then
			if jumpConn then
				jumpConn:Disconnect()
			end
			MovementObj.InfoTable.Wallrun._JumpConn = nil
			return
		end
		-- Anti-fling: head-on contact kills the mover, anim finishes solo.
		do
			local curVel = lv.VectorVelocity
			if curVel.Magnitude > 1 then
				local d = curVel.Unit
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { char, VFXFolder, NPCFolder, CharactersFolder }
				local range = curVel.Magnitude * math.max(dt or 0.016, 0.001) * 2 + JUMP_WALL_PROBE_MARGIN
				local hit = workspace:Raycast(HRP.Position, d * range, params)
				if hit and d:Dot(hit.Normal) < JUMP_WALL_STOP_DOT then
					if jumpConn then
						jumpConn:Disconnect()
					end
					MovementObj.InfoTable.Wallrun._JumpConn = nil
					MovementObj.InfoTable.Wallrun._JumpLV = nil
					lv:Destroy()
					return
				end
			end
		end
		local t = os.clock() - startT
		if t < boostDuration then
			lv.VectorVelocity = launchVect
			return
		end
		if t >= totalDur then
			if jumpConn then
				jumpConn:Disconnect()
			end
			MovementObj.InfoTable.Wallrun._JumpConn = nil
			MovementObj.InfoTable.Wallrun._JumpLV = nil
			if lv and lv.Parent then
				lv:Destroy()
			end
			return
		end
		local u = math.clamp((t - boostDuration) / math.max(0.001, decayTime), 0, 1)
		local e = easeOutCubic(u)
		local curFlat = Vector3.new(wjLerp(startFlat.X, endFlat.X, e), 0, wjLerp(startFlat.Z, endFlat.Z, e))
		-- Y cut: fade fast in first ~40% of decay, then 0 so gravity takes over
		local yFade = 1 - easeOutCubic(math.clamp(u * 2.5, 0, 1))
		local curY = uppower * yFade
		lv.VectorVelocity = curFlat + Vector3.new(0, curY, 0)
	end)
	MovementObj.InfoTable.Wallrun._JumpConn = jumpConn
end

return Wallrun
