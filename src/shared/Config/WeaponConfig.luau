--!strict
-- Every weapon, attachment and combat number lives here so balance can change
-- without touching code. Times are in seconds, distances in studs, angles in degrees.

export type FireMode = "Bolt" | "Semi"

export type Palette = {
	Primary: Color3,
	Secondary: Color3,
	Accent: Color3,
	Material: Enum.Material,
}

export type Weapon = {
	DisplayName: string,
	Description: string,
	Price: number, -- coins; 0 = owned from the start
	FireMode: FireMode,
	ShotsPerCycle: number, -- shots fired before the bolt has to be worked
	FireInterval: number, -- time between shots inside one cycle
	BoltTime: number, -- time to work the bolt after a cycle (for Semi, the time between shots)
	UnscopeOnFire: boolean, -- Krunker-style: drop out of the scope after a cycle
	AdsTime: number, -- time to fully scope in
	BodyDamage: number,
	HeadDamage: number,
	LimbMultiplier: number, -- limbs take body damage × this
	MagSize: number,
	ReloadTime: number,
	Zoom: number, -- scope magnification
	HipfireSpread: number, -- cone half-angle when not scoped at all
	MoveSpeedMultiplier: number,
	Penetration: number, -- how many thin walls a shot can pass through
	Kick: number, -- recoil strength, 1 = normal
	Palette: Palette,
}

local function palette(primary: Color3, secondary: Color3, accent: Color3): Palette
	return { Primary = primary, Secondary = secondary, Accent = accent, Material = Enum.Material.SmoothPlastic }
end

local Weapons: { [string]: Weapon } = {
	Vanta = {
		DisplayName = "VANTA",
		Description = "The all-rounder. One shot to the body or head.",
		Price = 0,
		FireMode = "Bolt",
		ShotsPerCycle = 1,
		FireInterval = 0,
		BoltTime = 0.9,
		UnscopeOnFire = true,
		AdsTime = 0.14,
		BodyDamage = 100,
		HeadDamage = 999,
		LimbMultiplier = 0.75,
		MagSize = 5,
		ReloadTime = 2.0,
		Zoom = 4,
		HipfireSpread = 6,
		MoveSpeedMultiplier = 1,
		Penetration = 0,
		Kick = 1,
		Palette = palette(Color3.fromRGB(58, 60, 66), Color3.fromRGB(28, 29, 33), Color3.fromRGB(255, 140, 40)),
	},
	Needle = {
		DisplayName = "NEEDLE",
		Description = "Fastest scope in the game. Body shots need a follow-up.",
		Price = 1500,
		FireMode = "Bolt",
		ShotsPerCycle = 1,
		FireInterval = 0,
		BoltTime = 0.6,
		UnscopeOnFire = true,
		AdsTime = 0.1,
		BodyDamage = 70,
		HeadDamage = 999,
		LimbMultiplier = 0.75,
		MagSize = 6,
		ReloadTime = 1.8,
		Zoom = 3.5,
		HipfireSpread = 5,
		MoveSpeedMultiplier = 1.06,
		Penetration = 0,
		Kick = 0.8,
		Palette = palette(Color3.fromRGB(226, 228, 234), Color3.fromRGB(60, 64, 74), Color3.fromRGB(70, 210, 255)),
	},
	Harpoon = {
		DisplayName = "HARPOON",
		Description = "Kills with any hit and punches through one thin wall.",
		Price = 3000,
		FireMode = "Bolt",
		ShotsPerCycle = 1,
		FireInterval = 0,
		BoltTime = 1.2,
		UnscopeOnFire = true,
		AdsTime = 0.2,
		BodyDamage = 100,
		HeadDamage = 999,
		LimbMultiplier = 1,
		MagSize = 4,
		ReloadTime = 2.4,
		Zoom = 5,
		HipfireSpread = 7,
		MoveSpeedMultiplier = 0.92,
		Penetration = 1,
		Kick = 1.4,
		Palette = palette(Color3.fromRGB(70, 82, 64), Color3.fromRGB(34, 38, 30), Color3.fromRGB(230, 200, 60)),
	},
	Twinbolt = {
		DisplayName = "TWINBOLT",
		Description = "Two quick shots, then a reload. Two body shots kill.",
		Price = 4500,
		FireMode = "Bolt",
		ShotsPerCycle = 2,
		FireInterval = 0.25,
		BoltTime = 0.25,
		UnscopeOnFire = true,
		AdsTime = 0.15,
		BodyDamage = 60,
		HeadDamage = 100,
		LimbMultiplier = 0.75,
		MagSize = 2,
		ReloadTime = 1.6,
		Zoom = 4,
		HipfireSpread = 6,
		MoveSpeedMultiplier = 1,
		Penetration = 0,
		Kick = 1.1,
		Palette = palette(Color3.fromRGB(96, 44, 52), Color3.fromRGB(36, 22, 26), Color3.fromRGB(255, 90, 110)),
	},
	Pulse = {
		DisplayName = "PULSE",
		Description = "Semi-auto: keep firing while scoped. Wide hip-fire spread.",
		Price = 6000,
		FireMode = "Semi",
		ShotsPerCycle = 1,
		FireInterval = 0,
		BoltTime = 0.35,
		UnscopeOnFire = false,
		AdsTime = 0.16,
		BodyDamage = 55,
		HeadDamage = 110,
		LimbMultiplier = 0.75,
		MagSize = 8,
		ReloadTime = 2.2,
		Zoom = 3.5,
		HipfireSpread = 9,
		MoveSpeedMultiplier = 1,
		Penetration = 0,
		Kick = 0.7,
		Palette = palette(Color3.fromRGB(40, 44, 70), Color3.fromRGB(20, 22, 34), Color3.fromRGB(160, 110, 255)),
	},
}

