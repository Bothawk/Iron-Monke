--!strict
-- The flashy inspect animation (F). Each weapon's style says how it spins and
-- whether it's tossed. Over the inspect the weapon is:
--   0.00–0.15  brought up and turned toward the camera
--   0.15–0.70  spun (and tossed up and caught, for styles with a toss)
--   0.70–0.88  settled, with an optional bolt rack
--   0.88–1.00  lowered back to the normal hold
-- Returns the extra motion for the weapon only (the hands stay put), how far the
-- bolt is pulled, and how strongly the accent parts should glow.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)

local PRESENT = CFrame.new(-0.35, 0.3, 0.25) * CFrame.Angles(math.rad(12), math.rad(-38), math.rad(28))

local Inspect = {}

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Overshoots slightly before settling, for a snappy catch.
local function backOut(x: number): number
	x = math.clamp(x, 0, 1)
	local s = 1.6
	return 1 + (s + 1) * (x - 1) ^ 3 + s * (x - 1) ^ 2
end

local function phase(u: number, from: number, to: number): number
	return math.clamp((u - from) / (to - from), 0, 1)
end

function Inspect.Pose(style: WeaponConfig.InspectStyle, elapsed: number): (CFrame, number, number)
	local u = elapsed / style.Duration
	if u <= 0 or u >= 1 then
		return CFrame.identity, 0, 0
	end

	-- Presenting weight: up in the first part, back down at the end.
	local present = smooth(phase(u, 0, 0.15)) * (1 - smooth(phase(u, 0.88, 1)))

	local spinPhase = phase(u, 0.15, 0.7)
	local angle = backOut(spinPhase) * style.Spins * math.pi * 2
	local spin = if style.SpinAxis == "Roll"
		then CFrame.Angles(0, 0, angle)
		elseif style.SpinAxis == "Yaw" then CFrame.Angles(0, angle, 0)
		else CFrame.Angles(angle, 0, 0)
	local toss = math.sin(spinPhase * math.pi) * style.TossHeight

	local bolt = if style.BoltRack then math.sin(phase(u, 0.72, 0.88) * math.pi) else 0
	-- Glows hardest mid-spin and flashes again on the bolt rack.
	local glow = math.max(math.sin(spinPhase * math.pi), bolt * 0.6)

	local motion = CFrame.identity:Lerp(PRESENT, present) * CFrame.new(0, toss, 0) * spin
	return motion, bolt, glow
end

return Inspect
