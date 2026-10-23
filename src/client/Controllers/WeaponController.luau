--!strict
-- The client side of the snipers: scoping, quickscopes, firing (bolt-action,
-- two-shot or semi-auto), reload, recoil and viewmodel motion. Shots are cast here
-- for instant feedback, then the server re-checks them before any damage happens.
-- Also owns which weapon is equipped (the knife itself lives in KnifeController)
-- and the inspect animation (F).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Ballistics = require(ReplicatedStorage.Shared.Combat.Ballistics)
local Hitboxes = require(ReplicatedStorage.Shared.Combat.Hitboxes)
local KillTags = require(ReplicatedStorage.Shared.Combat.KillTags)
local MovementConfig = require(ReplicatedStorage.Shared.Config.MovementConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Spring = require(ReplicatedStorage.Shared.Util.Spring)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local WeaponStats = require(ReplicatedStorage.Shared.Combat.WeaponStats)
local MovementController = require(script.Parent.MovementController)
local ProfileController = require(script.Parent.ProfileController)
local SettingsController = require(script.Parent.SettingsController)
local Inspect = require(script.Parent.Parent.Weapon.Inspect)
local Tracers = require(script.Parent.Parent.Weapon.Tracers)
local Viewmodel = require(script.Parent.Parent.Weapon.Viewmodel)

local player = Players.LocalPlayer

local FIRE_INPUTS = { Enum.UserInputType.MouseButton1 }
local FIRE_BUTTONS = { Enum.KeyCode.ButtonR2 }
local SCOPE_INPUTS = { Enum.UserInputType.MouseButton2 }
local SCOPE_BUTTONS = { Enum.KeyCode.ButtonL2 }
local RELOAD_KEYS = { Enum.KeyCode.R, Enum.KeyCode.ButtonX }
local SNIPER_KEYS = { Enum.KeyCode.One }
local KNIFE_KEYS = { Enum.KeyCode.Three }
local TOGGLE_KEYS = { Enum.KeyCode.Q, Enum.KeyCode.ButtonY }
local INSPECT_KEYS = { Enum.KeyCode.F, Enum.KeyCode.DPadUp }

local KICK_BACK = 0.35 -- studs, at Kick = 1
local KICK_PITCH = math.rad(6)
local BOLT_DIP = math.rad(8)
local RELOAD_DIP = math.rad(35)
local SWAY_SCALE = 0.02 -- radians the gun lags per radian/s of camera turn
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
	Kick: number,
}

local WeaponController = {}

-- Read by the HUD and camera every frame.
WeaponController.State = {
	Stats = ProfileController.GetLifeStats(),
	Ammo = ProfileController.GetLifeStats().MagSize,
	Reloading = false,
	ReloadProgress = 0,
	AdsAlpha = 0,
	Scoped = false,
	Spread = ProfileController.GetLifeStats().HipfireSpread,
	Alive = false,
	Equipped = "Sniper" :: Slot,
	SwitchProgress = 1, -- 0..1 through the current weapon switch; 1 = done
	HeadshotStreak = 0,
}

WeaponController.Fired = Signal.new() -- (info: ShotInfo)
WeaponController.Hit = Signal.new() -- (zone, killed) predicted on hit, again on a confirmed kill
WeaponController.Killed = Signal.new() -- (result: { Zone, Distance, Tags, Weapon }) server-confirmed
WeaponController.Damaged = Signal.new() -- (info: table) this player took damage
WeaponController.ReloadStarted = Signal.new()
WeaponController.ReloadFinished = Signal.new()
WeaponController.ScopedIn = Signal.new()
WeaponController.BoltStarted = Signal.new() -- the bolt is being worked after a cycle
WeaponController.EquipChanged = Signal.new() -- (slot: Slot)
WeaponController.InspectStarted = Signal.new() -- (slot: Slot)

local state = WeaponController.State

local fireShot = Net.Event(Net.Names.FireShot)
local reloadEvent = Net.Event(Net.Names.Reload)
local equipEvent = Net.Event(Net.Names.Equip)
local shotResult = Net.Event(Net.Names.ShotResult)
local tookDamage = Net.Event(Net.Names.TookDamage)

local random = Random.new()
local viewmodel = Viewmodel.new("Sniper")
local character: Model? = nil
local worldWeaponParts: { BasePart } = {}

