local CrouchModule = {}
local RS = game:GetService("ReplicatedStorage")
local RSModules = RS.Modules

local RunService = game:GetService("RunService")
local TS = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local ClientTypes = require(RSModules.ClientTypes)
local Cast = require(RSModules.Cast)
local MovementData = require(RSModules.Movement.Data)
local SpeedMods = require(RSModules.Movement.Ultils.Speed)
local FlowManager = require(RSModules.Movement.Ultils.Flow)
local cam = game.Workspace.CurrentCamera

local WeaponAnimationFolder = RS.Animations.Weapons

local VFXFolder = workspace:WaitForChild("VFX")
local NPCFolder = workspace:WaitForChild("NPC")
local CharactersFolder = workspace:WaitForChild("Characters")

local Config = {
	Cooldown = MovementData.Data.CrouchCooldown,
	DefaultFov = MovementData.Data.BaseFov,
	CrouchFov = MovementData.Data.CrouchFov,
	CrouchFovTime = 0.5,
	ResetFovTime = 1,
	CamOffset = -0.5,
	MinCamDist = 0.5,
	MaxCamDist = 10,
	DustEnabled = true,
	DynamicDustColor = true,
	DustSpawnRate = 0.15,
	MaxFreefallTime = 0.35
}

local function SpawnDust(HRP: BasePart, hitInstance: BasePart?, name: string, emitCount: number)
	local template = RS.Effects.Combat.Dust
	if not template then
		return
	end

	local dust = template:Clone()
	dust.Position = HRP.Position + Vector3.new(0, -2.5, 0)
	dust.Parent = workspace.VFX
	dust.Name = name

	if Config.DynamicDustColor and hitInstance and hitInstance:IsA("BasePart") then
		dust.Attachment.Dust.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, hitInstance.Color),
			ColorSequenceKeypoint.new(1, hitInstance.Color),
		})
	else
		dust.Attachment.Dust.Color = ColorSequence.new(Color3.fromRGB(255, 225, 225))
	end

	dust.Attachment.Dust:Emit(emitCount)
	Debris:AddItem(dust, 0.8)
end

local CrouchDebounce = {}
local OrginalMaxCam = {}
local OrginalMinCam = {}

local function StopChecker(MovementObj: ClientTypes.MovementObj)
	local stop = false

	if MovementObj.IsActing.Climbing then
		stop = true
		return stop
	end
	if MovementObj.IsActing.Dodging then
		stop = true
		return stop
	end
	if MovementObj.IsActing.WallRunning then
		stop = true
		return stop
	end

	return stop
end

local function RunChecker(MovementObj: ClientTypes.MovementObj)
	local flag = false
	local Variant = nil
	if MovementObj.IsActing.IsEXSprinting then
		flag = true
		Variant = "EX"
		return flag, Variant
	end

	if MovementObj.IsActing.IsSprinting then
		flag = true
		Variant = "Normal"
		return flag, Variant
	end

	return flag, Variant
end

local function HeadChecker(char)
	local head = char:FindFirstChild("Head")
	if not head then
		return false
	end

	local Result = Cast.Ray({
		Origin = head.Position,
		Direction = head.CFrame.UpVector * 1.5,
		FilterList = { char, VFXFolder, NPCFolder, CharactersFolder },
	})

	return Result ~= nil
end

