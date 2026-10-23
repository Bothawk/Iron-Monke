--!strict
-- Every weapon and combat number lives here so balance can change without touching code.
-- Times are in seconds, distances in studs, angles in degrees.

export type Weapon = {
	DisplayName: string,
	AdsTime: number, -- time to fully scope in
	BodyDamage: number,
	HeadDamage: number,
	BoltTime: number, -- rechamber time after each shot
	MagSize: number,
	ReloadTime: number,
	Zoom: number, -- scope magnification
}

local Weapons: { [string]: Weapon } = {
	Vanta = {
		DisplayName = "VANTA",
		AdsTime = 0.14,
		BodyDamage = 100, -- one-shot to the body
		HeadDamage = 999, -- headshots always kill
		BoltTime = 0.9,
		MagSize = 5,
		ReloadTime = 2.0,
		Zoom = 4,
	},
}

local WeaponConfig = {
	Weapons = Weapons,
	DefaultWeapon = "Vanta",

	MaxHealth = 100,
	LimbMultiplier = 0.75, -- limbs take body damage × this
	MaxRange = 2000,
	HipfireSpread = 6, -- cone half-angle when not scoped at all
	UnscopeTime = 0.08,
	RespawnTime = 4,

	Regen = {
		Delay = 5, -- seconds without taking damage before health comes back
		PerSecond = 20,
	},

	-- 1 = scoped sensitivity matched to the zoom, so the view moves the same
	-- distance on screen as when unscoped. Lower is slower.
	ScopedSensitivity = 1,

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
	},
}

return WeaponConfig
