--!strict
-- The client side of the sniper: scoping, quickscopes, scope sway and Shift to
-- steady, firing, bolt and reload, recoil and viewmodel motion. Shots raycast here
-- for instant feedback, then the server re-checks them before any damage happens.
-- Also owns which weapon is equipped; the knife itself lives in KnifeController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Hitboxes = require(ReplicatedStorage.Shared.Combat.Hitboxes)
local KillTags = require(ReplicatedStorage.Shared.Combat.KillTags)
local MovementConfig = require(ReplicatedStorage.Shared.Config.MovementConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
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
local STEADY_KEYS = { Enum.KeyCode.LeftShift }
local STEADY_BUTTONS = { Enum.KeyCode.ButtonL3 }
local SNIPER_KEYS = { Enum.KeyCode.One }
local KNIFE_KEYS = { Enum.KeyCode.Three }
local TOGGLE_KEYS = { Enum.KeyCode.Q, Enum.KeyCode.ButtonY }

local KICK_BACK = 0.35 -- studs
local KICK_PITCH = math.rad(6)
local BOLT_DIP = math.rad(8)
local RELOAD_DIP = math.rad(35)
local SWAY_SCALE = 0.02 -- radians of gun sway per radian/s of camera turn
local SWAY_LIMIT = math.rad(5)
local BOB_AMOUNT = 0.035
local BOB_SPEED = 0.55 -- bob cycles per stud travelled
local SCOPING_ZOOM = 1.12 -- slight zoom while the scope is still coming up

export type Slot = "Sniper" | "Knife"

export type ShotInfo = {
	Origin: Vector3,
	TracerStart: Vector3,
	EndPoint: Vector3,
	Normal: Vector3?,
	Material: Enum.Material?,
	HitCharacter: boolean,
}

local WeaponController = {}

-- Read by the HUD and camera every frame.
WeaponController.State = {
	WeaponId = WeaponConfig.DefaultWeapon,
	Ammo = WeaponConfig.Weapons[WeaponConfig.DefaultWeapon].MagSize,
	Reloading = false,
	ReloadProgress = 0,
	AdsAlpha = 0,
	Scoped = false,
	Spread = WeaponConfig.HipfireSpread,
	Alive = false,
	Equipped = "Sniper" :: Slot,
	SwitchProgress = 1, -- 0..1 through the current weapon switch; 1 = done
	AimSway = Vector2.zero, -- radians (yaw, pitch) the scoped view drifts; shots follow it
	Steadying = false,
	SteadyRemaining = WeaponConfig.Sway.SteadyDuration,
	HeadshotStreak = 0,
}

WeaponController.Fired = Signal.new() -- (info: ShotInfo)
WeaponController.Hit = Signal.new() -- (zone: Hitboxes.Zone, killed: boolean) predicted on hit, again on a confirmed kill
WeaponController.Killed = Signal.new() -- (result: { Zone, Distance, Tags }) server-confirmed
WeaponController.Damaged = Signal.new() -- (info: table) this player took damage
WeaponController.ReloadStarted = Signal.new()
WeaponController.ReloadFinished = Signal.new()
WeaponController.ScopedIn = Signal.new()
WeaponController.BoltFinished = Signal.new()
WeaponController.EquipChanged = Signal.new() -- (slot: Slot)

local state = WeaponController.State
local Sway = WeaponConfig.Sway

local fireShot = Net.Event(Net.Names.FireShot)
local reloadEvent = Net.Event(Net.Names.Reload)
local equipEvent = Net.Event(Net.Names.Equip)
local shotResult = Net.Event(Net.Names.ShotResult)
local tookDamage = Net.Event(Net.Names.TookDamage)

local random = Random.new()
local viewmodel = Viewmodel.new("Sniper")
local character: Model? = nil

local boltStartedAt = -math.huge
local boltEndsAt = -math.huge
local reloadStartedAt = -math.huge
local reloadEndsAt = -math.huge
local scopedAt = -math.huge -- when the scope last finished coming up
local exhaustedUntil = -math.huge -- after holding breath too long, steadying is locked out
local switchStartedAt = -math.huge
local previousSlot: Slot = "Sniper"

local kickBack = Spring.new(0, 220, 0.75)
local kickPitch = Spring.new(0, 220, 0.75)
local swayYaw = Spring.new(0, 120, 0.85)
local swayPitch = Spring.new(0, 120, 0.85)
local lastLook: Vector3? = nil
local bobPhase = 0
local swayClock = 0

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

local function isAnyDown(keys: { Enum.KeyCode }, buttons: { Enum.KeyCode }): boolean
	for _, key in keys do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	for _, button in buttons do
		if UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, button) then
			return true
		end
	end
	return false
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
	local ignore: { Instance } = { workspace.CurrentCamera }
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

local function sniperReady(): boolean
	return state.Alive and state.Equipped == "Sniper" and state.SwitchProgress >= 1
end

