--!strict
-- Damped spring for smooth camera and viewmodel motion.

local Spring = {}
Spring.__index = Spring

export type Spring = typeof(setmetatable(
	{} :: {
		Position: number,
		Velocity: number,
		Target: number,
		Stiffness: number,
		Damping: number,
	},
	Spring
))

local MAX_STEP = 1 / 240

function Spring.new(initial: number, stiffness: number, damping: number): Spring
	return setmetatable({
		Position = initial,
		Velocity = 0,
		Target = initial,
		Stiffness = stiffness,
		Damping = damping,
	}, Spring)
end

function Spring.Update(self: Spring, dt: number): number
	-- Small fixed substeps keep the spring stable when the frame rate drops.
	local steps = math.max(1, math.ceil(dt / MAX_STEP))
	local h = dt / steps
	local dampingForce = 2 * self.Damping * math.sqrt(self.Stiffness)
	for _ = 1, steps do
		local accel = self.Stiffness * (self.Target - self.Position) - dampingForce * self.Velocity
		self.Velocity += accel * h
		self.Position += self.Velocity * h
	end
	return self.Position
end

function Spring.Impulse(self: Spring, velocity: number)
	self.Velocity += velocity
end

return Spring
