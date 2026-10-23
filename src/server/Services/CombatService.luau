--!strict
-- Server side of all combat. Clients check hits locally for instant feedback and
-- report them; this service re-checks every claim and is the only place damage is
-- ever applied.
-- Sniper shots: ammo, fire-rate and reload timers, shot origin, lag-compensated
-- hitboxes and walls in the way (thin walls only stop shots from weapons that
-- can't pierce them).
-- Knife hits: equipped weapon, cooldowns, lag-compensated reach and line of sight.
-- Kills during a match pay out coins and count toward attachment unlocks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Ballistics = require(ReplicatedStorage.Shared.Combat.Ballistics)
local Hitboxes = require(ReplicatedStorage.Shared.Combat.Hitboxes)
local KillTags = require(ReplicatedStorage.Shared.Combat.KillTags)
local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local WeaponStats = require(ReplicatedStorage.Shared.Combat.WeaponStats)
local DataService = require(script.Parent.DataService)
local LagCompensation = require(script.Parent.LagCompensation)
local MatchState = require(script.Parent.MatchState)
local SpawnService = require(script.Parent.SpawnService)
local StatsService = require(script.Parent.StatsService)
local WorldWeaponService = require(script.Parent.WorldWeaponService)

local Validation = WeaponConfig.Validation
local Lag = WeaponConfig.LagCompensation

type Slot = "Sniper" | "Knife"

type WeaponState = {
	Stats: WeaponStats.Stats,
	Equipped: Slot,
	EquippedAt: number,
	Ammo: number,
	ShotsInCycle: number,
	NextShotDelay: number, -- the wait required after the last shot
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
local loadoutEvent = Net.Event(Net.Names.Loadout)

local function newWeaponState(stats: WeaponStats.Stats): WeaponState
	return {
		Stats = stats,
		Equipped = "Sniper",
		EquippedAt = -math.huge,
		Ammo = stats.MagSize,
		ShotsInCycle = 0,
		NextShotDelay = 0,
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
		state.Ammo = state.Stats.MagSize
		state.ShotsInCycle = 0
		state.ReloadEndsAt = nil
	end
end

local function sniperDamage(stats: WeaponStats.Stats, zone: Hitboxes.Zone): number
	if zone == "Head" then
		return stats.HeadDamage
	elseif zone == "Body" then
		return stats.BodyDamage
	end
	return stats.BodyDamage * stats.LimbMultiplier
end

local function charactersToIgnore(attacker: Model): { Instance }
	local ignore: { Instance } = LagCompensation.GetTrackedModels()
	table.insert(ignore, attacker)
	return ignore
end

-- How many thin walls are between the origin and the hit, or nil if blocked.
local function wallsInTheWay(
	attacker: Model,
	origin: Vector3,
	direction: Vector3,
	distance: number,
	penetration: number
): number?
	return Ballistics.WallsBetween(origin, direction, distance, charactersToIgnore(attacker), penetration)
end

local function reward(player: Player, amount: number, reason: string)
	if MatchState.Phase == "Playing" then
		DataService.AddCoins(player, amount, reason)
	end
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
	local attackerState = weaponStates[attacker]
	local weaponName = if weaponKind == "Sniper" and attackerState
		then attackerState.Stats.DisplayName
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

		-- Dummies respawn forever, so they don't pay out unless turned on for testing.
		local countsForProgress = victimPlayer ~= nil or MatchConfig.DummyKillsCount
		-- Coins only for tags the server can check itself, so a modified client can't
		-- farm bonuses by claiming airshots or Overflow.
		local rewards = MatchConfig.Rewards
		local coins = rewards.Kill
		if table.find(tags, "HEADSHOT") then
			coins += rewards.Headshot
		end
		if table.find(tags, "LONGSHOT") then
			coins += rewards.Longshot
		end
		if table.find(tags, "SLICE") then
			coins += rewards.Slice
		end
		if countsForProgress then
			reward(attacker, coins, table.concat(tags, " · "))
		end

		if countsForProgress and MatchState.Phase == "Playing" then
			local streak = attacker:GetAttribute("Streak") or 0
			DataService.Update(attacker, function(profile)
				local stats = profile.Stats
				stats.Kills += 1
				stats.BestStreak = math.max(stats.BestStreak, streak)
				if table.find(tags, "HEADSHOT") then
					stats.Headshots += 1
				end
				if table.find(tags, "FLOW KILL") then
					stats.FlowKills += 1
				end
				if weaponKind == "Sniper" and attackerState then
					stats.LongestShot = math.max(stats.LongestShot, math.floor(distance))
					local weaponId = attackerState.Stats.WeaponId
					profile.WeaponKills[weaponId] = (profile.WeaponKills[weaponId] or 0) + 1
				end
			end)
		end

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
	if state.Equipped ~= "Sniper" or not MatchState.CombatEnabled then
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

	local stats = state.Stats
	settleReload(state, serverClock)
	if state.ReloadEndsAt or state.Ammo <= 0 then
		return
	end
	-- Checked on both clocks: the client's timestamps must be far enough apart, and
	-- so must the arrivals (with slack for network jitter).
	local requiredGap = state.NextShotDelay
	if shotTime - state.LastShotTime < requiredGap - Validation.TimingTolerance then
		return
	end
	if serverClock - state.LastShotAt < requiredGap - Validation.TimingTolerance * 2 then
		return
	end

	local speed = if root then root.AssemblyLinearVelocity.Magnitude else 0
	local allowedOffset = Validation.OriginTolerance + speed * Validation.OriginSpeedAllowance
	if (origin - head.Position).Magnitude > allowedOffset then
		return
	end

	state.Ammo -= 1
	state.ShotsInCycle += 1
	state.NextShotDelay = WeaponStats.NextShotDelay(stats, state.ShotsInCycle)
	if state.ShotsInCycle >= stats.ShotsPerCycle then
		state.ShotsInCycle = 0
	end
	state.LastShotAt = serverClock
	state.LastShotTime = shotTime
	SpawnService.EndProtection(character)

	-- Other players draw the tracer and impact. Hitting a character shows no bullet hole.
	local worldHit = Ballistics.Cast(origin, direction, WeaponConfig.MaxRange, { character }, stats.Penetration).Hit
	local hitParent = worldHit and worldHit.Instance.Parent
	local effect = {
		Origin = origin,
		EndPoint = if worldHit then worldHit.Position else origin + direction * WeaponConfig.MaxRange,
		Normal = if worldHit then worldHit.Normal else nil,
		Material = if worldHit then worldHit.Material else nil,
		HitCharacter = hitParent ~= nil and hitParent:FindFirstChildOfClass("Humanoid") ~= nil,
		Suppressed = stats.Suppressed,
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
	local walls = wallsInTheWay(character, origin, direction, distance, stats.Penetration)
	if not walls then
		return
	end
	local zone = Hitboxes.GetZone(hitPart)
	if not zone then
		return
	end
	local damage = sniperDamage(stats, zone)
	if walls > 0 then
		damage *= WeaponConfig.PenetrationDamageMultiplier
	end

	applyDamage(
		player,
		victimModel,
		victimHumanoid,
		damage,
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
	if not MatchState.CombatEnabled then
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
	if
		toVictim.Magnitude > 1e-3 and not wallsInTheWay(character, head.Position, toVictim.Unit, toVictim.Magnitude, 0)
	then
		return
	end

	if kind == "Slash" then
		state.LastSlashAt = serverClock
	else
		state.LastLungeAt = serverClock
	end
	SpawnService.EndProtection(character)
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
	if state.ReloadEndsAt or state.Ammo >= state.Stats.MagSize then
		return
	end
	state.ReloadEndsAt = serverClock + state.Stats.ReloadTime
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
	LagCompensation.Track(character)
	-- The loadout is read once per life, so changes in the menu apply on respawn.
	DataService.WaitFor(player, 5)
	if player.Character ~= character then
		return
	end
	local weaponId, attachments = DataService.GetLoadout(player)
	local stats = WeaponStats.Compute(weaponId, attachments)
	weaponStates[player] = newWeaponState(stats)
	loadoutEvent:FireClient(player, { WeaponId = weaponId, Attachments = attachments })
	WorldWeaponService.SetPalette(character, stats.Palette)

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.MaxHealth = WeaponConfig.MaxHealth
	humanoid.Health = WeaponConfig.MaxHealth
	humanoid.Died:Connect(function()
		lastDamagedAt[humanoid] = nil
	end)
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
	local REGEN_STEP = 0.1
	local elapsed = 0
	RunService.Heartbeat:Connect(function(frameDt)
		elapsed += frameDt
		if elapsed < REGEN_STEP then
			return
		end
		local dt = elapsed
		elapsed = 0
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