-- How far a weapon's viewmodel is lowered: the old one drops out during the first
-- half of a switch and the new one comes up during the second half.
function WeaponController.GetLower(slot: Slot): number
	local progress = state.SwitchProgress
	if progress >= 1 then
		return if slot == state.Equipped then 0 else 1
	end
	if slot == state.Equipped then
		return if progress < 0.5 then 1 else 1 - (progress - 0.5) * 2
	elseif slot == previousSlot then
		return if progress < 0.5 then progress * 2 else 1
	end
	return 1
end

function WeaponController.Equip(slot: Slot)
	if slot == state.Equipped or not state.Alive then
		return
	end
	previousSlot = state.Equipped
	state.Equipped = slot
	switchStartedAt = os.clock()
	state.SwitchProgress = 0
	state.AdsAlpha = 0
	equipEvent:FireServer(slot)
	MovementController.SetKnifeEquipped(slot == "Knife")
	WeaponController.EquipChanged:Fire(slot)
end

local function isAlive(): boolean
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function startReload()
	local now = os.clock()
	if not sniperReady() or state.Reloading or state.Ammo >= weapon().MagSize or now < boltEndsAt then
		return
	end
	state.Reloading = true
	reloadStartedAt = now
	reloadEndsAt = now + weapon().ReloadTime
	reloadEvent:FireServer()
	WeaponController.ReloadStarted:Fire()
end

local function fire()
	local now = os.clock()
	if not sniperReady() or state.Reloading or now < boltEndsAt then
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

	-- Sent along so the server can tag the kill (noscope, quickscope, airshot...).
	local movement = MovementController.State
	local context: KillTags.ShotContext = {
		AdsAlpha = state.AdsAlpha,
		ScopedFor = if state.Scoped then now - scopedAt else 0,
		Airborne = not movement.Grounded,
		Overflow = movement.OverflowRemaining > 0,
	}
	fireShot:FireServer(origin, direction, workspace:GetServerTimeNow(), victim, partName, context)

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

	WeaponController.Fired:Fire({
		Origin = origin,
		TracerStart = tracerStart,
		EndPoint = endPoint,
		Normal = if hit then hit.Normal else nil,
		Material = if hit then hit.Material else nil,
		HitCharacter = victim ~= nil,
	} :: ShotInfo)

	if victim and partName then
		-- Shown right away; a kill is only shown once the server confirms it.
		local zone = Hitboxes.GetZone(partName) or "Body"
		state.HeadshotStreak = if zone == "Head" then state.HeadshotStreak + 1 else 0
		WeaponController.Hit:Fire(zone, false)
	else
		state.HeadshotStreak = 0
	end
end

local function isScopeHeld(): boolean
	return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, SCOPE_BUTTON)
end

local function updateAds(dt: number, now: number)
	local wasScoped = state.Scoped
	local canScope = sniperReady() and not state.Reloading and now >= boltEndsAt
	if canScope and isScopeHeld() then
		state.AdsAlpha = math.min(1, state.AdsAlpha + dt / weapon().AdsTime)
	else
		state.AdsAlpha = math.max(0, state.AdsAlpha - dt / WeaponConfig.UnscopeTime)
	end
	state.Scoped = state.AdsAlpha >= 1
	if state.Scoped and not wasScoped then
		scopedAt = now
		WeaponController.ScopedIn:Fire()
	end
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

-- Scoped aim drifts slowly. It's strongest right after scoping in, grows while
-- moving, and holding Shift steadies it for a couple of seconds.
local function updateAimSway(dt: number, now: number)
	local holding = state.Scoped and now >= exhaustedUntil and isAnyDown(STEADY_KEYS, STEADY_BUTTONS)
	if holding then
		state.SteadyRemaining -= dt
		if state.SteadyRemaining <= 0 then
			state.SteadyRemaining = 0
			exhaustedUntil = now + Sway.ExhaustedTime
			holding = false
		end
	else
		state.SteadyRemaining = math.min(Sway.SteadyDuration, state.SteadyRemaining + dt * Sway.SteadyRegenRate)
	end
	state.Steadying = holding

	if not state.Scoped then
		state.AimSway = Vector2.zero
		return
	end

	local settle = math.clamp((now - scopedAt) / Sway.SettleTime, 0, 1)
	local amplitude = Sway.Amplitude * (1 + (Sway.ScopeInMultiplier - 1) * (1 - settle))
	amplitude *= 1 + MovementController.State.Speed / MovementConfig.MaxSpeedCap * Sway.MovingMultiplier
	if holding then
		amplitude *= Sway.SteadyMultiplier
	elseif now < exhaustedUntil then
		amplitude *= Sway.ExhaustedMultiplier
	end

	swayClock += dt
	local radians = math.rad(amplitude)
	-- Two slow waves at unrelated speeds make a figure-eight that never quite repeats.
	state.AimSway = Vector2.new(math.sin(swayClock * 1.1) * radians, math.sin(swayClock * 1.7 + 0.6) * radians * 0.7)
end

