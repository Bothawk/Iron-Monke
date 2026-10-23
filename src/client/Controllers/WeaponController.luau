--!strict
-- The client side of the sniper: scoping, quickscopes, firing, bolt and reload,
-- recoil and viewmodel motion. Shots raycast here for instant feedback, then the
-- server re-checks them before any damage happens.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Hitboxes = require(ReplicatedStorage.Shared.Combat.Hitboxes)
local MovementConfig = require(ReplicatedStorage.Shared.Config.MovementConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Spring = require(ReplicatedStorage.Shared.Util.Spring)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local MovementController = require(script.Parent.MovementController)
local Tracers = require(script.Parent.Parent.Weapon.Tracers)
local Viewmodel = require(script.Parent.Parent.Weapon.Viewmodel)

local player = Players.LocalPlayer

local FIRE_INPUTS = { Enum.UserInputType.MouseButton1 }
local FIRE_BUTTONS = { Enum.KeyCode.ButtonR2 }
local RELOAD_KEYS = { Enum.KeyCode.R, Enum.KeyCode.ButtonX }
local SCOPE_BUTTON = Enum.KeyCode.ButtonL2

local KICK_BACK = 0.35 -- studs
local KICK_PITCH = math.rad(6)
local BOLT_DIP = math.rad(8)
local RELOAD_DIP = math.rad(35)
local SWAY_SCALE = 0.02 -- radians of sway per radian/s of camera turn
local SWAY_LIMIT = math.rad(5)
local BOB_AMOUNT = 0.035
local BOB_SPEED = 0.55 -- bob cycles per stud travelled
local SCOPING_ZOOM = 1.12 -- slight zoom while the scope is still coming up

export type HitEvent = { Zone: Hitboxes.Zone, Killed: boolean }
export type KillEvent = { Zone: Hitboxes.Zone, Distance: number }

local WeaponController = {}

-- Read by the HUD and camera. The Count fields increase by one per event, so
-- readers can tell when something new happened.
WeaponController.State = {
	WeaponId = WeaponConfig.DefaultWeapon,
	Ammo = WeaponConfig.Weapons[WeaponConfig.DefaultWeapon].MagSize,
	Reloading = false,
	ReloadProgress = 0,
	AdsAlpha = 0,
	Scoped = false,
	Spread = WeaponConfig.HipfireSpread,
	Alive = false,
	HitCount = 0,
	LastHit = { Zone = "Body", Killed = false } :: HitEvent,
	KillCount = 0,
	LastKill = { Zone = "Body", Distance = 0 } :: KillEvent,
	DamageCount = 0,
}

local state = WeaponController.State

local fireShot = Net.Event(Net.Names.FireShot)
local reloadEvent = Net.Event(Net.Names.Reload)
local shotResult = Net.Event(Net.Names.ShotResult)
local tookDamage = Net.Event(Net.Names.TookDamage)
local shotEffect = Net.Event(Net.Names.ShotEffect)

local random = Random.new()
local viewmodel = Viewmodel.new()
local character: Model? = nil

local boltStartedAt = -math.huge
local boltEndsAt = -math.huge
local reloadStartedAt = -math.huge
local reloadEndsAt = -math.huge

local kickBack = Spring.new(0, 220, 0.75)
local kickPitch = Spring.new(0, 220, 0.75)
local swayYaw = Spring.new(0, 120, 0.85)
local swayPitch = Spring.new(0, 120, 0.85)
local lastLook: Vector3? = nil
local bobPhase = 0

local function weapon(): WeaponConfig.Weapon
	return WeaponConfig.Weapons[state.WeaponId]
end

local function zoomedFov(fov: number, zoom: number): number
	return 2 * math.deg(math.atan(math.tan(math.rad(fov) / 2) / zoom))
end

-- The camera calls this after its own FOV smoothing so the scope zoom snaps in.
function WeaponController.ApplyZoom(fov: number): number
	if state.Scoped then
		return zoomedFov(fov, weapon().Zoom)
	elseif state.AdsAlpha > 0 then
		return zoomedFov(fov, 1 + (SCOPING_ZOOM - 1) * state.AdsAlpha)
	end
	return fov
end

local function spreadDirection(cframe: CFrame, spreadDegrees: number): Vector3
	if spreadDegrees <= 0 then
		return cframe.LookVector
	end
	-- sqrt keeps shots evenly spread across the cone instead of bunched in the middle.
	local angle = math.rad(spreadDegrees) * math.sqrt(random:NextNumber())
	local roll = random:NextNumber() * 2 * math.pi
	return (cframe * CFrame.Angles(0, 0, roll) * CFrame.Angles(angle, 0, 0)).LookVector
end

-- Raycasts the shot, passing through hats and other accessories.
local function castShot(origin: Vector3, direction: Vector3): RaycastResult?
	local camera = workspace.CurrentCamera
	local ignore: { Instance } = { camera }
	if character then
		table.insert(ignore, character)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	for _ = 1, 4 do
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(origin, direction * WeaponConfig.MaxRange, params)
		if not hit then
			return nil
		end
		local accessory = hit.Instance:FindFirstAncestorOfClass("Accessory")
		if not accessory then
			return hit
		end
		table.insert(ignore, accessory)
	end
	return nil
end

-- If the part belongs to a living character, returns that character and the
-- hitbox name to report to the server.
local function getVictim(part: BasePart): (Model?, string?)
	local model = part.Parent
	if not model or not model:IsA("Model") then
		return nil, nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	if Hitboxes.GetZone(part.Name) then
		return model, part.Name
	end
	-- The root part sits inside the torso; count it as a body hit.
	local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
	return model, if torso then torso.Name else nil
end

local function isAlive(): boolean
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function startReload()
	local now = os.clock()
	if not state.Alive or state.Reloading or state.Ammo >= weapon().MagSize or now < boltEndsAt then
		return
	end
	state.Reloading = true
	reloadStartedAt = now
	reloadEndsAt = now + weapon().ReloadTime
	reloadEvent:FireServer()
end

local function fire()
	local now = os.clock()
	if not state.Alive or state.Reloading or now < boltEndsAt then
		return
	end
	if state.Ammo <= 0 then
		startReload()
		return
	end

	local camera = workspace.CurrentCamera
	local origin = camera.CFrame.Position
	local direction = spreadDirection(camera.CFrame, state.Spread)
	local hit = castShot(origin, direction)

	local victim: Model?, partName: string? = nil, nil
	if hit then
		victim, partName = getVictim(hit.Instance)
	end
	fireShot:FireServer(origin, direction, workspace:GetServerTimeNow(), victim, partName)

	state.Ammo -= 1
	boltStartedAt = now
	boltEndsAt = now + weapon().BoltTime

	local endPoint = if hit then hit.Position else origin + direction * WeaponConfig.MaxRange
	-- When scoped the gun is hidden, so the tracer starts just under the view instead.
	local tracerStart = if state.Scoped
		then origin + camera.CFrame.UpVector * -0.4 + direction * 2
		else viewmodel:GetMuzzlePosition()
	Tracers.Show(tracerStart, endPoint)

	kickBack:Impulse(KICK_BACK * 30)
	kickPitch:Impulse(KICK_PITCH * 30)

	if victim and partName then
		-- Shown right away; a kill is only shown once the server confirms it.
		local zone = Hitboxes.GetZone(partName) or "Body"
		state.HitCount += 1
		state.LastHit = { Zone = zone, Killed = false }
	end
end

local function isScopeHeld(): boolean
	return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, SCOPE_BUTTON)