-- Shop and loadout order.
local WEAPON_ORDER = { "Vanta", "Needle", "Harpoon", "Twinbolt", "Pulse" }

export type Slot = "Scope" | "Barrel" | "Stock" | "Bolt" | "Mag"

-- What an attachment changes. Multipliers default to 1, additions to 0.
export type Mods = {
	ZoomMultiplier: number?,
	ZoomOverride: number?,
	AdsTimeAdd: number?,
	BoltTimeMultiplier: number?,
	ReloadTimeMultiplier: number?,
	MagSizeAdd: number?,
	HipfireSpreadMultiplier: number?,
	MoveSpeedMultiplier: number?,
	KickMultiplier: number?,
	Suppressed: boolean?,
	RedDot: boolean?,
}

export type Attachment = {
	Id: string,
	Slot: Slot,
	DisplayName: string,
	Description: string,
	UnlockKills: number, -- kills with that weapon needed; 0 = always available
	Mods: Mods,
}

local ATTACHMENTS: { Attachment } = {
	{
		Id = "Scope4x",
		Slot = "Scope",
		DisplayName = "Standard scope",
		Description = "The weapon's own zoom.",
		UnlockKills = 0,
		Mods = {},
	},
	{
		Id = "Scope6x",
		Slot = "Scope",
		DisplayName = "Long scope",
		Description = "More zoom, slightly slower to scope.",
		UnlockKills = 10,
		Mods = { ZoomMultiplier = 1.5, AdsTimeAdd = 0.02 },
	},
	{
		Id = "RedDot",
		Slot = "Scope",
		DisplayName = "Red dot",
		Description = "2x zoom with an open view, much faster to scope.",
		UnlockKills = 25,
		Mods = { ZoomOverride = 2, AdsTimeAdd = -0.03, RedDot = true },
	},

	{
		Id = "NoBarrel",
		Slot = "Barrel",
		DisplayName = "Standard barrel",
		Description = "No changes.",
		UnlockKills = 0,
		Mods = {},
	},
	{
		Id = "MuzzleBrake",
		Slot = "Barrel",
		DisplayName = "Muzzle brake",
		Description = "Half the recoil kick.",
		UnlockKills = 10,
		Mods = { KickMultiplier = 0.5 },
	},
	{
		Id = "LongBarrel",
		Slot = "Barrel",
		DisplayName = "Long barrel",
		Description = "Tighter hip-fire, slightly slower to scope.",
		UnlockKills = 25,
		Mods = { HipfireSpreadMultiplier = 0.7, AdsTimeAdd = 0.02 },
	},
	{
		Id = "Suppressor",
		Slot = "Barrel",
		DisplayName = "Suppressor",
		Description = "Enemies see no tracer and hear a quieter shot. Slightly slower bolt.",
		UnlockKills = 100,
		Mods = { Suppressed = true, BoltTimeMultiplier = 1.05 },
	},

	{
		Id = "NoStock",
		Slot = "Stock",
		DisplayName = "Standard stock",
		Description = "No changes.",
		UnlockKills = 0,
		Mods = {},
	},
	{
		Id = "LightStock",
		Slot = "Stock",
		DisplayName = "Light stock",
		Description = "Faster to scope, more recoil.",
		UnlockKills = 10,
		Mods = { AdsTimeAdd = -0.02, KickMultiplier = 1.3 },
	},
	{
		Id = "HeavyStock",
		Slot = "Stock",
		DisplayName = "Heavy stock",
		Description = "Less recoil, slightly slower movement.",
		UnlockKills = 25,
		Mods = { KickMultiplier = 0.6, MoveSpeedMultiplier = 0.96 },
	},

	{
		Id = "StandardBolt",
		Slot = "Bolt",
		DisplayName = "Standard bolt",
		Description = "No changes.",
		UnlockKills = 0,
		Mods = {},
	},
	{
		Id = "MatchBolt",
		Slot = "Bolt",
		DisplayName = "Match bolt",
		Description = "One more round, slightly slower bolt.",
		UnlockKills = 25,
		Mods = { MagSizeAdd = 1, BoltTimeMultiplier = 1.1 },
	},
	{
		Id = "GreasedBolt",
		Slot = "Bolt",
		DisplayName = "Greased bolt",
		Description = "15% faster bolt, one less round.",
		UnlockKills = 200,
		Mods = { BoltTimeMultiplier = 0.85, MagSizeAdd = -1 },
	},

	{
		Id = "StandardMag",
		Slot = "Mag",
		DisplayName = "Standard mag",
		Description = "No changes.",
		UnlockKills = 0,
		Mods = {},
	},
	{
		Id = "QuickMag",
		Slot = "Mag",
		DisplayName = "Quick mag",
		Description = "25% faster reload.",
		UnlockKills = 10,
		Mods = { ReloadTimeMultiplier = 0.75 },
	},
	{
		Id = "ExtendedMag",
		Slot = "Mag",
		DisplayName = "Extended mag",
		Description = "Two more rounds, slower reload.",
		UnlockKills = 50,
		Mods = { MagSizeAdd = 2, ReloadTimeMultiplier = 1.15 },
	},
}

