local StarterPlayer = game:GetService("StarterPlayer")
local Data = {}

export type DataSet = {
	--// General
	WalkSpeed: number,
	JumpHeight: number,
	JumpPower: number,
	BaseFov: number,
	DoubleJumps: number,

	--// Sprint
	SprintSpeed: number,
	ExSprintSpeed: number,
	ExSprintFallbackSpeed: number,
	SprintFov: number,
	ExSprintFov: number,

	--// Dodge
	DodgeSpeed: number,
	MaxDodgeSpeed: number,
	DodgeDuration: number,
	DodgeCooldown: number,
	DodgeCancelCooldown: number,
	AirDodgeMultiplier: number,
	AirDodgeBonusMultiplier: number,
	AirDodgeBonusWindow: number,
	AirDodgeCamPitchAngle: number,
	DodgeMomentumRetention: number,
	DodgeAccelTime: number,
	DodgeDecayTime: number,
	DodgePeakScale: number,
	DodgeMinCarry: number,

	--// Dive (E + IsInAir stance: accelerating forward-then-down arc,
	--// no time limit, killed by Landed / DoubleJump only)
	DiveSpeedBoost: number,
	DiveCooldown: number,
	DiveAccel: number,
	DiveMaxSpeed: number,
	DiveArcTime: number,
	DiveEntryBias: number,
	DiveEndBias: number,
	DivePosePitch: number,

	--// Double Jump
	DoubleJumpPower: number,
	DoubleJumpForward: number,
	DoubleJumpStaminaCost: number,

	--// Vault
	VaultBoost: number,
	VaultUp: number,
	VaultDuration: number,
	LedgeDistance: number,

	--// Crouch
	CrouchSpeed: number,
	CrouchCooldown: number,
	CrouchFov: number,

	--// Slide
	SlideEntryMomentumGain: number,
	SlideSpeedDrain: number,
	SlideSpeedGain: number,
	SlideMomentumDrain: number,
	SlideMomentumGain: number,
	SlideMaxSpeed: number,
	SlideEndSpeed: number,

	--// Climb
	ClimbSpeed: number,
	ClimbMaxHeight: number,
	ClimbDetectionRange: number,
	ClimbStaminaDrain: number,
	ClimbStaminaRegen: number,
	MaxClimbsPerSet:number,
	ClimbStaminaCost:number,

	--// Wall Run
	WallRunSpeed: number,
	WallRunSprintSpeed: number,
	WallRunExSprintSpeed: number,
	WallRunDuration: number,
	WallRunCheckRange: number,
	WallRunFacingLeniency: number,
	WallRunFacingMax: number,
	WallRunCamLean: number,
	WallRunContactRange: number,
	WallRunCooldown: number,
	WallRunGravityScale: number,
	WallRunCarry: number,
	WallRunEntryPush: number,

	--// Wall Jump
	WallJumpForward: number,
	WallJumpUp: number,
	WallJumpHop: number,
	WallJumpBoostDuration: number,
	WallJumpDecayTime: number,
	WallJumpWallDirBlend: number,
	WallJumpRetainFactor: number,

	--// Wall Run Curvature
	WallRunCurveSteerRate: number,
	WallRunCurveMaxAngle: number,

	--// Fall
	SafeFallDistance: number,
	FallDamagePerStud: number,
	FallReductionEndMax: number,
	FallReductionCap: number,
	FallEndStatMax: number,
}

local DataTable: DataSet = {
	--// General
	WalkSpeed = StarterPlayer.CharacterWalkSpeed,
	JumpHeight = StarterPlayer.CharacterJumpHeight,
	JumpPower = 50,
	BaseFov = 70,
	DoubleJumps = 2,

	--// Sprint
	SprintSpeed = 32,
	ExSprintSpeed = 45,
	ExSprintFallbackSpeed = 64,
	SprintFov = 80,
	ExSprintFov = 85,

	--// Dodge
	DodgeSpeed = 75,
	MaxDodgeSpeed = 120,
	DodgeDuration = 0.25,
	DodgeCooldown = 0.55,
	DodgeCancelCooldown = 0.5,
	AirDodgeMultiplier = 1.08,
	AirDodgeBonusMultiplier = 1.5,
	AirDodgeBonusWindow = 1.0,
	AirDodgeCamPitchAngle = 90,
	DodgeMomentumRetention = 0.5,
	DodgeAccelTime = 0.04,
	DodgeDecayTime = 0.29,
	DodgePeakScale = 1.18,
	DodgeMinCarry = 0.32,

	--// Dive
	DiveSpeedBoost = 1.12,
	DiveCooldown = 0.55,
	DiveAccel = 140,
	DiveMaxSpeed = 180,
	DiveArcTime = 0.40,
	DiveEntryBias = 0.15,
	DiveEndBias = 0.85,
	-- Extra local-X pitch on the dive align: the dive pose is authored
	-- face-up (+90 deg about X off the root), so the root pitches -90 to put
	-- the body headfirst along the fall line. Tune if the pose changes.
	DivePosePitch = -90,

	--// Double Jump
	DoubleJumpPower = 50,
	DoubleJumpForward = 45,
	DoubleJumpStaminaCost = 15,

	--// Vault
	VaultBoost = 35,
	VaultUp = 25,
	VaultDuration = 0.3,
	LedgeDistance = 0.4,

	--// Crouch
	CrouchSpeed = 9,
	CrouchCooldown = 0.1,
	CrouchFov = 65,

	--// Slide
	SlideEntryMomentumGain = 2,
	SlideSpeedDrain = 18,
	SlideSpeedGain = 28,
	SlideMomentumDrain = 6,
	SlideMomentumGain = 10,
	SlideMaxSpeed = 60,
	SlideEndSpeed = 2,

	--// Climb
	ClimbSpeed = 20,
	ClimbMaxHeight = 40,
	ClimbDetectionRange = 5,
	ClimbStaminaDrain = 1,
	ClimbStaminaRegen = 1,
	MaxClimbsPerSet = 3,
	ClimbStaminaCost = 10,
	
	

	--// Wall Run
	WallRunSpeed = 50,
	WallRunSprintSpeed = 80,
	WallRunExSprintSpeed = 85,
	WallRunDuration = 20,
	WallRunCheckRange = 4.5,
	WallRunFacingLeniency = 0.4,
	WallRunFacingMax = 0.6,
	WallRunCamLean = 8,
	WallRunContactRange = 5,
	WallRunCooldown = 0.2,
	WallRunGravityScale = 0.5,
	WallRunCarry = 0.15,
	WallRunEntryPush = 15,

	--// Wall Jump
	WallJumpForward = 125,
	WallJumpUp = 82.5,
	WallJumpHop = 75,
	WallJumpBoostDuration = 0.15,
	WallJumpDecayTime = 0.15,
	WallJumpWallDirBlend = 0.25,
	WallJumpRetainFactor = 0.6,

	--// Wall Run Curvature
	WallRunCurveSteerRate = 18,
	WallRunCurveMaxAngle = 35,

	--// Fall
	SafeFallDistance = 35,
	FallDamagePerStud = 3,
	FallReductionEndMax = 0.5,
	FallReductionCap = 1.0,
	FallEndStatMax = 99,
}

Data.Data = DataTable

return Data
