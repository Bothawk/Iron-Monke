--!strict
-- Client movement: bhop air strafing, slides, wall kicks, Slingshot ramps and Flow.
-- Velocity is worked out here every frame and handed to the Humanoid, so the
-- default Roblox walk and jump feel never applies.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config.MovementConfig)

local player = Players.LocalPlayer

local MovementController = {}

-- Read by the camera and HUD. Only this module writes to it.
MovementController.State = {
	Speed = 0,
	Flow = 0,
	Tier = 1,
	OverflowRemaining = 0,
	Grounded = false,
	Sliding = false,
	Crouching = false,
	StrafeInput = 0, -- -1 left, 0 none, 1 right
	LandCount = 0, -- increments on every landing so the camera can react
	LastLandSpeed = 0, -- downward speed at the moment of landing
	WallKicksUsed = 0,
}

local state = MovementController.State

local humanoid: Humanoid? = nil
local root: BasePart? = nil
local controls: any = nil

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local jumpPressedAt = -math.huge
local lastJumpAt = -math.huge
local lastGroundedAt = -math.huge
local landedAt = -math.huge
local lastSlideBoostAt = -math.huge
local lastSlingshotAt = -math.huge
local groundIdleTime = 0
local jumpedSinceGrounded = false
-- After a slide ends with crouch still held, crouch must be released before sliding again.
local slideNeedsRelease = false
local lastVerticalSpeed = 0

local AIR_STEP = 1 / 60
local airStepRemainder = 0

local WALL_PROBE_DIRECTIONS: { Vector3 } = {}
for i = 0, 7 do
	local angle = i * math.pi / 4
	table.insert(WALL_PROBE_DIRECTIONS, Vector3.new(math.cos(angle), 0, math.sin(angle)))
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function isBindDown(bind: { Keyboard: { Enum.KeyCode }, Gamepad: { Enum.KeyCode } }): boolean
	for _, key in bind.Keyboard do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	for _, button in bind.Gamepad do
		if UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, button) then
			return true
		end
	end
	return false
end

local function isBindKey(bind: { Keyboard: { Enum.KeyCode }, Gamepad: { Enum.KeyCode } }, key: Enum.KeyCode): boolean
	return table.find(bind.Keyboard, key) ~= nil or table.find(bind.Gamepad, key) ~= nil
end

local function getWishDirection(): Vector3
	local move: Vector3 = if controls then controls:GetMoveVector() else Vector3.zero
	state.StrafeInput = if move.X > 0.1 then 1 elseif move.X < -0.1 then -1 else 0
	if move.Magnitude < 0.01 then
		return Vector3.zero
	end

	local cameraCFrame = (workspace.CurrentCamera :: Camera).CFrame
	local forward = flat(cameraCFrame.LookVector)
	if forward.Magnitude < 1e-3 then
		-- Looking straight up or down: the up vector points where the player is facing.
		forward = flat(cameraCFrame.UpVector)
	end
	forward = forward.Unit
	local right = forward:Cross(Vector3.yAxis)

	local wish = right * move.X + forward * -move.Z
	return if wish.Magnitude > 1 then wish.Unit else wish
end

local function probeGround(hum: Humanoid, rootPart: BasePart): RaycastResult?
	local legLength = if hum.RigType == Enum.HumanoidRigType.R15
		then hum.HipHeight + rootPart.Size.Y / 2
		else rootPart.Size.Y / 2 + 2
	local radius = Config.GroundProbeRadius
	local distance = legLength + Config.GroundProbeExtra - radius
	return workspace:Spherecast(rootPart.Position, radius, Vector3.new(0, -distance, 0), raycastParams)
end

local function probeWall(rootPart: BasePart): RaycastResult?
	local reach = rootPart.Size.X / 2 + Config.WallKick.DetectDistance
	local best: RaycastResult? = nil
	for _, direction in WALL_PROBE_DIRECTIONS do
		local hit = workspace:Raycast(rootPart.Position, direction * reach, raycastParams)
		if hit and math.abs(hit.Normal.Y) <= Config.WallKick.MaxWallSteepness then
			if not best or hit.Distance < best.Distance then
				best = hit
			end
		end
	end
	return best
