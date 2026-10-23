--!strict
-- Server-side speed check. Each client controls its own movement, so the server
-- samples positions and pulls a player back if they keep moving faster than the
-- game allows.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.MovementConfig)
local Settings = Config.AntiCheat

type Tracker = {
	LastPosition: Vector3?,
	LastValidCFrame: CFrame?,
	Violations: { number },
}

local AntiCheatService = {}

local trackers: { [Player]: Tracker } = {}

local function resetTracker(player: Player)
	trackers[player] = { LastPosition = nil, LastValidCFrame = nil, Violations = {} }
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function check(player: Player, tracker: Tracker, sampleDt: number, maxAllowed: number)
	local root = getRoot(player)
	if not root then
		return
	end

	local position = root.Position
	local lastPosition = tracker.LastPosition
	if lastPosition then
		local delta = position - lastPosition
		local horizontalSpeed = Vector3.new(delta.X, 0, delta.Z).Magnitude / sampleDt

		if horizontalSpeed > maxAllowed then
			local now = os.clock()
			table.insert(tracker.Violations, now)
			while tracker.Violations[1] and now - tracker.Violations[1] > Settings.ViolationWindow do
				table.remove(tracker.Violations, 1)
			end

			local lastValid = tracker.LastValidCFrame
			if #tracker.Violations >= Settings.ViolationsToRubberBand and lastValid then
				warn(
					string.format(
						"[AntiCheat] %s moved %.1f studs/s (max %.1f), pulled back",
						player.Name,
						horizontalSpeed,
						maxAllowed
					)
				)
				root.CFrame = lastValid
				root.AssemblyLinearVelocity = Vector3.zero
				table.clear(tracker.Violations)
				position = lastValid.Position
			end
		else
			tracker.LastValidCFrame = root.CFrame
		end
	end
	tracker.LastPosition = position
end

function AntiCheatService.Start()
	local function onPlayerAdded(player: Player)
		resetTracker(player)
		-- A respawn is a legitimate teleport, so start fresh.
		player.CharacterAdded:Connect(function()
			resetTracker(player)
		end)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		trackers[player] = nil
	end)

	local maxAllowed = Config.MaxSpeedCap * Settings.Tolerance + Settings.Leeway
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < Settings.SampleInterval then
			return
		end
		local sampleDt = elapsed
		elapsed = 0
		for player, tracker in trackers do
			check(player, tracker, sampleDt, maxAllowed)
		end
	end)
end

return AntiCheatService