function CrouchModule.StartCrouch(MovementObj: ClientTypes.MovementObj, momentumRetain: number?)
	pcall(function() MovementObj:CancelConflictingActions("CrouchStart") end)
	if StopChecker(MovementObj) then
		return
	end
	local char = MovementObj.char
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not char or not hum then
		return
	end
	if CrouchDebounce[MovementObj] then
		return
	end
	local HRP = char.HumanoidRootPart
	local CurrentWeapon = char:GetAttribute("CurrentWeapon")
	local CrouchAnim = hum.Animator:LoadAnimation(WeaponAnimationFolder[CurrentWeapon].Movement.Crouching)
	local notmoving = false
	local IsonGround = true
	local Dustdebounce = true
	local FallTimer = 0

	CrouchDebounce[MovementObj] = false
	MovementObj.States.IsCrouching = true
	CrouchAnim:Play()
	MovementObj:ClearWalkAnims()
	MovementObj:ServerRequest("CrouchStart")
	hum.WalkSpeed = SpeedMods.GetMovementSpeed(char, "CrouchSpeed", "Crouch")
	FlowManager.OnCrouchStart(MovementObj, momentumRetain)

	local playerflag = MovementObj.identifer
	local plr = nil
	if playerflag:IsA("Player") then
		plr = playerflag
	end

	if plr then
		OrginalMinCam[MovementObj] = plr.CameraMinZoomDistance
		OrginalMaxCam[MovementObj] = plr.CameraMaxZoomDistance

		plr.CameraMaxZoomDistance = Config.MaxCamDist
		plr.CameraMinZoomDistance = Config.MinCamDist

		local FovGoal1 = { FieldOfView = Config.CrouchFov }
		local FovInfo1 = TweenInfo.new(Config.CrouchFovTime)
		local FovTween1 = TS:Create(cam, FovInfo1, FovGoal1)
		FovTween1:Play()

		local CamGoal1 = { CameraOffset = Vector3.new(0, Config.CamOffset, 0) }
		local Caminfo1 = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0)

		local CamTween1 = TS:Create(hum, Caminfo1, CamGoal1)
		CamTween1:Play()
	end

	hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	local conn = nil

	local function CrouchStop()
		if HeadChecker(char) then
			return
		end
		if not MovementObj.States.IsCrouching then
			return
		end
		MovementObj.States.IsCrouching = false
		CrouchAnim:Stop()
		MovementObj:UpdateWalkTracks()
		MovementObj:ServerRequest("CrouchEnd")
		hum.WalkSpeed = SpeedMods.GetMovementSpeed(char, "WalkSpeed", "Walk")
		FlowManager.OnCrouchEnd(MovementObj, hum.WalkSpeed)
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

		local playerflag = MovementObj.identifer
		local plr = nil
		if playerflag:IsA("Player") then
			plr = playerflag
		end

		if plr then
			plr.CameraMaxZoomDistance = OrginalMaxCam[MovementObj]
			plr.CameraMinZoomDistance = OrginalMinCam[MovementObj]

			local FovGoal2 = { FieldOfView = Config.DefaultFov }
			local Fovinfo2 = TweenInfo.new(Config.ResetFovTime)
			local Fovtween2 = TS:Create(cam, Fovinfo2, FovGoal2)
			Fovtween2:Play()

			local camgoal2 = { CameraOffset = Vector3.new(0, 0, 0) }
			local Caminfo2 = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0)

			local CamTween2 = TS:Create(hum, Caminfo2, camgoal2)
			CamTween2:Play()
		end
	end

	MovementObj.InfoTable.Crouch.Stop = CrouchStop

	conn = RunService.Heartbeat:Connect(function()
		notmoving = hum.MoveDirection.Magnitude == 0

		if notmoving and MovementObj.States.IsCrouching then
			CrouchAnim:AdjustSpeed(0)
		end

		if not notmoving and MovementObj.States.IsCrouching then
			CrouchAnim:AdjustSpeed(1)
		end

		IsonGround = hum.FloorMaterial ~= Enum.Material.Air

		if Config.DustEnabled and IsonGround and MovementObj.States.IsCrouching and Dustdebounce and not notmoving then
			Dustdebounce = false

			local Result = Cast.Ray({
				Origin = HRP.Position + Vector3.new(0, 1, 0),
				Direction = Vector3.new(0, -4.5, 0),
				FilterList = { char, VFXFolder, NPCFolder, CharactersFolder },
			})

			SpawnDust(HRP, Result and Result.Instance, "CrouchDust", 1)

			task.wait(Config.DustSpawnRate)
			Dustdebounce = true
		end

		if not IsonGround and MovementObj.States.IsCrouching then
			FallTimer = FallTimer + RunService.Heartbeat:Wait()
			if FallTimer >= Config.MaxFreefallTime then
				CrouchStop()
			end
		else
			FallTimer = 0
		end
	end)
end

local SlideDebounce = {}