end

local function updateTier()
	if state.OverflowRemaining > 0 then
		state.Tier = #Config.Flow.Tiers
		return
	end
	local tier = 1
	-- The last tier is Overflow, which is only entered through AddFlow.
	for i = 1, #Config.Flow.Tiers - 1 do
		if state.Flow >= Config.Flow.Tiers[i].Min then
			tier = i
		end
	end
	state.Tier = tier
end

function MovementController.AddFlow(amount: number)
	if state.OverflowRemaining > 0 then
		return
	end
	state.Flow = math.clamp(state.Flow + amount, 0, Config.Flow.Max)
	if state.Flow >= Config.Flow.Max then
		state.OverflowRemaining = Config.Flow.OverflowDuration
	end
	updateTier()
end

-- Called by combat code (phase 2) when this player takes damage.
function MovementController.OnDamaged()
	state.OverflowRemaining = 0
	state.Flow = math.max(0, state.Flow - Config.Flow.HitPenalty)
	updateTier()
end

-- Called by combat code (phase 2) when this player gets a kill.
function MovementController.OnKill()
	if not state.Grounded then
		MovementController.AddFlow(Config.Flow.AirKill)
	end
end

local function approach(current: Vector3, target: Vector3, maxDelta: number): Vector3
	local diff = target - current
	local distance = diff.Magnitude
	if distance <= maxDelta or distance < 1e-4 then
		return target
	end
	return current + diff / distance * maxDelta
end

local function groundMove(vel: Vector3, wish: Vector3, dt: number): Vector3
	local maxSpeed = if state.Crouching then Config.CrouchSpeed else Config.WalkSpeed
	local target = wish * maxSpeed
	local speedingUp = wish.Magnitude > 0 and target.Magnitude >= vel.Magnitude - 0.01
	local rate = if speedingUp
		then Config.WalkSpeed / Config.GroundAccelTime
		else Config.WalkSpeed / Config.GroundStopTime
	return approach(vel, target, rate * dt)
end

local function airAccelerate(vel: Vector3, wish: Vector3, dt: number): Vector3
	-- Only the part of the speed along the wish direction is capped, so turning
	-- while strafing keeps adding speed (the classic Source bhop trick).
	local wishDir = wish.Unit
	local currentAlongWish = vel:Dot(wishDir)
	local addSpeed = Config.AirWishSpeedCap * wish.Magnitude - currentAlongWish
	if addSpeed <= 0 then
		return vel
	end
	local accel = math.min(Config.AirAcceleration * Config.WalkSpeed * dt, addSpeed)
	return vel + wishDir * accel
end

local function airMove(vel: Vector3, wish: Vector3, dt: number): Vector3
	if wish.Magnitude < 1e-3 then
		airStepRemainder = 0
		return vel
	end
	-- Strafe gain depends on how often it runs, so it runs at a fixed rate.
	-- Otherwise a 240 FPS player would gain speed 4x faster than a 60 FPS one.
	airStepRemainder += dt
	while airStepRemainder >= AIR_STEP do
		airStepRemainder -= AIR_STEP
		vel = airAccelerate(vel, wish, AIR_STEP)
	end
	return vel
end

local function startSlide(vel: Vector3, now: number): Vector3
	state.Sliding = true
	state.Crouching = false
	if now - lastSlideBoostAt >= Config.Slide.BoostCooldown and vel.Magnitude > 1e-3 then
		lastSlideBoostAt = now
		vel += vel.Unit * Config.Slide.Boost
	end
	return vel
end

