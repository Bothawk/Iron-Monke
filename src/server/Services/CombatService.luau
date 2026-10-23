--!strict
-- Server side of shooting. Clients raycast for instant feedback and report what
-- they hit; this service checks every claim (ammo, bolt and reload timers, where
-- the shot came from, lag-compensated hitboxes, walls in the way) and is the only
-- place damage is ever applied.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Hitboxes = require(ReplicatedStorage.Shared.Combat.Hitboxes)
local Net = require(ReplicatedStorage.Shared.Net)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local LagCompensation = require(script.Parent.LagCompensation)

local Validation = WeaponConfig.Validation

type WeaponState = {
	WeaponId: string,
	Ammo: number,
	LastShotAt: number, -- server clock when the last shot arrived
	LastShotTime: number, -- the client's timestamp on the last shot
	ReloadEndsAt: number?,
	ShotTimes: { number }, -- arrival times in the last second, for rate limiting
	ReloadTimes: { number },
}

local CombatService = {}

local weaponStates: { [Player]: WeaponState } = {}
local lastDamagedAt: { [Humanoid]: number } = {}

local fireShot = Net.Event(Net.Names.FireShot)
local reload = Net.Event(Net.Names.Reload)
local shotResult = Net.Event(Net.Names.ShotResult)
local tookDamage = Net.Event(Net.Names.TookDamage)
local shotEffect = Net.Event(Net.Names.ShotEffect)

local function newWeaponState(): WeaponState
	local weaponId = WeaponConfig.DefaultWeapon
	return {
		WeaponId = weaponId,
		Ammo = WeaponConfig.Weapons[weaponId].MagSize,
		LastShotAt = -math.huge,
		LastShotTime = -math.huge,
		ReloadEndsAt = nil,
		ShotTimes = {},
		ReloadTimes = {},
	}
end

-- Keeps only timestamps from the last second and says whether another fits under the limit.
local function underRateLimit(times: { number }, now: number, limit: number): boolean
	while times[1] and now - times[1] > 1 do
		table.remove(times, 1)
	end
	if #times >= limit then
		return false
	end
	table.insert(times, now)
	return true
end