local nextShotAt = -math.huge
local shotsInCycle = 0
local boltStartedAt = -math.huge
local boltEndsAt = -math.huge -- only set when a cycle ends (for the bolt animation)
local reloadStartedAt = -math.huge
local reloadEndsAt = -math.huge
local scopedAt = -math.huge -- when the scope last finished coming up
local switchStartedAt = -math.huge
local previousSlot: Slot = "Sniper"
local scopeToggled = false
local touchScope = false -- touch has no "hold", so its scope button always toggles
local inspectStartedAt = -math.huge
local inspectStyle: WeaponConfig.InspectStyle? = nil

local kickBack = Spring.new(0, 220, 0.75)
local kickPitch = Spring.new(0, 220, 0.75)
local swayYaw = Spring.new(0, 120, 0.85)
local swayPitch = Spring.new(0, 120, 0.85)
local lastLook: Vector3? = nil
local bobPhase = 0

local function stats(): WeaponStats.Stats
	return state.Stats
end

local function zoomedFov(fov: number, zoom: number): number
	return 2 * math.deg(math.atan(math.tan(math.rad(fov) / 2) / zoom))
end

-- The camera calls this after its own FOV smoothing so the scope zoom snaps in.
function WeaponController.ApplyZoom(fov: number): number
	if state.Scoped then
		return zoomedFov(fov, stats().Zoom)
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

local function cancelInspect()
	inspectStyle = nil
end

-- How far into an inspect of `slot` we are, or nil if not inspecting it.
function WeaponController.GetInspect(slot: Slot): (WeaponConfig.InspectStyle?, number)
	local style = inspectStyle
	if not style or state.Equipped ~= slot then
		return nil, 0
	end
	local elapsed = os.clock() - inspectStartedAt
	if elapsed >= style.Duration then
		inspectStyle = nil
		return nil, 0
	end
	return style, elapsed
end

-- Starts the inspect for whatever is in hand. Anything else you do cancels it.
function WeaponController.StartInspect()
	if not state.Alive or state.SwitchProgress < 1 or inspectStyle then
		return
	end
	if state.Equipped == "Sniper" then
		if state.Reloading or state.AdsAlpha > 0 or os.clock() < nextShotAt then
			return
		end
		inspectStyle = stats().Inspect
	else
		inspectStyle = WeaponConfig.Knife.Inspect
	end
	inspectStartedAt = os.clock()
	WeaponController.InspectStarted:Fire(state.Equipped)
end

-- Used by the knife: attacking cancels an inspect too.
WeaponController.CancelInspect = cancelInspect

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
	scopeToggled = false
	cancelInspect()
	equipEvent:FireServer(slot)
	MovementController.SetKnifeEquipped(slot == "Knife")
	WeaponController.EquipChanged:Fire(slot)
end

function WeaponController.Swap()
	WeaponController.Equip(if state.Equipped == "Sniper" then "Knife" else "Sniper")
end

local function isAlive(): boolean
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function startReload()
	local now = os.clock()
	if not sniperReady() or state.Reloading or state.Ammo >= stats().MagSize or now < nextShotAt then
		return
	end
	state.Reloading = true
	scopeToggled = false
	cancelInspect()
	reloadStartedAt = now
	reloadEndsAt = now + stats().ReloadTime
	reloadEvent:FireServer()
	WeaponController.ReloadStarted:Fire()
end

