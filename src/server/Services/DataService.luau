--!strict
-- Saves and loads each player's profile with DataStores: coins, owned weapons,
-- loadouts, per-weapon kills (attachment unlocks), settings and lifetime stats.
--
-- Safety:
--   - A profile is "locked" to one server while someone plays, so two servers can't
--     overwrite each other if the player hops quickly.
--   - Loads and saves retry with a growing wait.
--   - If loading fails completely, the player still plays but nothing is saved, so a
--     temporary outage can never wipe real progress.
--   - In Studio without API access, profiles live in memory only (with a warning).
-- Turn on saving in Studio: Home → Game Settings → Security → Enable Studio Access
-- to API Services (the place must be published first).

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local SettingsConfig = require(ReplicatedStorage.Shared.Config.SettingsConfig)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local WeaponStats = require(ReplicatedStorage.Shared.Combat.WeaponStats)

local STORE_NAME = "PlayerProfiles_v1"
local AUTOSAVE_INTERVAL = 60
local LOCK_TIME = AUTOSAVE_INTERVAL * 3 -- a lock older than this is from a crashed server
local RETRIES = 4
local LOCK_WAIT = 4 -- seconds between tries while another server holds the lock
local MAX_SETTINGS_SAVES_PER_MINUTE = 30

export type LifetimeStats = {
	Kills: number,
	Deaths: number,
	Headshots: number,
	LongestShot: number,
	BestStreak: number,
	FlowKills: number,
	Wins: number,
	MatchesPlayed: number,
	TimePlayed: number,
}

export type Profile = {
	Version: number,
	Coins: number,
	OwnedWeapons: { [string]: boolean },
	EquippedWeapon: string,
	Loadouts: { [string]: WeaponStats.Loadout }, -- weapon id → slot → attachment id
	WeaponKills: { [string]: number },
	OwnedSkins: { [string]: boolean },
	EquippedSkins: { [string]: string }, -- weapon id → skin id
	Settings: { [string]: any },
	Stats: LifetimeStats,
}

type Session = {
	Profile: Profile,
	CanSave: boolean, -- false if loading failed; never save over unknown data
	Dirty: boolean,
	JoinedAt: number,
	SettingsSaves: { number },
}

local DataService = {}

DataService.ProfileLoaded = Signal.new() -- (player: Player, profile: Profile)

local sessions: { [Player]: Session } = {}
-- Identifies this server in profile locks. Studio has no JobId, so make one up.
local SERVER_ID = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)
local store: DataStore? = nil
local storeWarned = false

local profileUpdated = Net.Event(Net.Names.ProfileUpdated)
local settingsLoaded = Net.Event(Net.Names.SettingsLoaded)
local coinsEarned = Net.Event(Net.Names.CoinsEarned)

local function newProfile(): Profile
	return {
		Version = 1,
		Coins = 0,
		OwnedWeapons = { [WeaponConfig.DefaultWeapon] = true },
		EquippedWeapon = WeaponConfig.DefaultWeapon,
		Loadouts = {},
		WeaponKills = {},
		OwnedSkins = {},
		EquippedSkins = {},
		Settings = {},
		Stats = {
			Kills = 0,
			Deaths = 0,
			Headshots = 0,
			LongestShot = 0,
			BestStreak = 0,
			FlowKills = 0,
			Wins = 0,
			MatchesPlayed = 0,
			TimePlayed = 0,
		},
	}
end

-- Fills in anything an older save is missing, without touching what it has.
local function reconcile(saved: any): Profile
	local fresh = newProfile() :: any
	if typeof(saved) ~= "table" then
		return fresh
	end
	for key, value in fresh do
		if saved[key] == nil or typeof(saved[key]) ~= typeof(value) then
			saved[key] = value
		end
	end
	for key, value in fresh.Stats do
		if typeof(saved.Stats[key]) ~= typeof(value) then
			saved.Stats[key] = value
		end
	end
	saved.OwnedWeapons[WeaponConfig.DefaultWeapon] = true
	if not WeaponConfig.Weapons[saved.EquippedWeapon] or not saved.OwnedWeapons[saved.EquippedWeapon] then
		saved.EquippedWeapon = WeaponConfig.DefaultWeapon
	end
	saved.Settings = SettingsConfig.Merge(saved.Settings)
	return saved :: Profile
end

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, STORE_NAME)
	if ok then
		store = result
		return result
	end
	if not storeWarned then
		storeWarned = true
		warn("[DataService] DataStores unavailable, progress won't be saved this session:", result)
	end
	return nil
end

local function key(player: Player): string
	return `player_{player.UserId}`
end

-- The lock is stored alongside the profile.
type Stored = { Profile: any, Lock: { JobId: string, Expires: number }? }