local function slideMove(vel: Vector3, wish: Vector3, ground: RaycastResult, dt: number): Vector3
	local speed = vel.Magnitude
	if speed < 1e-3 then
		return vel
	end
	local dir = vel / speed

	if wish.Magnitude > 0.1 then
		local wishDir = wish.Unit
		local angle = math.acos(math.clamp(dir:Dot(wishDir), -1, 1))
		if angle > 1e-3 then
			local step = math.min(angle, Config.Slide.SteerRate * dt)
			local sign = if dir:Cross(wishDir).Y > 0 then 1 else -1
			dir = CFrame.Angles(0, step * sign, 0):VectorToWorldSpace(dir)
		end
	end

	speed = math.max(0, speed - Config.Slide.Friction * dt)

	-- Gravity pulls along the slope. Its flat part speeds you up downhill and slows you uphill.
	local normal = ground.Normal
	local down = -Vector3.yAxis
	local downhill = flat(down - normal * down:Dot(normal))
	local slopeAccel = downhill * Config.Gravity * Config.Slide.SlopeGain
	if (dir * speed):Dot(downhill) < 0 then
		slopeAccel *= Config.Slide.UphillMultiplier
	end

	return dir * speed + slopeAccel * dt
end

local function leaveGround(hum: Humanoid, now: number)
	-- Freefall rather than Jumping: the Humanoid's jump would apply its own (zero)
	-- JumpPower on top of the speed set here.
	hum:ChangeState(Enum.HumanoidStateType.Freefall)
	lastJumpAt = now
	jumpedSinceGrounded = true
	jumpPressedAt = -math.huge
	state.Grounded = false
	state.Sliding = false
	state.Crouching = false
end

