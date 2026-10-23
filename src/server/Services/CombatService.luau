--!strict
-- Server side of all combat. Clients check hits locally for instant feedback and
-- report them; this service re-checks every claim and is the only place damage is
-- ever applied.
-- Sniper shots: ammo, bolt and reload timers, shot origin, lag-compensated
-- hitboxes and walls in the way.
-- Knife hits: equipped weapon, cooldowns, lag-compensated reach and line of sight.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Hitboxes = require(ReplicatedStorage.Shared.Combat.Hitboxes)
local KillTags = require(ReplicatedStorage.Shared.Combat.KillTags)
local Net = require(ReplicatedStorage.Shared.Net)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local LagCompensation = require(script.Parent.LagCompensation)
local StatsService = require(script.Parent.StatsService)
local WorldWeaponService = require(script.Parent.WorldWeaponService)

local Validation = WeaponConfig.Validation
local Lag = WeaponConfig.LagCompensation

type Slot = "Sniper" | "Knife"

type WeaponState = {
	WeaponId: string,
	Equipped: Slot,
	EquippedAt: number,
	Ammo: number,
	LastShotAt: number, -- server clock when the last shot arrived
	LastShotTime: number, -- the client's timestamp on the last shot
	ReloadEndsAt: number?,
	LastSlashAt: number,
	LastLungeAt: number,
	ShotTimes: { number }, -- arrival times in the last second, for rate limits
	ReloadTimes: { number },
	EquipTimes: { number },
}

local CombatService = {}

local weaponStates: { [Player]: WeaponState } = {}
local lastDamagedAt: { [Humanoid]: number } = {}

local fireShot = Net.Event(Net.Names.FireShot)
local reload = Net.Event(Net.Names.Reload)
local equip = Net.Event(Net.Names.Equip)
local meleeHit = Net.Event(Net.Names.MeleeHit)
local shotResult = Net.Event(Net.Names.ShotResult)
local tookDamage = Net.Event(Net.Names.TookDamage)
local shotEffect = Net.Event(Net.Names.ShotEffect)
local killFeed = Net.Event(Net.Names.KillFeed)