local function updateTimers(now: number)
	if state.Reloading then
		state.ReloadProgress = math.clamp((now - reloadStartedAt) / weapon().ReloadTime, 0, 1)
		if now >= reloadEndsAt then
			state.Reloading = false
			state.Ammo = weapon().MagSize
			WeaponController.ReloadFinished:Fire()
		end
	else
		state.ReloadProgress = 0
	end
	if boltEndsAt > 0 and now >= boltEndsAt and boltStartedAt > 0 then
		boltStartedAt = -math.huge
		WeaponController.BoltFinished:Fire()
	end
	state.SwitchProgress = math.clamp((now - switchStartedAt) / WeaponConfig.Knife.SwitchTime, 0, 1)
	-- Krunker-style: an empty mag reloads by itself once the bolt is done.
	if state.Ammo <= 0 and not state.Reloading and now >= boltEndsAt then
		startReload()
	end
end

local function updateViewmodel(dt: number, now: number)
	local camera = workspace.CurrentCamera

	-- Gun sway follows how fast the camera turns, not the raw mouse, so it works the
	-- same for mouse, controller and touch.
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

	local bolting = now < boltEndsAt
	local boltProgress = if bolting
		then math.clamp((now - (boltEndsAt - weapon().BoltTime)) / weapon().BoltTime, 0, 1)
		else 1
	local boltCurve = if bolting then math.sin(boltProgress * math.pi) else 0
	local reloadCurve = if state.Reloading then math.sin(state.ReloadProgress * math.pi) else 0

	local lower = WeaponController.GetLower("Sniper")
	viewmodel:SetVisible(state.Alive and not state.Scoped and lower < 1)
	viewmodel:Update(camera, {
		AdsAlpha = state.AdsAlpha,
		Lower = lower,
		KickBack = kickBack:Update(dt),
		KickPitch = kickPitch:Update(dt),
		Dip = boltCurve * BOLT_DIP + reloadCurve * RELOAD_DIP,
		BoltPull = boltCurve,
		Sway = Vector2.new(swayYaw:Update(dt), swayPitch:Update(dt)),
		Bob = bob,
	})
end

-- Other players see a gun in this character's hands; this player only sees the
-- first-person one.
local function hideOwnWorldWeapon()
	local worldWeapon = character and character:FindFirstChild("WorldWeapon")
	if not worldWeapon then
		return
	end
	for _, part in worldWeapon:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = 1
		end
	end
end

local function onCharacterAdded(newCharacter: Model)
	character = newCharacter
	state.Ammo = weapon().MagSize
	state.Reloading = false
	state.AdsAlpha = 0
	state.Scoped = false
	state.HeadshotStreak = 0
	state.SteadyRemaining = Sway.SteadyDuration
	-- Every life starts with the sniper out.
	state.Equipped = "Sniper"
	state.SwitchProgress = 1
	previousSlot = "Sniper"
	MovementController.SetKnifeEquipped(false)
	boltStartedAt = -math.huge
	boltEndsAt = -math.huge
	reloadEndsAt = -math.huge
	exhaustedUntil = -math.huge

	viewmodel:SetSkinColor(newCharacter)
end

function WeaponController.Start()
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	-- Skin color is only final once the avatar has loaded.
	player.CharacterAppearanceLoaded:Connect(function(loaded)
		viewmodel:SetSkinColor(loaded)
	end)

	UserInputService.MouseIconEnabled = false

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		local key = input.KeyCode
		if table.find(FIRE_INPUTS, input.UserInputType) or table.find(FIRE_BUTTONS, key) then
			fire()
		elseif table.find(RELOAD_KEYS, key) then
			startReload()
		elseif table.find(SNIPER_KEYS, key) then
			WeaponController.Equip("Sniper")
		elseif table.find(KNIFE_KEYS, key) then
			WeaponController.Equip("Knife")
		elseif table.find(TOGGLE_KEYS, key) then
			WeaponController.Equip(if state.Equipped == "Sniper" then "Knife" else "Sniper")
		end
	end)

	shotResult.OnClientEvent:Connect(function(result: any)
		if typeof(result) ~= "table" or not result.Killed then
			return
		end
		if typeof(result.Tags) ~= "table" then
			result.Tags = {}
		end
		WeaponController.Hit:Fire(result.Zone, true)
		WeaponController.Killed:Fire(result)
		MovementController.OnKill()
	end)

	tookDamage.OnClientEvent:Connect(function(info: any)
		WeaponController.Damaged:Fire(info)
		MovementController.OnDamaged()
	end)

	-- Runs after the camera controller so the gun follows the final camera position.
	RunService:BindToRenderStep("SniperWeapon", Enum.RenderPriority.Camera.Value + 2, function(dt: number)
		local now = os.clock()
		state.Alive = isAlive()
		hideOwnWorldWeapon()
		updateTimers(now)
		updateAds(dt, now)
		updateAimSway(dt, now)
		updateViewmodel(dt, now)
	end)
end

return WeaponController
