local DoubleJump = {}
local Debris = game:GetService("Debris")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local RSModules = RS.Modules

local ClientTypes = require(RSModules.ClientTypes)
local FlowManager = require(RSModules.Movement.Ultils.Flow)
local MovementData = require(RSModules.Movement.Data)
local SpeedMods = require(RSModules.Movement.Ultils.Speed)

local WeaponAnimations = RS.Animations.Weapons

local JumpCooldowns = {}

local function LoadJumpAnim(Hum, CurrentWeapon)
	local weaponFolder = WeaponAnimations[CurrentWeapon]
	if not weaponFolder or not weaponFolder.Movement then
		return nil
	end

	local asset = weaponFolder.Movement.DoubleJump
	if not asset then
		return nil
	end

	local ok, track = pcall(function()
		return Hum.Animator:LoadAnimation(asset)
	end)

	if ok then
		return track
	end

	return nil
end

function DoubleJump.Start(MovementObj: ClientTypes.MovementObj)
	if not MovementObj or not MovementObj.char then
		return
	end

	if JumpCooldowns[MovementObj] and tick() - JumpCooldowns[MovementObj] < 0.05 then
		return
	end

	pcall(function() MovementObj:CancelConflictingActions("DoubleJump") end)

	local D = MovementData.Data
	local info = MovementObj.InfoTable.DoubleJump
	if not info then
		return
	end

	if not MovementObj.States.IsInAir then
		return
	end
	if MovementObj.IsActing.WallRunning or MovementObj.IsActing.Climbing then
		return
	end

	local char = MovementObj.char
	local Hum = char.Humanoid
	local HRP = char.HumanoidRootPart
	local CurrentWeapon = char:GetAttribute("CurrentWeapon")
	if not Hum or not HRP then
		return
	end

	-- Free pool is a HARD cap in combat (no stamina-purchased overflow).
	-- Out of combat, jumps past the pool are gated by stamina upstream.
	if char:GetAttribute("InCombat") and info.Used >= (info.FreeJumps or D.DoubleJumps) then
		return
	end

	info.Used += 1
	info.LastTime = os.clock()

	local anim = LoadJumpAnim(Hum, CurrentWeapon)
	if anim then
		anim:Play()
	end

	local flatVel = Vector3.new(HRP.AssemblyLinearVelocity.X, 0, HRP.AssemblyLinearVelocity.Z)
	local up = Vector3.new(0, SpeedMods.GetJumpSpeed(char, "DoubleJumpPower"), 0)

	-- W held (forward intent) -> forward and up; otherwise -> straight up
	local forward = Vector3.zero
	local isServer = RunService:IsServer()
	local cam = workspace.CurrentCamera

	if not isServer and cam then
		local camLook = cam.CFrame.LookVector
		local flatCam = Vector3.new(camLook.X, 0, camLook.Z)
		if flatCam.Magnitude > 0.1 then
			flatCam = flatCam.Unit

			local moveDir = Hum.MoveDirection
			if moveDir:Dot(flatCam) > 0.1 then
				forward = flatCam * SpeedMods.GetJumpSpeed(char, "DoubleJumpForward")
			end
		end
	end

	local attachment = HRP:FindFirstChild("RootAttachment") or Instance.new("Attachment", HRP)

	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = attachment
	lv.MaxForce = math.huge
	lv.VectorVelocity = flatVel + forward + up
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = HRP

	Debris:AddItem(lv, 0.2)

	FlowManager.OnDoubleJump(MovementObj)
	MovementObj:ServerRequest("DoubleJump")
end

function DoubleJump.Reset(MovementObj: ClientTypes.MovementObj)
	if not MovementObj or not MovementObj.InfoTable or not MovementObj.InfoTable.DoubleJump then
		return
	end

	MovementObj.InfoTable.DoubleJump.Used = 0
end

return DoubleJump
