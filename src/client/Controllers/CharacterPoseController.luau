--!strict
-- Raises every other player's arms into a rifle-aiming pose. There are no uploaded
-- animations yet, so the shoulder joints are turned directly each frame, after
-- Roblox's own animations have run. It only changes what this player sees.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- +90° about X swings an arm from hanging down to pointing forward; the Y turn
-- brings each hand in toward the gun.
local RIGHT_SHOULDER_POSE = CFrame.Angles(0, math.rad(12), 0) * CFrame.Angles(math.rad(90), 0, 0)
local LEFT_SHOULDER_POSE = CFrame.Angles(0, math.rad(-38), 0) * CFrame.Angles(math.rad(90), 0, 0)

local CharacterPoseController = {}

type Rig = { Right: Motor6D, Left: Motor6D }

local rigs: { [Model]: Rig } = {}

local function findMotor(character: Model, partName: string, motorName: string): Motor6D?
	local part = character:FindFirstChild(partName)
	local motor = part and part:FindFirstChild(motorName)
	return if motor and motor:IsA("Motor6D") then motor else nil
end

local function track(character: Model)
	task.spawn(function()
		character:WaitForChild("RightUpperArm", 10)
		character:WaitForChild("LeftUpperArm", 10)
		local right = findMotor(character, "RightUpperArm", "RightShoulder")
		local left = findMotor(character, "LeftUpperArm", "LeftShoulder")
		if right and left and character.Parent then
			rigs[character] = { Right = right, Left = left }
		end
	end)
end

function CharacterPoseController.Start()
	local function onPlayerAdded(other: Player)
		if other == player then
			return
		end
		other.CharacterAdded:Connect(track)
		if other.Character then
			track(other.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, other in Players:GetPlayers() do
		onPlayerAdded(other)
	end

	-- PreSimulation runs after animations are applied, so this pose is what gets drawn.
	RunService.PreSimulation:Connect(function()
		for character, rig in rigs do
			if not character.Parent then
				rigs[character] = nil
				continue
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				rig.Right.Transform = RIGHT_SHOULDER_POSE
				rig.Left.Transform = LEFT_SHOULDER_POSE
			end
		end
	end)
end

return CharacterPoseController
