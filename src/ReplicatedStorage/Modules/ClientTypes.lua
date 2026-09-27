export type MovementObjData = {
	identifer: any,
	char: Model,
	IsReady: boolean,

	IsActing: { -- Flags for if they are using the movement system
		Dodging: boolean,
		WallRunning: boolean,
		Climbing: boolean,
		IsSprinting: boolean,
		IsEXSprinting: boolean,
	},

	States: {
		IsGrounded: boolean, -- Standard is on ground
		IsInAir: boolean, -- In the air
		IsOnWall: boolean, -- Is holding onto a wall
		IsCrouching: boolean, -- Is crouching
		ISSliding: boolean, -- Is sliding
		IsResting: boolean, -- Is resting
	},

	_attributeSignals: { [string]: any },
	_attributePaths: { [string]: string },

	InfoTable: { -- Table for storing important info for the movement system (like wallrun dir, climb dir, etc.)
		Wallrun: {
			Side: number, -- Side of the wall (1 is right, -1 is left)
			Normal: Vector3, -- Normal of the wall
			Stop: (reason: string) -> (),
			_JumpConn: RBXScriptConnection?, -- Active walljump tail heartbeat (nil when idle)
			_JumpLV: LinearVelocity?, -- Active walljump mover (nil when idle)
		},

		DoubleJump: {
			FreeJumps:number,
			Used: number, -- How many air jumps have been used
			LastTime: number, -- Timestamp of the last double jump (drives the air dodge bonus window)
		},

		Dodge: {
			Dir: Vector3, -- Direction of the dodge (forward, back, left, right and spot)
			Type: string, -- Type of dodge (standard, airdash,)
			Speed: number, -- How fast the dodge is going
			Stop: () -> (),
			_CurveConn: RBXScriptConnection?, -- Active dodge curve heartbeat (nil when idle)
		},

		Climb: {
			FreeClimbs: number,
			Used: number,
			LastTime:number,
			Stop: () -> (),
		},

		Sprint: {
			Stop: () -> (),
			SprintAnim: AnimationTrack,
		},

		EXSprint: {
			Stop: () -> (),
		},

		WallHold: {
			Type: string, -- Type of wall hold (Ledge, Parallel, etc.)
			Stop: () -> (),
		},

		Crouch: {
			Stop: () -> (),
		},

		Slide: {
			Stop: () -> (),
		},

        Resting: {
			Stop:() -> (),
		},
        

	},

	WalkCycleAnims: {
		WalkForward: AnimationTrack,
		WalkRight: AnimationTrack,
		WalkLeft: AnimationTrack,
		WalkBack: AnimationTrack,
	},

	UI: {
		top: Frame,
		bottom: Frame,
		top_tilt: Frame,
		bottom_tilt: Frame,
	},

	Flow: {
		BaseSpeed: number,
		CurrentSpeed: number,
		TargetSpeed: number,

		WasSprinting: boolean,
		SprintIntentTime: number,
		LastMechanic: string,

		StoredVelocity: Vector3,
		LastAirVelocity: Vector3,
		EntryVelocity: Vector3,

		Momentum: number,
		MaxMomentum: number,

		FlowBonus: number,
		GlobalSpeedMult:number,
		ChainCount: number,
		LastChainTime: number,

		IsTransitioning: boolean,
		WallRunElapsed: number,
		LerpConnection: RBXScriptConnection?,
	},
}

export type MovementObjMethods = {
	BarTween: (self: MovementObj, infoTable: { any }) -> (),
	BarTweenStop: (self: MovementObj, infoTable: { any }) -> (),
	UpdateWalkTracks: (self: MovementObj) -> (),
	WalkCycle: (self: MovementObj) -> (),
	ClearWalkAnims: (self: MovementObj) -> (),
	ServerRequest: (self: MovementObj, action: string, ...any) -> (),
	StateChecker: (self: MovementObj, action: string, Ignore: boolean) -> boolean,
	CancelConflictingActions: (self: MovementObj, requestedAction: string) -> (),
	CleanupOrphanPhysics: (self: MovementObj) -> (),
	Destroy: (self: MovementObj) -> (),
	GetAttributeChangedSignal: (self: MovementObj, attributeName: string) -> (),
}

export type MovementObj = MovementObjData & MovementObjMethods

export type ElementBase = {
	Name: string,
	Data: { [string]: any },
	R: (self: ElementBase, char: Model) -> (),
	Z: (self: ElementBase, char: Model) -> (),
	X: (self: ElementBase, char: Model) -> (),
	C: (self: ElementBase, char: Model) -> (),
	V: (self: ElementBase, char: Model) -> (),
	Innate: ((self: ElementBase, char: Model) -> ())?,
	Mode1Init: ((self: ElementBase, char: Model) -> ())?,
	Mode2Init: ((self: ElementBase, char: Model) -> ())?,
	RevengeCounter: ((self: ElementBase, char: Model, target: Model) -> ())?,
}

return {}
