--!strict
-- Picks where each player spawns: far from enemies and out of their sight, with a
-- little randomness so spawns aren't predictable. New spawns get a short
-- protection bubble that ends early as soon as they attack.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local MapService = require(script.Parent.MapService)

local SEEN_PENALTY = 250 -- a spawn an enemy can see is treated as this many studs closer
local EYE_HEIGHT = 3

local SpawnService = {}

local random = Random.new()

local function enemyHeads(except: Player): { Vector3 }
	local heads = {}
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local head = character and character:FindFirstChild("Head")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if other ~= except and head and head:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			table.insert(heads, head.Position)
		end
	end
	return heads
end

local function canSee(from: Vector3, to: Vector3, ignore: { Instance }): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return workspace:Raycast(from, to - from, params) == nil
end

function SpawnService.Pick(player: Player): CFrame?
	local spawns = MapService.GetSpawns()
	if #spawns == 0 then
		return nil
	end
	local heads = enemyHeads(player)
	local ignore: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end

	type Scored = { Spawn: SpawnLocation, Score: number }
	local scored: { Scored } = {}
	for _, spawn in spawns do
		local eye = spawn.Position + Vector3.new(0, EYE_HEIGHT, 0)
		local nearest = 1000
		local seen = false
		for _, head in heads do
			nearest = math.min(nearest, (head - eye).Magnitude)
			if not seen and canSee(head, eye, ignore) then
				seen = true
			end
		end
		table.insert(scored, { Spawn = spawn, Score = nearest - (if seen then SEEN_PENALTY else 0) })
	end
	table.sort(scored, function(a, b)
		return a.Score > b.Score
	end)
	local pick = scored[random:NextInteger(1, math.min(MatchConfig.SpawnCandidates, #scored))]
	return pick.Spawn.CFrame + Vector3.new(0, EYE_HEIGHT, 0)
end

local function protect(character: Model)
	local shield = Instance.new("ForceField")
	shield.Name = "SpawnProtection"
	shield.Visible = true
	shield.Parent = character
	task.delay(MatchConfig.SpawnProtection, function()
		if shield.Parent then
			shield:Destroy()
		end
	end)
end

-- Called when a player attacks, so spawn protection can't be abused.
function SpawnService.EndProtection(character: Model)
	local shield = character:FindFirstChild("SpawnProtection")
	if shield then
		shield:Destroy()
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not root then
		return
	end
	local spawnCFrame = SpawnService.Pick(player)
	if spawnCFrame then
		character:PivotTo(spawnCFrame)
	end
	protect(character)
end

function SpawnService.Start()
	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return SpawnService
