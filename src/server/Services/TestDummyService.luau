--!strict
-- Shooting-range dummies for testing alone: standing targets at set distances,
-- strafing targets to test lag compensation, and one behind cover that must never
-- be hittable. Only for the test map; real matches won't have these.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CombatService = require(script.Parent.CombatService)

type DummySpec = {
	Label: string,
	Position: Vector3, -- feet position
	StrafeDistance: number?, -- moves side to side this far from Position
	StrafeSpeed: number?, -- top speed while strafing
}

local DUMMIES: { DummySpec } = {
	{ Label = "50 studs", Position = Vector3.new(0, 0, -50) },
	{ Label = "100 studs", Position = Vector3.new(-20, 0, -100) },
	{ Label = "Strafing 25", Position = Vector3.new(0, 0, -150), StrafeDistance = 30, StrafeSpeed = 25 },
	{ Label = "200 studs", Position = Vector3.new(25, 0, -200) },
	{ Label = "Strafing 48", Position = Vector3.new(0, 0, -250), StrafeDistance = 40, StrafeSpeed = 48 },
	{ Label = "280 studs", Position = Vector3.new(-30, 0, -280) },
	{ Label = "Behind cover", Position = Vector3.new(40, 0, -90) },
}

local RESPAWN_DELAY = 3
local LOOK_AT = Vector3.new(0, 0, 0) -- dummies face the spawn

local TestDummyService = {}

local function spawnDummy(spec: DummySpec)
	local description = Instance.new("HumanoidDescription")
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = "Dummy"

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.DisplayName = spec.Label
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.NameDisplayDistance = 400
	humanoid.HealthDisplayDistance = 400
	root.Anchored = true

	local standHeight = humanoid.HipHeight + root.Size.Y / 2
	local base = spec.Position + Vector3.new(0, standHeight, 0)
	local facing = Vector3.new(LOOK_AT.X, base.Y, LOOK_AT.Z)
	model:PivotTo(CFrame.lookAt(base, facing))
	model.Parent = workspace
	CombatService.RegisterCombatant(model)

	local moveConnection: RBXScriptConnection? = nil
	local distance, speed = spec.StrafeDistance, spec.StrafeSpeed
	if distance and speed then
		-- Sine motion whose peak speed is `speed`.
		local frequency = speed / distance
		local startTime = os.clock()
		local side = CFrame.lookAt(base, facing).RightVector
		moveConnection = RunService.Heartbeat:Connect(function()
			if humanoid.Health <= 0 then
				return
			end
			local offset = side * math.sin((os.clock() - startTime) * frequency) * distance
			root.CFrame = CFrame.lookAt(base + offset, facing + offset)
		end)
	end

	humanoid.Died:Connect(function()
		if moveConnection then
			moveConnection:Disconnect()
		end
		task.delay(RESPAWN_DELAY, function()
			model:Destroy()
			spawnDummy(spec)
		end)
	end)
end

function TestDummyService.Start()
	local map = workspace:FindFirstChild("Map")
	if not map or not map:GetAttribute("IsTestMap") then
		return
	end
	for _, spec in DUMMIES do
		task.spawn(spawnDummy, spec)
	end
end

return TestDummyService
