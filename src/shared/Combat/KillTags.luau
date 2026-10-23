--!strict
-- Labels a kill for the banner and kill feed: HEADSHOT, NOSCOPE, QUICKSCOPE,
-- AIRSHOT, FLOW KILL, LONGSHOT, SLICE. The server works these out so everyone sees
-- the same tags.

export type ShotContext = {
	AdsAlpha: number, -- 0..1 how far the scope was up
	ScopedFor: number, -- seconds the scope had been fully up
	Airborne: boolean,
	Overflow: boolean,
}

local NOSCOPE_MAX_ADS = 0.35
local QUICKSCOPE_WINDOW = 0.25
local LONGSHOT_DISTANCE = 200

local KillTags = {}

-- Turns whatever the client sent into a safe context, or nil if it's junk.
function KillTags.Sanitize(raw: any): ShotContext?
	if typeof(raw) ~= "table" then
		return nil
	end
	local ads, scopedFor = raw.AdsAlpha, raw.ScopedFor
	if typeof(ads) ~= "number" or typeof(scopedFor) ~= "number" or ads ~= ads or scopedFor ~= scopedFor then
		return nil
	end
	return {
		AdsAlpha = math.clamp(ads, 0, 1),
		ScopedFor = math.clamp(scopedFor, 0, 60),
		Airborne = raw.Airborne == true,
		Overflow = raw.Overflow == true,
	}
end

function KillTags.Compute(weaponKind: string, zone: string, distance: number, context: ShotContext?): { string }
	local tags = {}
	if weaponKind == "Knife" then
		table.insert(tags, "SLICE")
	elseif zone == "Head" then
		table.insert(tags, "HEADSHOT")
	end
	if context and weaponKind ~= "Knife" then
		if context.AdsAlpha < NOSCOPE_MAX_ADS then
			table.insert(tags, "NOSCOPE")
		elseif context.AdsAlpha >= 1 and context.ScopedFor <= QUICKSCOPE_WINDOW then
			table.insert(tags, "QUICKSCOPE")
		end
	end
	if context and context.Airborne then
		table.insert(tags, "AIRSHOT")
	end
	if context and context.Overflow then
		table.insert(tags, "FLOW KILL")
	end
	if distance >= LONGSHOT_DISTANCE then
		table.insert(tags, "LONGSHOT")
	end
	return tags
end

return KillTags