local function fire()
	local now = os.clock()
	if not sniperReady() or state.Reloading or now < nextShotAt then
		return
	end
	if state.Ammo <= 0 then
		startReload()
		return
	end
	cancelInspect()

	local weapon = stats()
	local camera = workspace.CurrentCamera
	local origin = camera.CFrame.Position
	local direction = spreadDirection(camera.CFrame, state.Spread)
	local ignore: { Instance } = { camera }
	if character then
		table.insert(ignore, character)
	end
	local hit = Ballistics.Cast(origin, direction, WeaponConfig.MaxRange, ignore, weapon.Penetration).Hit

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
	shotsInCycle += 1
	nextShotAt = now + WeaponStats.NextShotDelay(weapon, shotsInCycle)
	local cycleDone = shotsInCycle >= weapon.ShotsPerCycle
	if cycleDone then
		shotsInCycle = 0
		boltStartedAt = now
		boltEndsAt = nextShotAt
		if weapon.FireMode == "Bolt" then
			WeaponController.BoltStarted:Fire()
		end
	end

	local endPoint = if hit then hit.Position else origin + direction * WeaponConfig.MaxRange
	-- When scoped the gun is hidden, so the tracer starts just under the view instead.
	local tracerStart = if state.Scoped
		then origin + camera.CFrame.UpVector * -0.4 + direction * 2
		else viewmodel:GetMuzzlePosition()
	Tracers.Show(tracerStart, endPoint)

	kickBack:Impulse(KICK_BACK * 30 * weapon.Kick)
	kickPitch:Impulse(KICK_PITCH * 30 * weapon.Kick)

	if cycleDone and weapon.UnscopeOnFire then
		-- Krunker-style: drop out of the scope while the bolt is worked.
		state.AdsAlpha = math.min(state.AdsAlpha, 0.99)
	end

	WeaponController.Fired:Fire({
		Origin = origin,
		TracerStart = tracerStart,
		EndPoint = endPoint,
		Normal = if hit then hit.Normal else nil,
		Material = if hit then hit.Material else nil,
		HitCharacter = victim ~= nil,
		Kick = weapon.Kick,
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

local function scopeInputHeld(): boolean
	for _, input in SCOPE_INPUTS do
		if UserInputService:IsMouseButtonPressed(input) then
			return true
		end
	end
	for _, button in SCOPE_BUTTONS do
		if UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, button) then
			return true
		end
	end
	return false
end

-- The menu frees the mouse; right-clicking in it shouldn't scope.
local function menuOpen(): boolean
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local menu = playerGui and playerGui:FindFirstChild("Menu")
	return menu ~= nil and menu:IsA("ScreenGui") and menu.Enabled
end

local function wantsScope(): boolean
	if menuOpen() then
		return false
	end
	if SettingsController.Get("ToggleScope") or touchScope then
		return scopeToggled
	end
	return scopeInputHeld()
end

local function updateAds(dt: number, now: number)
	local weapon = stats()
	local wasScoped = state.Scoped
	-- While the bolt is being worked the scope stays down (unless the gun keeps its scope).
	local bolting = now < boltEndsAt and weapon.UnscopeOnFire
	local canScope = sniperReady() and not state.Reloading and not bolting
	if canScope and wantsScope() then
		cancelInspect()
		state.AdsAlpha = math.min(1, state.AdsAlpha + dt / weapon.AdsTime)
	else
		state.AdsAlpha = math.max(0, state.AdsAlpha - dt / WeaponConfig.UnscopeTime)
	end
	state.Scoped = state.AdsAlpha >= 1
	if state.Scoped and not wasScoped then
		scopedAt = now
		WeaponController.ScopedIn:Fire()
	end
	-- Spread shrinks as the scope comes up, so a well-timed quickscope is accurate.
	state.Spread = if state.Scoped then 0 else weapon.HipfireSpread * (1 - state.AdsAlpha)

	MovementController.SetScoped(state.AdsAlpha > 0)

	local sensitivity = SettingsController.Get("Sensitivity")
	if state.Scoped then
		-- Scaled by the zoom so the view moves the same distance on screen as unscoped.
		local baseFov = SettingsController.Get("FieldOfView")
		local ratio = math.tan(math.rad(zoomedFov(baseFov, weapon.Zoom)) / 2) / math.tan(math.rad(baseFov) / 2)
		UserInputService.MouseDeltaSensitivity = sensitivity * SettingsController.Get("ScopedSensitivity") * ratio
	else
		UserInputService.MouseDeltaSensitivity = sensitivity
	end
end

local function updateTimers(now: number)
	if state.Reloading then
		state.ReloadProgress = math.clamp((now - reloadStartedAt) / stats().ReloadTime, 0, 1)
		if now >= reloadEndsAt then
			state.Reloading = false
			state.Ammo = stats().MagSize
			shotsInCycle = 0
			WeaponController.ReloadFinished:Fire()
		end
	else
		state.ReloadProgress = 0
	end
	state.SwitchProgress = math.clamp((now - switchStartedAt) / WeaponConfig.Knife.SwitchTime, 0, 1)
	-- Krunker-style: an empty mag reloads by itself once the last shot is done.
	if state.Ammo <= 0 and not state.Reloading and now >= nextShotAt then
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
	if SettingsController.Get("ViewBob") and movement.Grounded and not movement.Sliding and not state.Scoped then
		bobPhase += movement.Speed * dt * BOB_SPEED * math.pi
		local strength = math.clamp(movement.Speed / MovementConfig.SprintSpeed, 0, 1) * BOB_AMOUNT
		bob = Vector2.new(math.sin(bobPhase) * strength, -math.abs(math.cos(bobPhase)) * strength)
	end

	local bolting = now < boltEndsAt and stats().FireMode == "Bolt"
	local boltProgress = if bolting
		then math.clamp((now - boltStartedAt) / math.max(boltEndsAt - boltStartedAt, 1e-3), 0, 1)
		else 1
	local boltCurve = if bolting then math.sin(boltProgress * math.pi) else 0
	local reloadCurve = if state.Reloading then math.sin(state.ReloadProgress * math.pi) else 0

	local detached, inspectBolt, glow = CFrame.identity, 0, 0
	local style, elapsed = WeaponController.GetInspect("Sniper")
	if style then
		detached, inspectBolt, glow = Inspect.Pose(style, elapsed)
	end
	viewmodel:SetGlow(glow)

	local lower = WeaponController.GetLower("Sniper")
	viewmodel:SetVisible(state.Alive and not state.Scoped and lower < 1)
	viewmodel:Update(camera, {
		AdsAlpha = state.AdsAlpha,
		Lower = lower,
		Detached = detached,
		KickBack = kickBack:Update(dt),
		KickPitch = kickPitch:Update(dt),
		Dip = boltCurve * BOLT_DIP + reloadCurve * RELOAD_DIP,
		BoltPull = math.max(boltCurve, inspectBolt),
		Sway = Vector2.new(swayYaw:Update(dt), swayPitch:Update(dt)),
		Bob = bob,
	})
end

-- Other players see a gun in this character's hands; this player only sees the
-- first-person one.
local function hideWorldWeaponPart(part: Instance)
	if part:IsA("BasePart") then
		part.LocalTransparencyModifier = 1
		table.insert(worldWeaponParts, part)
	end
end

local function hideOwnWorldWeapon()
	-- LocalTransparencyModifier can be reset by Roblox's camera, so reapply it.
	for _, part in worldWeaponParts do
		part.LocalTransparencyModifier = 1
	end
end

local function resetForLife()
	local weapon = stats()
	state.Ammo = weapon.MagSize
	state.Reloading = false
	state.AdsAlpha = 0
	state.Scoped = false
	state.HeadshotStreak = 0
	state.Spread = weapon.HipfireSpread
	nextShotAt = -math.huge
	shotsInCycle = 0
	boltEndsAt = -math.huge
	reloadEndsAt = -math.huge
	scopeToggled = false
	cancelInspect()
	viewmodel:SetPalette(weapon.Palette)
	MovementController.SetWeaponSpeedMultiplier(weapon.MoveSpeedMultiplier)
end

local function onCharacterAdded(newCharacter: Model)
	character = newCharacter
	-- Every life starts with the sniper out.
	state.Equipped = "Sniper"
	state.SwitchProgress = 1
	previousSlot = "Sniper"
	MovementController.SetKnifeEquipped(false)
	resetForLife()

	table.clear(worldWeaponParts)
	newCharacter.DescendantAdded:Connect(function(descendant)
		if descendant:FindFirstAncestor("WorldWeapon") then
			hideWorldWeaponPart(descendant)
		end
	end)
	local existing = newCharacter:FindFirstChild("WorldWeapon")
	if existing then
		for _, part in existing:GetDescendants() do
			hideWorldWeaponPart(part)
		end
	end

	viewmodel:SetSkinColor(newCharacter)
end

-- Touch buttons (TouchController) drive the same actions as keys.
function WeaponController.Fire()
	fire()
end

function WeaponController.Reload()
	startReload()
end

function WeaponController.ToggleScope()
	touchScope = true
	if sniperReady() then
		scopeToggled = not scopeToggled
	end
end

function WeaponController.Start()
	ProfileController.LoadoutChanged:Connect(function(newStats: WeaponStats.Stats)
		state.Stats = newStats
		resetForLife()
	end)

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
			touchScope = false
			fire()
		elseif table.find(SCOPE_INPUTS, input.UserInputType) or table.find(SCOPE_BUTTONS, key) then
			if sniperReady() then
				scopeToggled = not scopeToggled
			end
		elseif table.find(RELOAD_KEYS, key) then
			startReload()
		elseif table.find(SNIPER_KEYS, key) then
			WeaponController.Equip("Sniper")
		elseif table.find(KNIFE_KEYS, key) then
			WeaponController.Equip("Knife")
		elseif table.find(TOGGLE_KEYS, key) then
			WeaponController.Swap()
		elseif table.find(INSPECT_KEYS, key) then
			WeaponController.StartInspect()
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
		updateViewmodel(dt, now)
	end)
end

return WeaponController