local function newWeaponState(): WeaponState
	local weaponId = WeaponConfig.DefaultWeapon
	return {
		WeaponId = weaponId,
		Equipped = "Sniper",
		EquippedAt = -math.huge,
		Ammo = WeaponConfig.Weapons[weaponId].MagSize,
		LastShotAt = -math.huge,
		LastShotTime = -math.huge,
		ReloadEndsAt = nil,
		LastSlashAt = -math.huge,
		LastLungeAt = -math.huge,
		ShotTimes = {},
		ReloadTimes = {},
		EquipTimes = {},
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

local function getPart(model: Model, name: string): BasePart?
	local part = model:FindFirstChild(name)
	return if part and part:IsA("BasePart") then part else nil
end

local function displayName(model: Model): string
	local player = Players:GetPlayerFromCharacter(model)
	if player then
		return player.DisplayName
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return if humanoid and humanoid.DisplayName ~= "" then humanoid.DisplayName else model.Name
end

-- Finishes a reload whose timer has run out.
local function settleReload(state: WeaponState, now: number)
	local endsAt = state.ReloadEndsAt
	if endsAt and now >= endsAt - Validation.TimingTolerance then
		state.Ammo = WeaponConfig.Weapons[state.WeaponId].MagSize
		state.ReloadEndsAt = nil
	end
end

local function sniperDamage(weaponId: string, zone: Hitboxes.Zone): number
	local weapon = WeaponConfig.Weapons[weaponId]
	if zone == "Head" then
		return weapon.HeadDamage
	elseif zone == "Body" then
		return weapon.BodyDamage
	end
	return weapon.BodyDamage * WeaponConfig.LimbMultiplier
end

-- Is anything solid (not a character) between the origin and the hit?
local function isBlocked(attacker: Model, origin: Vector3, direction: Vector3, distance: number): boolean
	local ignore: { Instance } = LagCompensation.GetTrackedModels()
	table.insert(ignore, attacker)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(origin, direction * distance, params)
	-- A small margin so the edge of a box hugging a wall still counts.
	return hit ~= nil and hit.Distance < distance - 0.5
end

local function rewindTime(clientTime: number, now: number): number
	return math.clamp(clientTime, now - Lag.MaxRewind, now)
end

-- The one place damage happens. Tells the attacker, the victim and (on a kill)
-- everyone's kill feed.
local function applyDamage(
	attacker: Player,
	victim: Model,
	humanoid: Humanoid,
	damage: number,
	weaponKind: string, -- "Sniper", "Slash" or "Lunge"
	zone: Hitboxes.Zone,
	distance: number,
	origin: Vector3,
	context: KillTags.ShotContext?
)
	humanoid:TakeDamage(damage)
	lastDamagedAt[humanoid] = os.clock()
	local killed = humanoid.Health <= 0
	local tags = if killed then KillTags.Compute(weaponKind, zone, distance, context) else {}
	local weaponName = if weaponKind == "Sniper"
		then WeaponConfig.Weapons[weaponStates[attacker].WeaponId].DisplayName
		else WeaponConfig.Knife.DisplayName
	local victimPlayer = Players:GetPlayerFromCharacter(victim)

	shotResult:FireClient(attacker, {
		Zone = zone,
		Damage = damage,
		Killed = killed,
		Distance = distance,
		Tags = tags,
		Weapon = weaponName,
	})

	if victimPlayer then
		tookDamage:FireClient(victimPlayer, {
			Damage = damage,
			From = origin,
			Killed = killed,
			Killer = attacker.DisplayName,
			KillerUserId = attacker.UserId,
			Weapon = weaponName,
			Distance = distance,
			Tags = tags,
		})
	end

	if killed then
		StatsService.RecordKill(attacker, victimPlayer, tags)
		killFeed:FireAllClients({
			Killer = attacker.DisplayName,
			KillerUserId = attacker.UserId,
			Victim = displayName(victim),
			VictimUserId = if victimPlayer then victimPlayer.UserId else 0,
			Weapon = weaponName,
			Tags = tags,
		})
	end
end

local function getVictim(victim: any, attackerCharacter: Model): (Model?, Humanoid?)
	if typeof(victim) ~= "Instance" or not victim:IsA("Model") or victim == attackerCharacter then
		return nil, nil
	end
	if not LagCompensation.IsTracked(victim) then
		return nil, nil
	end
	local humanoid = getAliveHumanoid(victim)
	if not humanoid then
		return nil, nil
	end
	return victim, humanoid
end

local function onFireShot(
	player: Player,
	origin: any,
	direction: any,
	shotTime: any,
	victim: any,
	partName: any,
	rawContext: any
)
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
	local head = character and getPart(character, "Head")
	local root = character and getPart(character, "HumanoidRootPart")
	if not state or not character or not getAliveHumanoid(character) or not head then
		return
	end
	if state.Equipped ~= "Sniper" then
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

	local speed = if root then root.AssemblyLinearVelocity.Magnitude else 0
	local allowedOffset = Validation.OriginTolerance + speed * Validation.OriginSpeedAllowance
	if (origin - head.Position).Magnitude > allowedOffset then
		return
	end

	state.Ammo -= 1
	state.LastShotAt = serverClock
	state.LastShotTime = shotTime

	-- Other players draw the tracer and impact. Hitting a character shows no bullet hole.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local worldHit = workspace:Raycast(origin, direction * WeaponConfig.MaxRange, params)
	local hitParent = worldHit and worldHit.Instance.Parent
	local effect = {
		Origin = origin,
		EndPoint = if worldHit then worldHit.Position else origin + direction * WeaponConfig.MaxRange,
		Normal = if worldHit then worldHit.Normal else nil,
		Material = if worldHit then worldHit.Material else nil,
		HitCharacter = hitParent ~= nil and hitParent:FindFirstChildOfClass("Humanoid") ~= nil,
	}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			shotEffect:FireClient(other, effect)
		end
	end

	local victimModel, victimHumanoid = getVictim(victim, character)
	if not victimModel or not victimHumanoid then
		return
	end
	local claimedPart = if typeof(partName) == "string" then partName else nil

	local rewindTo = rewindTime(shotTime, now)
	local hitPart, distance = LagCompensation.Raycast(
		victimModel,
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

	applyDamage(
		player,
		victimModel,
		victimHumanoid,
		sniperDamage(state.WeaponId, zone),
		"Sniper",
		zone,
		distance,
		origin,
		KillTags.Sanitize(rawContext)
	)
end

local function onMeleeHit(player: Player, kind: any, victim: any, attackTime: any, rawContext: any)
	if (kind ~= "Slash" and kind ~= "Lunge") or typeof(attackTime) ~= "number" or attackTime ~= attackTime then
		return
	end
	local state = weaponStates[player]
	local character = player.Character
	local head = character and getPart(character, "Head")
	local root = character and getPart(character, "HumanoidRootPart")
	if not state or not character or not getAliveHumanoid(character) or not head then
		return
	end

	local serverClock = os.clock()
	if state.Equipped ~= "Knife" or serverClock - state.EquippedAt < WeaponConfig.Knife.SwitchTime * 0.5 then
		return
	end
	local attack = if kind == "Slash" then WeaponConfig.Knife.Slash else WeaponConfig.Knife.Lunge
	local lastAt = if kind == "Slash" then state.LastSlashAt else state.LastLungeAt
	if serverClock - lastAt < attack.Cooldown - Validation.TimingTolerance * 2 then
		return
	end

	local now = workspace:GetServerTimeNow()
	if attackTime > now + Validation.FutureTolerance then
		return
	end
	local victimModel, victimHumanoid = getVictim(victim, character)
	if not victimModel or not victimHumanoid then
		return
	end

	-- A lunge can land anywhere along its dash, and the server may still see the
	-- attacker at the start of it.
	local reach = if kind == "Slash"
		then WeaponConfig.Knife.Slash.Range
		else WeaponConfig.Knife.Lunge.HitRange + WeaponConfig.Knife.Lunge.DashDistance
	local speed = if root then root.AssemblyLinearVelocity.Magnitude else 0
	reach += Validation.MeleeRangeTolerance + speed * Validation.OriginSpeedAllowance

	local rewindTo = rewindTime(attackTime, now)
	local distance, closest =
		LagCompensation.ClosestDistance(victimModel, head.Position, rewindTo - Lag.InterpolationWindow, rewindTo)
	if distance > reach or not closest then
		return
	end
	local toVictim = closest - head.Position
	if toVictim.Magnitude > 1e-3 and isBlocked(character, head.Position, toVictim.Unit, toVictim.Magnitude) then
		return
	end

	if kind == "Slash" then
		state.LastSlashAt = serverClock
	else
		state.LastLungeAt = serverClock
	end
	applyDamage(
		player,
		victimModel,
		victimHumanoid,
		attack.Damage,
		kind,
		"Body",
		distance,
		head.Position,
		KillTags.Sanitize(rawContext)
	)
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

local function onEquip(player: Player, slot: any)
	if slot ~= "Sniper" and slot ~= "Knife" then
		return
	end
	local state = weaponStates[player]
	local character = player.Character
	if not state or not character or not getAliveHumanoid(character) or state.Equipped == slot then
		return
	end
	local serverClock = os.clock()
	if not underRateLimit(state.EquipTimes, serverClock, Validation.MaxEquipsPerSecond) then
		return
	end
	state.Equipped = slot
	state.EquippedAt = serverClock
	WorldWeaponService.SetEquipped(character, slot)
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
	meleeHit.OnServerEvent:Connect(onMeleeHit)
	reload.OnServerEvent:Connect(onReload)
	equip.OnServerEvent:Connect(onEquip)

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