end

local function updateAds(dt: number, now: number)
	local canScope = state.Alive and not state.Reloading and now >= boltEndsAt
	if canScope and isScopeHeld() then
		state.AdsAlpha = math.min(1, state.AdsAlpha + dt / weapon().AdsTime)
	else
		state.AdsAlpha = math.max(0, state.AdsAlpha - dt / WeaponConfig.UnscopeTime)
	end
	state.Scoped = state.AdsAlpha >= 1
	-- Spread shrinks as the scope comes up, so a well-timed quickscope is accurate.
	state.Spread = if state.Scoped then 0 else WeaponConfig.HipfireSpread * (1 - state.AdsAlpha)

	MovementController.SetScoped(state.AdsAlpha > 0)

	if state.Scoped then
		local baseFov = MovementConfig.Camera.BaseFov
		local ratio = math.tan(math.rad(zoomedFov(baseFov, weapon().Zoom)) / 2) / math.tan(math.rad(baseFov) / 2)
		UserInputService.MouseDeltaSensitivity = WeaponConfig.ScopedSensitivity * ratio
	else
		UserInputService.MouseDeltaSensitivity = 1
	end
end

local function updateTimers(now: number)
	if state.Reloading then
		state.ReloadProgress = math.clamp((now - reloadStartedAt) / weapon().ReloadTime, 0, 1)
		if now >= reloadEndsAt then
			state.Reloading = false
			state.Ammo = weapon().MagSize
		end
	else
		state.ReloadProgress = 0
	end
	-- Krunker-style: an empty mag reloads by itself once the bolt is done.
	if state.Ammo <= 0 and not state.Reloading and now >= boltEndsAt then
		startReload()
	end
