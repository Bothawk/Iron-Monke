--!strict
-- Per-player match stats, stored as attributes on the Player so every client can
-- read them for the scoreboard: Kills, Deaths, Headshots, Streak, BestStreak, Ping.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local DataService = require(script.Parent.DataService)
local MatchState = require(script.Parent.MatchState)

local PING_INTERVAL = 2

local StatsService = {}

StatsService.KillRecorded = Signal.new() -- (killer: Player, victim: Player?, tags: { string })

local STAT_NAMES = { "Kills", "Deaths", "Headshots", "Streak", "BestStreak" }

local function add(player: Player, name: string, amount: number)
	player:SetAttribute(name, (player:GetAttribute(name) or 0) + amount)
end

function StatsService.Reset(player: Player)
	for _, name in STAT_NAMES do
		player:SetAttribute(name, 0)
	end
end

function StatsService.RecordKill(killer: Player, victim: Player?, tags: { string })
	add(killer, "Kills", 1)
	add(killer, "Streak", 1)
	if table.find(tags, "HEADSHOT") then
		add(killer, "Headshots", 1)
	end
	local streak = killer:GetAttribute("Streak") or 0
	if streak > (killer:GetAttribute("BestStreak") or 0) then
		killer:SetAttribute("BestStreak", streak)
	end
	StatsService.KillRecorded:Fire(killer, victim, tags)
end

local function recordDeath(player: Player)
	add(player, "Deaths", 1)
	player:SetAttribute("Streak", 0)
	if MatchState.Phase == "Playing" then
		DataService.Update(player, function(profile)
			profile.Stats.Deaths += 1
		end)
	end
end

function StatsService.Start()
	local function onPlayerAdded(player: Player)
		StatsService.Reset(player)
		player:SetAttribute("Ping", 0)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid") :: Humanoid
			humanoid.Died:Connect(function()
				recordDeath(player)
			end)
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				player:SetAttribute("Ping", math.floor(player:GetNetworkPing() * 1000 + 0.5))
			end
			task.wait(PING_INTERVAL)
		end
	end)
end

return StatsService