local function load(player: Player): (Profile, boolean)
	local dataStore = getStore()
	if not dataStore then
		return newProfile(), false
	end
	local jobId = SERVER_ID

	for attempt = 1, RETRIES do
		local lockedElsewhere = false
		local loaded: any = nil
		local ok, err = pcall(function()
			dataStore:UpdateAsync(key(player), function(stored: Stored?)
				local current = stored or { Profile = nil, Lock = nil }
				local lock = current.Lock
				-- On the last try a stale-looking lock is taken over rather than waited on.
				if lock and lock.JobId ~= jobId and lock.Expires > os.time() and attempt < RETRIES then
					lockedElsewhere = true
					return nil -- cancel this update and try again shortly
				end
				current.Lock = { JobId = jobId, Expires = os.time() + LOCK_TIME }
				loaded = current.Profile
				return current
			end)
		end)
		if ok and not lockedElsewhere then
			return reconcile(loaded), true
		end
		if not ok then
			warn(`[DataService] load failed for {player.Name} (try {attempt}):`, err)
			if typeof(err) == "string" and err:find("StudioAccessToApisNotAllowed") then
				break
			end
		end
		task.wait(if lockedElsewhere then LOCK_WAIT else attempt * 2)
	end
	warn(`[DataService] couldn't load {player.Name}; playing without saving`)
	return newProfile(), false
end

local function save(player: Player, session: Session, release: boolean)
	local dataStore = getStore()
	if not dataStore or not session.CanSave then
		return
	end
	local stats = session.Profile.Stats
	stats.TimePlayed += os.clock() - session.JoinedAt
	session.JoinedAt = os.clock()

	for attempt = 1, RETRIES do
		local ok, err = pcall(function()
			dataStore:UpdateAsync(key(player), function(_stored: Stored?)
				return {
					Profile = session.Profile,
					Lock = if release then nil else { JobId = SERVER_ID, Expires = os.time() + LOCK_TIME },
				}
			end)
		end)
		if ok then
			session.Dirty = false
			return
		end
		warn(`[DataService] save failed for {player.Name} (try {attempt}):`, err)
		task.wait(attempt * 2)
	end
end

-- What the client sees: everything except internal fields.
local function push(player: Player)
	local session = sessions[player]
	if session then
		profileUpdated:FireClient(player, session.Profile)
	end
end

function DataService.Get(player: Player): Profile?
	local session = sessions[player]
	return if session then session.Profile else nil
end

-- Waits (up to `timeout`) for a player's profile to finish loading.
function DataService.WaitFor(player: Player, timeout: number?): Profile?
	local deadline = os.clock() + (timeout or 15)
	while not sessions[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return DataService.Get(player)
end

-- Runs `change` on the profile, marks it for saving and sends the update.
function DataService.Update(player: Player, change: (Profile) -> ())
	local session = sessions[player]
	if not session then
		return
	end
	change(session.Profile)
	session.Dirty = true
	push(player)
end

function DataService.AddCoins(player: Player, amount: number, reason: string)
	if amount <= 0 then
		return
	end
	DataService.Update(player, function(profile)
		profile.Coins += math.floor(amount)
	end)
	coinsEarned:FireClient(player, { Amount = math.floor(amount), Reason = reason })
end

-- Weapon id and attachments for this player's next life.
function DataService.GetLoadout(player: Player): (string, WeaponStats.Loadout)
	local profile = DataService.Get(player)
	if not profile then
		return WeaponConfig.DefaultWeapon, WeaponStats.CleanLoadout(nil)
	end
	local weaponId = profile.EquippedWeapon
	return weaponId, WeaponStats.CleanLoadout(profile.Loadouts[weaponId])
end

local function onPlayerAdded(player: Player)
	local profile, canSave = load(player)
	if not player.Parent then
		-- They left while loading; give the lock back.
		if canSave then
			save(
				player,
				{ Profile = profile, CanSave = true, Dirty = false, JoinedAt = os.clock(), SettingsSaves = {} },
				true
			)
		end
		return
	end
	sessions[player] =
		{ Profile = profile, CanSave = canSave, Dirty = false, JoinedAt = os.clock(), SettingsSaves = {} }
	push(player)
	settingsLoaded:FireClient(player, profile.Settings)
	DataService.ProfileLoaded:Fire(player, profile)
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if session then
		sessions[player] = nil
		save(player, session, true)
	end
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Clients ask again once they're listening, in case the first push came too early.
	Net.Event(Net.Names.RequestProfile).OnServerEvent:Connect(function(player)
		local session = sessions[player]
		if session then
			push(player)
			settingsLoaded:FireClient(player, session.Profile.Settings)
		end
	end)

	Net.Event(Net.Names.SaveSettings).OnServerEvent:Connect(function(player, batch: any)
		local session = sessions[player]
		if not session or typeof(batch) ~= "table" then
			return
		end
		local now = os.clock()
		local saves = session.SettingsSaves
		while saves[1] and now - saves[1] > 60 do
			table.remove(saves, 1)
		end
		if #saves >= MAX_SETTINGS_SAVES_PER_MINUTE then
			return
		end
		table.insert(saves, now)
		for id, value in batch do
			local clean = if typeof(id) == "string" then SettingsConfig.Sanitize(id, value) else nil
			if clean ~= nil then
				session.Profile.Settings[id] = clean
				session.Dirty = true
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, session in sessions do
				if session.Dirty then
					task.spawn(save, player, session, false)
				end
			end
		end
	end)

	-- Save everyone before the server shuts down.
	game:BindToClose(function()
		local pending = 0
		for player, session in sessions do
			pending += 1
			task.spawn(function()
				save(player, session, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