end

local function updateViewmodel(dt: number, now: number)
	local camera = workspace.CurrentCamera

	-- Sway follows how fast the camera is turning, not the raw mouse, so it works
	-- the same for mouse, controller and touch.
	local look = camera.CFrame.LookVector
	if lastLook and dt > 0 then
		local localLook = camera.CFrame:VectorToObjectSpace(lastLook)
		-- Positive when the camera turned right, so the gun lags back to the left.
		local yawRate = math.atan2(-localLook.X, -localLook.Z) / dt
		local pitchRate = math.asin(math.clamp(localLook.Y, -1, 1)) / dt
		swayYaw.Target = math.clamp(yawRate * SWAY_SCALE, -SWAY_LIMIT, SWAY_LIMIT)
		swayPitch.Target = math.clamp(pitchRate * SWAY_SCALE, -SWAY_LIMIT, SWAY_LIMIT)
	end
	lastLook = look

	local movement = MovementController.State
	local bob = Vector2.zero
	if movement.Grounded and not movement.Sliding and not state.Scoped then
		bobPhase += movement.Speed * dt * BOB_SPEED * math.pi
		local strength = math.clamp(movement.Speed / MovementConfig.SprintSpeed, 0, 1) * BOB_AMOUNT
		bob = Vector2.new(math.sin(bobPhase) * strength, -math.abs(math.cos(bobPhase)) * strength)
	end

	local boltProgress = math.clamp((now - boltStartedAt) / weapon().BoltTime, 0, 1)
	local boltCurve = if now < boltEndsAt then math.sin(boltProgress * math.pi) else 0
	local reloadCurve = if state.Reloading then math.sin(state.ReloadProgress * math.pi) else 0

	viewmodel:SetVisible(state.Alive and not state.Scoped)
	viewmodel:Update(camera, {
		AdsAlpha = state.AdsAlpha,
		KickBack = kickBack:Update(dt),
		KickPitch = kickPitch:Update(dt),
		Dip = boltCurve * BOLT_DIP + reloadCurve * RELOAD_DIP,
		BoltPull = boltCurve,
		Sway = Vector2.new(swayYaw:Update(dt), swayPitch:Update(dt)),
		Bob = bob,
	})
end

local function onCharacterAdded(newCharacter: Model)
	character = newCharacter
	state.Ammo = weapon().MagSize
	state.Reloading = false
	state.AdsAlpha = 0
	state.Scoped = false
	boltEndsAt = -math.huge
	reloadEndsAt = -math.huge
end

function WeaponController.Start()
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end

	UserInputService.MouseIconEnabled = false

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if table.find(FIRE_INPUTS, input.UserInputType) or table.find(FIRE_BUTTONS, input.KeyCode) then
			fire()
		elseif table.find(RELOAD_KEYS, input.KeyCode) then
			startReload()
		end
	end)

	shotResult.OnClientEvent:Connect(function(result: any)
		if typeof(result) ~= "table" or not result.Killed then
			return
		end
		state.HitCount += 1
		state.LastHit = { Zone = result.Zone, Killed = true }
		state.KillCount += 1
		state.LastKill = { Zone = result.Zone, Distance = result.Distance }
		MovementController.OnKill()
	end)

	tookDamage.OnClientEvent:Connect(function()
		state.DamageCount += 1
		MovementController.OnDamaged()
	end)

	shotEffect.OnClientEvent:Connect(function(origin: any, endPoint: any)
		if typeof(origin) == "Vector3" and typeof(endPoint) == "Vector3" then
			Tracers.Show(origin, endPoint)
		end
	end)

	-- Runs after the camera controller so the gun follows the final camera position.
	RunService:BindToRenderStep("SniperWeapon", Enum.RenderPriority.Camera.Value + 2, function(dt: number)
		local now = os.clock()
		state.Alive = isAlive()
		updateTimers(now)
		updateAds(dt, now)
		updateViewmodel(dt, now)
	end)
end

return WeaponController
