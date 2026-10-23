--!strict
-- Works out a weapon's final numbers with its attachments. The client and the
-- server both use this, so they always agree on timings and damage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)

export type Stats = WeaponConfig.Weapon & {
	WeaponId: string,
	Suppressed: boolean,
	RedDot: boolean,
}

export type Loadout = { [string]: string } -- slot → attachment id

local WeaponStats = {}

-- Keeps only attachments that exist and sit in their own slot, filling the rest
-- with defaults.
function WeaponStats.CleanLoadout(raw: any): Loadout
	local loadout: Loadout = table.clone(WeaponConfig.DefaultAttachments)
	if typeof(raw) == "table" then
		for _, slot in WeaponConfig.Slots do
			local id = raw[slot]
			local attachment = if typeof(id) == "string" then WeaponConfig.AttachmentsById[id] else nil
			if attachment and attachment.Slot == slot then
				loadout[slot] = attachment.Id
			end
		end
	end
	return loadout
end

function WeaponStats.Compute(weaponId: string, rawLoadout: any): Stats
	local base = WeaponConfig.Weapons[weaponId] or WeaponConfig.Weapons[WeaponConfig.DefaultWeapon]
	local stats = table.clone(base) :: any
	stats.WeaponId = if WeaponConfig.Weapons[weaponId] then weaponId else WeaponConfig.DefaultWeapon
	stats.Suppressed = false
	stats.RedDot = false

	for _, attachmentId in WeaponStats.CleanLoadout(rawLoadout) do
		local mods = WeaponConfig.AttachmentsById[attachmentId].Mods
		if mods.ZoomOverride then
			stats.Zoom = mods.ZoomOverride
		end
		stats.Zoom *= mods.ZoomMultiplier or 1
		stats.AdsTime += mods.AdsTimeAdd or 0
		stats.BoltTime *= mods.BoltTimeMultiplier or 1
		stats.ReloadTime *= mods.ReloadTimeMultiplier or 1
		stats.MagSize += mods.MagSizeAdd or 0
		stats.HipfireSpread *= mods.HipfireSpreadMultiplier or 1
		stats.MoveSpeedMultiplier *= mods.MoveSpeedMultiplier or 1
		stats.Kick *= mods.KickMultiplier or 1
		stats.Suppressed = stats.Suppressed or mods.Suppressed == true
		stats.RedDot = stats.RedDot or mods.RedDot == true
	end

	stats.AdsTime = math.max(0.05, stats.AdsTime)
	stats.MagSize = math.max(1, stats.MagSize)
	-- A cycle never holds more shots than the mag.
	stats.ShotsPerCycle = math.min(stats.ShotsPerCycle, stats.MagSize)
	return stats :: Stats
end

-- Time before the next shot is allowed, given how many shots of the current
-- cycle have been fired (after counting the shot just taken).
function WeaponStats.NextShotDelay(stats: Stats, shotsInCycle: number): number
	if shotsInCycle >= stats.ShotsPerCycle then
		return stats.BoltTime
	end
	return stats.FireInterval
end

return WeaponStats