local function isFiniteVector(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < math.huge
end

local function getAliveHumanoid(model: Instance?): Humanoid?
	if not model then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

-- Finishes a reload whose timer has run out.
local function settleReload(state: WeaponState, now: number)
	local endsAt = state.ReloadEndsAt
	if endsAt and now >= endsAt - Validation.TimingTolerance then
		state.Ammo = WeaponConfig.Weapons[state.WeaponId].MagSize
		state.ReloadEndsAt = nil
	end
end

local function damageFor(weaponId: string, zone: Hitboxes.Zone): number
	local weapon = WeaponConfig.Weapons[weaponId]
	if zone == "Head" then
		return weapon.HeadDamage
	elseif zone == "Body" then
		return weapon.BodyDamage
	end
	return weapon.BodyDamage * WeaponConfig.LimbMultiplier
end

-- Is anything solid (not a character) between the origin and the hit?
local function isBlocked(shooter: Model, origin: Vector3, direction: Vector3, distance: number): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = LagCompensation.GetTrackedModels()
	table.insert(ignore, shooter)
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(origin, direction * distance, params)
	-- A small margin so the edge of a box hugging a wall still counts.
	return hit ~= nil and hit.Distance < distance - 0.5
end

local function worldEndPoint(shooter: Model, origin: Vector3, direction: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { shooter }
	local hit = workspace:Raycast(origin, direction * WeaponConfig.MaxRange, params)
	return if hit then hit.Position else origin + direction * WeaponConfig.MaxRange
end

local function onFireShot(player: Player, origin: any, direction: any, shotTime: any, victim: any, partName: any)
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" or typeof(shotTime) ~= "number" then
		return
	end
	if not isFiniteVector(origin) or not isFiniteVector(direction) or shotTime ~= shotTime then
		return
	end
	if math.abs(direction.Magnitude - 1) > 0.05 then
		return
	end
	direction = direction.Unit

	local state = weaponStates[player]
	local character = player.Character
	local shooterHumanoid = getAliveHumanoid(character)
	local head = character and character:FindFirstChild("Head")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not state or not character or not shooterHumanoid or not head or not head:IsA("BasePart") then
		return
	end

	local serverClock = os.clock()
	if not underRateLimit(state.ShotTimes, serverClock, Validation.MaxShotsPerSecond) then
		return
	end

	local now = workspace:GetServerTimeNow()
	if shotTime > now + Validation.FutureTolerance then
		return
	end

	local weapon = WeaponConfig.Weapons[state.WeaponId]
	settleReload(state, serverClock)
	if state.ReloadEndsAt or state.Ammo <= 0 then
		return
	end
	-- Checked on both clocks: the client's timestamps must be a bolt apart, and so
	-- must the arrivals (with slack for network jitter).
	if shotTime - state.LastShotTime < weapon.BoltTime - Validation.TimingTolerance then
		return
	end
	if serverClock - state.LastShotAt < weapon.BoltTime - Validation.TimingTolerance * 2 then
		return
	end

	local speed = if root and root:IsA("BasePart") then root.AssemblyLinearVelocity.Magnitude else 0
	local allowedOffset = Validation.OriginTolerance + speed * Validation.OriginSpeedAllowance
	if (origin - head.Position).Magnitude > allowedOffset then
		return
	end

	state.Ammo -= 1
	state.LastShotAt = serverClock
	state.LastShotTime = shotTime

	local endPoint = worldEndPoint(character, origin, direction)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			shotEffect:FireClient(other, origin, endPoint)
		end
	end

	if typeof(victim) ~= "Instance" or not victim:IsA("Model") or victim == character then
		return
	end
	if not LagCompensation.IsTracked(victim) then
		return
	end
	local victimHumanoid = getAliveHumanoid(victim)
	if not victimHumanoid then
		return
	end
	local claimedPart = if typeof(partName) == "string" then partName else nil

	local Lag = WeaponConfig.LagCompensation
	local rewindTo = math.clamp(shotTime, now - Lag.MaxRewind, now)
	local hitPart, distance = LagCompensation.Raycast(
		victim,
		origin,
		direction,
		WeaponConfig.MaxRange,
		rewindTo - Lag.InterpolationWindow,
		rewindTo,
		claimedPart
	)
	if not hitPart or not distance then
		return
	end
	if isBlocked(character, origin, direction, distance) then
		return
	end

	local zone = Hitboxes.GetZone(hitPart)
	if not zone then
		return
	end
	local damage = damageFor(state.WeaponId, zone)
	victimHumanoid:TakeDamage(damage)
	lastDamagedAt[victimHumanoid] = serverClock
	local killed = victimHumanoid.Health <= 0

	shotResult:FireClient(player, {
		Zone = zone,
		Damage = damage,
		Killed = killed,
		Distance = distance,
	})

	local victimPlayer = Players:GetPlayerFromCharacter(victim)
	if victimPlayer then
		tookDamage:FireClient(victimPlayer, {
			Damage = damage,
			From = origin,
			Killed = killed,
		})
	end
end

local function onReload(player: Player)
	local state = weaponStates[player]
	if not state or not getAliveHumanoid(player.Character) then
		return
	end
	local serverClock = os.clock()
	if not underRateLimit(state.ReloadTimes, serverClock, Validation.MaxReloadsPerSecond) then
		return
	end
	settleReload(state, serverClock)
	local weapon = WeaponConfig.Weapons[state.WeaponId]
	if state.ReloadEndsAt or state.Ammo >= weapon.MagSize then
		return
	end
	state.ReloadEndsAt = serverClock + weapon.ReloadTime
end

local function onCharacterAdded(player: Player, character: Model)
	weaponStates[player] = newWeaponState()
	LagCompensation.Track(character)

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.MaxHealth = WeaponConfig.MaxHealth
	humanoid.Health = WeaponConfig.MaxHealth
	humanoid.Died:Connect(function()
		lastDamagedAt[humanoid] = nil
	end)
end

-- Lets other server code (test dummies) take part in combat.
function CombatService.RegisterCombatant(model: Model)
	LagCompensation.Track(model)
end

function CombatService.Start()
	Players.RespawnTime = WeaponConfig.RespawnTime

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		weaponStates[player] = nil
	end)

	fireShot.OnServerEvent:Connect(onFireShot)
	reload.OnServerEvent:Connect(onReload)

	-- Health only comes back after a few seconds without taking damage.
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, model in LagCompensation.GetTrackedModels() do
			local humanoid = getAliveHumanoid(model)
			if humanoid and humanoid.Health < humanoid.MaxHealth then
				local since = lastDamagedAt[humanoid]
				if not since or now - since >= WeaponConfig.Regen.Delay then
					humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + WeaponConfig.Regen.PerSecond * dt)
				end
			end
		end
	end)
end

return CombatService
