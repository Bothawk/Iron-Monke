--!strict
-- Every movement number lives here so the feel can be tuned without touching code.
-- Speeds are in studs per second, times are in seconds.

local MovementConfig = {
	Gravity = 230, -- Roblox default is 196.2; a bit higher makes jumps snappy

	WalkSpeed = 18, -- sniper equipped
	SprintSpeed = 25, -- holding sprint while moving forward
	SprintMinForwardInput = 0.3, -- how much forward input sprinting needs (no sprinting sideways or backward)
	KnifeSpeedMultiplier = 1.15, -- used once the knife exists (phase 4)
	CrouchSpeed = 9,
	ScopedSpeed = 10, -- walking while scoped in
	GroundAccelTime = 0.12, -- time to reach WalkSpeed from standing
	GroundStopTime = 0.1, -- time to stop from WalkSpeed

	JumpHeight = 7.5,
	CoyoteTime = 0.1, -- can still jump this long after walking off a ledge
	JumpBuffer = 0.12, -- a jump pressed this long before landing still counts
	AutoHopWhenHeld = false, -- false = every hop needs a fresh press, which keeps bhopping a skill
	JumpGroundIgnoreTime = 0.15, -- ignore the ground right after a jump so we don't instantly "land"

	-- Bhop. Jumping within PerfectHopWindow of landing skips ground friction.
	PerfectHopWindow = 0.1,
	PerfectHopBonus = 0.04, -- +4% speed per perfect hop
	PerfectHopMinSpeed = 14,

	-- Source-style air strafing: turning the mouse while holding A/D adds speed.
	AirAcceleration = 80,
	AirWishSpeedCap = 2, -- higher = faster speed gain from strafing (about +3 studs/s per good hop)

	GroundProbeRadius = 0.9,
	GroundProbeExtra = 0.35,
	MinGroundNormalY = 0.5, -- surfaces steeper than about 60° don't count as ground

	Slide = {
		MinSpeed = 16,
		Boost = 6,
		BoostCooldown = 0.8,
		Friction = 9, -- speed lost per second while sliding on flat ground
		EndSpeed = 10, -- the slide ends below this speed
		SteerRate = 1.5, -- radians per second the slide can turn toward your input
		SlopeGain = 1, -- how strongly downhill slopes speed you up
		UphillMultiplier = 1.5, -- uphill slows you down faster than downhill speeds you up
	},

	WallKick = {
		DetectDistance = 1.6, -- how close to a wall you must be, measured from your side
		Push = 20, -- speed away from the wall
		UpVelocity = 38,
		MaxKicks = 2, -- per trip into the air
		MinAirTime = 0.12, -- can't wall kick instantly after jumping
		MaxWallSteepness = 0.3, -- surfaces whose normal has |Y| above this aren't walls
	},

	Slingshot = {
		Tag = "Slingshot", -- CollectionService tag on launch ramps
		BaseLaunch = 55,
		SpeedToHeight = 0.9, -- extra upward speed per stud/s of slide speed
		HorizontalKeep = 0.7,
		Cooldown = 0.6,
	},

	Flow = {
		Max = 100,
		PerfectHop = 8,
		SlideJump = 12,
		WallKick = 15,
		AirKill = 25, -- used in phase 2
		HitPenalty = 30, -- used in phase 2
		DrainDelay = 0.4, -- grounded and not sliding for this long starts draining
		DrainRate = 40,
		OverflowDuration = 4,
		OverflowExitValue = 70, -- Flow drops to this when Overflow ends
		-- Tier 4 (Overflow) is only reached by filling the meter to Max.
		Tiers = {
			{ Min = 0, SpeedCap = 30, FovBonus = 0 },
			{ Min = 33, SpeedCap = 36, FovBonus = 0 },
			{ Min = 66, SpeedCap = 42, FovBonus = 4 },
			{ Min = 100, SpeedCap = 48, FovBonus = 6 },
		},
	},

	Camera = {
		-- Roblox FieldOfView is vertical. 80 vertical is about 110 horizontal on a 16:9 screen.
		BaseFov = 80,
		SlideFovBoost = 3,
		SprintFovBoost = 3,
		SlideDrop = 1.5,
		CrouchDrop = 1,
		DropSharpness = 37, -- reaches ~95% of the drop in 0.08 s
		SlideTilt = 3, -- degrees
		AirStrafeTilt = 1.5,
		TiltSharpness = 10,
		FovSharpness = 10,
		LandDipScale = 0.25, -- downward camera kick per stud/s of fall speed
		LandDipMax = 24,
		SpringStiffness = 180,
		SpringDamping = 0.8,
	},

	Keybinds = {
		Jump = {
			Keyboard = { Enum.KeyCode.Space },
			Gamepad = { Enum.KeyCode.ButtonA },
		},
		Sprint = {
			Keyboard = { Enum.KeyCode.LeftShift },
			Gamepad = { Enum.KeyCode.ButtonL3 }, -- clicking the left stick
		},
		Crouch = {
			Keyboard = { Enum.KeyCode.C },
			Gamepad = { Enum.KeyCode.ButtonB },
		},
	},

	AntiCheat = {
		SampleInterval = 0.25,
		Tolerance = 1.25, -- multiplier on the highest speed cap
		Leeway = 8, -- extra studs/s to absorb network jitter
		ViolationsToRubberBand = 3,
		ViolationWindow = 5,
	},
}

local maxSpeedCap = 0
for _, tier in MovementConfig.Flow.Tiers do
	maxSpeedCap = math.max(maxSpeedCap, tier.SpeedCap)
end
-- The fastest anyone can legitimately move horizontally.
MovementConfig.MaxSpeedCap = maxSpeedCap

MovementConfig.JumpVelocity = math.sqrt(2 * MovementConfig.Gravity * MovementConfig.JumpHeight)

return MovementConfig