local function step(dt: number)
	local hum = humanoid
	local rootPart = root
	if not hum or not rootPart or hum.Health <= 0 then
		return
	end

	local now = os.clock()
	local wish = getWishDirection()
	local crouchHeld = isBindDown(Config.Keybinds.Crouch)
	if not crouchHeld then
		slideNeedsRelease = false
	end
	if Config.AutoHopWhenHeld and isBindDown(Config.Keybinds.Jump) then
		jumpPressedAt = now
	end

	local vel = flat(rootPart.AssemblyLinearVelocity)
	local verticalSpeed = rootPart.AssemblyLinearVelocity.Y

	local ground = probeGround(hum, rootPart)
	local wasGrounded = state.Grounded
	state.Grounded = ground ~= nil and now - lastJumpAt > Config.JumpGroundIgnoreTime

	if state.Grounded and not wasGrounded then
		landedAt = now
		groundIdleTime = 0
		state.WallKicksUsed = 0
		state.LandCount += 1
		state.LastLandSpeed = math.max(0, -lastVerticalSpeed)
		slideNeedsRelease = false
		if crouchHeld and vel.Magnitude >= Config.Slide.MinSpeed then
			vel = startSlide(vel, now)
		end
	end
	if state.Grounded then
		lastGroundedAt = now
		jumpedSinceGrounded = false
		airStepRemainder = 0
	else
		state.Sliding = false
		state.Crouching = false
	end

	local wantsJump = now - jumpPressedAt <= Config.JumpBuffer
	local canCoyoteJump = not state.Grounded and not jumpedSinceGrounded and now - lastGroundedAt <= Config.CoyoteTime
	local jumped = false

	if wantsJump and (state.Grounded or canCoyoteJump) then
		if state.Sliding then
			-- Slide-jump keeps all of the slide's speed.
			MovementController.AddFlow(Config.Flow.SlideJump)
		elseif
			state.Grounded
			and now - landedAt <= Config.PerfectHopWindow
			and vel.Magnitude >= Config.PerfectHopMinSpeed
		then
			vel *= 1 + Config.PerfectHopBonus
			MovementController.AddFlow(Config.Flow.PerfectHop)
		end
		leaveGround(hum, now)
		verticalSpeed = Config.JumpVelocity
		jumped = true
	elseif
		wantsJump
		and not state.Grounded
		and state.WallKicksUsed < Config.WallKick.MaxKicks
		and now - lastJumpAt > Config.WallKick.MinAirTime
	then
		local wall = probeWall(rootPart)
		if wall then
			local normal = flat(wall.Normal).Unit
			local intoWall = vel:Dot(normal)
			if intoWall < 0 then
				vel -= normal * intoWall
			end
			vel += normal * Config.WallKick.Push
			state.WallKicksUsed += 1
			MovementController.AddFlow(Config.Flow.WallKick)
			leaveGround(hum, now)
			verticalSpeed = Config.WallKick.UpVelocity
			jumped = true
		end
	end

	if not jumped and state.Grounded and ground then
		if not state.Sliding and crouchHeld and not slideNeedsRelease and vel.Magnitude >= Config.Slide.MinSpeed then
			vel = startSlide(vel, now)
		end

		if state.Sliding then
			vel = slideMove(vel, wish, ground, dt)
			local onSlingshot = CollectionService:HasTag(ground.Instance, Config.Slingshot.Tag)
			if onSlingshot and now - lastSlingshotAt >= Config.Slingshot.Cooldown then
				lastSlingshotAt = now
				verticalSpeed = Config.Slingshot.BaseLaunch + vel.Magnitude * Config.Slingshot.SpeedToHeight
				vel *= Config.Slingshot.HorizontalKeep
				leaveGround(hum, now)
			elseif not crouchHeld or vel.Magnitude < Config.Slide.EndSpeed then
				state.Sliding = false
				slideNeedsRelease = crouchHeld
			end
		end

		if state.Grounded and not state.Sliding then
			state.Crouching = crouchHeld
			-- Landing grace: no friction yet, so a perfect hop keeps every bit of speed.
			local inHopWindow = now - landedAt <= Config.PerfectHopWindow and vel.Magnitude > Config.WalkSpeed
			if not inHopWindow then
				vel = groundMove(vel, wish, dt)
			end
		end
	elseif not jumped then
		vel = airMove(vel, wish, dt)
	end

	-- Flow drains when you stand around on the ground.
	if state.OverflowRemaining > 0 then
		state.OverflowRemaining -= dt
		if state.OverflowRemaining <= 0 then
			state.OverflowRemaining = 0
			state.Flow = Config.Flow.OverflowExitValue
		end
	elseif state.Grounded and not state.Sliding then
		groundIdleTime += dt
		if groundIdleTime > Config.Flow.DrainDelay then
			state.Flow = math.max(0, state.Flow - Config.Flow.DrainRate * dt)
		end
	else
		groundIdleTime = 0
	end
	updateTier()

	local cap = Config.Flow.Tiers[state.Tier].SpeedCap
	if vel.Magnitude > cap then
		vel = vel.Unit * cap
	end

	rootPart.AssemblyLinearVelocity = Vector3.new(vel.X, verticalSpeed, vel.Z)
	-- Keep the Humanoid's own movement in agreement with ours so it never fights it.
	local speed = vel.Magnitude
	hum.WalkSpeed = speed
	hum:Move(if speed > 0.05 then vel / speed else Vector3.zero, false)

	state.Speed = speed
	lastVerticalSpeed = verticalSpeed
end

local function onCharacterAdded(character: Model)
	local hum = character:WaitForChild("Humanoid") :: Humanoid
	local rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart

	-- Jumps are done by this module, so the Humanoid's own jump must do nothing.
	hum.UseJumpPower = true
	hum.JumpPower = 0

	raycastParams.FilterDescendantsInstances = { character }
	humanoid = hum
	root = rootPart

	state.Flow = 0
	state.OverflowRemaining = 0
	state.Sliding = false
	state.Crouching = false
	state.Grounded = false
	state.WallKicksUsed = 0
	jumpPressedAt = -math.huge
	lastJumpAt = -math.huge
	slideNeedsRelease = false
	updateTier()
end

function MovementController.Start()
	local playerModule =
		require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript) :: any
	controls = playerModule:GetControls()

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if isBindKey(Config.Keybinds.Jump, input.KeyCode) then
			jumpPressedAt = os.clock()
		end
	end)

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end

	-- PreSimulation runs after the default control script, right before physics.
	RunService.PreSimulation:Connect(step)
end

return MovementController