function CrouchModule.StartSlide(MovementObj: ClientTypes.MovementObj)
	pcall(function() MovementObj:CancelConflictingActions("SlideStart") end)
	if MovementObj.States.ISSliding then
		MovementObj.InfoTable.Slide.Stop()
		return
	end
	if SlideDebounce[MovementObj] then
		return
	end
	if StopChecker(MovementObj) then
		return
	end

	local char = MovementObj.char
	local hum = char:FindFirstChildOfClass("Humanoid")
	local HRP = char:FindFirstChild("HumanoidRootPart")
	if not hum or not HRP then
		return
	end

	SlideDebounce[MovementObj] = true
	MovementObj.States.ISSliding = true
	MovementObj:ServerRequest("SlideStart")

	FlowManager.OnSlideStart(MovementObj)

	local stored = FlowManager.GetStoredVelocity(MovementObj)
	if stored.Magnitude < 1 then
		stored = Vector3.new(HRP.CFrame.LookVector.X, 0, HRP.CFrame.LookVector.Z).Unit * (MovementData.Data.SprintSpeed or 20)
	end

	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bv.Velocity = stored
	bv.Parent = HRP

	local SlideAnim = nil
	local CurrentWeapon = char:GetAttribute("CurrentWeapon")
	local WeaponsFolder = WeaponAnimationFolder[CurrentWeapon] and WeaponAnimationFolder[CurrentWeapon].Movement
	if WeaponsFolder and WeaponsFolder.Slide then
		SlideAnim = hum.Animator:LoadAnimation(WeaponsFolder.Slide)
		SlideAnim:Play()
	end

	local conn = nil
	local dustTimer = 0
	MovementObj.InfoTable.Slide.Stop = function()
		if not MovementObj.States.ISSliding then
			return
		end
		MovementObj.States.ISSliding = false
		if conn then
			conn:Disconnect()
			conn = nil
		end
		if bv and bv.Parent then
			bv:Destroy()
		end
		if SlideAnim and SlideAnim.IsPlaying then
			SlideAnim:Stop()
		end
		MovementObj:ServerRequest("SlideEnd")
		FlowManager.OnSlideEnd(MovementObj, function() end)
		MovementObj.InfoTable.Slide.Stop = function() end
		task.delay(0.05, function()
			SlideDebounce[MovementObj] = nil
		end)
	end

	conn = RunService.Heartbeat:Connect(function(dt)
		if not MovementObj.States.ISSliding or not bv.Parent then
			return
		end

		local flat = Vector3.new(bv.Velocity.X, 0, bv.Velocity.Z)
		local slideDir = flat.Unit
		if slideDir.Magnitude < 0.001 then
			slideDir = Vector3.new(HRP.CFrame.LookVector.X, 0, HRP.CFrame.LookVector.Z).Unit
		end

		local hit = Cast.Ray({
			Origin = HRP.Position + Vector3.new(0, 1, 0),
			Direction = Vector3.new(0, -1, 0),
			Range = 3.5,
			FilterList = { char, VFXFolder, NPCFolder, CharactersFolder },
		})
		local groundNormal = hit and hit.Normal or Vector3.new(0, 1, 0)
		local slope = groundNormal:Dot(slideDir)

		if Config.DustEnabled and hit then
			dustTimer += dt
			if dustTimer >= Config.DustSpawnRate then
				dustTimer = 0
				local puffs = math.clamp(math.floor(bv.Velocity.Magnitude / 20), 1, 3)
				SpawnDust(HRP, hit.Instance, "SlideDust", puffs)
			end
		else
			dustTimer = Config.DustSpawnRate
		end

		local speed = bv.Velocity.Magnitude
		if slope <= 0 then
			speed = math.max(0, speed - MovementData.Data.SlideSpeedDrain * dt)
			MovementObj.Flow.Momentum = math.max(0, MovementObj.Flow.Momentum - MovementData.Data.SlideMomentumDrain * dt)
		else
			speed = math.min(MovementData.Data.SlideMaxSpeed, speed + MovementData.Data.SlideSpeedGain * slope * dt)
			MovementObj.Flow.Momentum = math.min(MovementObj.Flow.MaxMomentum or 100, MovementObj.Flow.Momentum + MovementData.Data.SlideMomentumGain * slope * dt)
		end

		if speed < MovementData.Data.SlideEndSpeed then
			bv.Velocity = Vector3.new()
			MovementObj.InfoTable.Slide.Stop()
			return
		end

		bv.Velocity = slideDir * speed
	end)
end

function CrouchModule.Start(MovementObj: ClientTypes.MovementObj)
	pcall(function() MovementObj:CancelConflictingActions("CrouchStart") end)
	if MovementObj.IsActing.IsSprinting or MovementObj.IsActing.IsEXSprinting then
		CrouchModule.StartSlide(MovementObj)
		return
	end

	if MovementObj.States.IsCrouching then
		MovementObj.InfoTable.Crouch.Stop()
		return
	end

	CrouchModule.StartCrouch(MovementObj)
end

return CrouchModule