local ATTACHMENTS_BY_ID: { [string]: Attachment } = {}
local DEFAULT_ATTACHMENTS: { [string]: string } = {}
for _, attachment in ATTACHMENTS do
	ATTACHMENTS_BY_ID[attachment.Id] = attachment
	if attachment.UnlockKills == 0 then
		DEFAULT_ATTACHMENTS[attachment.Slot] = attachment.Id
	end
end

local WeaponConfig = {
	Weapons = Weapons,
	WeaponOrder = WEAPON_ORDER,
	DefaultWeapon = "Vanta",

	Attachments = ATTACHMENTS,
	AttachmentsById = ATTACHMENTS_BY_ID,
	DefaultAttachments = DEFAULT_ATTACHMENTS, -- slot → attachment id
	Slots = { "Scope", "Barrel", "Stock", "Bolt", "Mag" } :: { Slot },

	Knife = {
		DisplayName = "KNIFE",
		SwitchTime = 0.2, -- swapping between sniper and knife
		Slash = { Damage = 50, Range = 5, Cooldown = 0.35, Radius = 1.2 },
		-- Dashes forward and hits the first enemy it reaches.
		Lunge = { Damage = 100, DashDistance = 10, DashTime = 0.18, HitRange = 3.5, Cooldown = 1.2, Radius = 1.4 },
	},

	MaxHealth = 100,
	MaxRange = 2000,
	UnscopeTime = 0.08,
	RespawnTime = 4,
	-- A wall at most this thick counts as thin enough to shoot through (Harpoon).
	MaxPenetrationThickness = 3,
	PenetrationDamageMultiplier = 0.5,

	Regen = {
		Delay = 5, -- seconds without taking damage before health comes back
		PerSecond = 20,
	},

	LagCompensation = {
		SnapshotRate = 30, -- hitbox recordings per second
		History = 1, -- seconds of recordings kept
		MaxRewind = 0.25, -- how far back a shot's timestamp can rewind
		-- Clients draw other players slightly in the past, so a shot is also
		-- checked against this much extra history before its timestamp.
		InterpolationWindow = 0.12,
		SampleStep = 1 / 60, -- how finely that window is checked
		HitboxPadding = 0.2, -- forgiveness added to every side of each hitbox
	},

	Validation = {
		OriginTolerance = 4, -- how far the shot origin may be from the shooter's head
		OriginSpeedAllowance = 0.15, -- extra tolerance per stud/s the shooter is moving
		TimingTolerance = 0.15, -- network jitter allowed on bolt and reload timers
		FutureTolerance = 0.05, -- how far ahead of the server clock a timestamp may be
		MaxShotsPerSecond = 15, -- hard cap before shots are dropped
		MaxReloadsPerSecond = 5,
		MeleeRangeTolerance = 2.5, -- extra reach allowed for lag on knife hits
		MaxEquipsPerSecond = 8,
	},
}

return WeaponConfig
