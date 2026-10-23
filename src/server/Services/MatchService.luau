--!strict
-- Runs the match loop: warm-up and map vote → Free-For-All match (first to the kill
-- target, or most kills when time runs out) → results → repeat.
-- Match state is shared with clients as attributes on ReplicatedStorage.Match:
--   Phase ("Intermission" | "Playing" | "Results"), PhaseEndsAt (server time),
--   Mode, KillTarget, MapId, MapName, LeaderName, LeaderKills, Winner,
--   VoteOptions (comma separated map ids) and Votes_<mapId>.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)
local MatchState = require(script.Parent.MatchState)
local PlayService = require(script.Parent.PlayService)
local StatsService = require(script.Parent.StatsService)

local STANDINGS_SHOWN = 8

local MatchService = {}

local matchFolder = Instance.new("Folder")
matchFolder.Name = "Match"
local votes: { [Player]: string } = {}
local voteEvent = Net.Event(Net.Names.MatchVote)
local resultsEvent = Net.Event(Net.Names.MatchResults)
local random = Random.new()

local function kills(player: Player): number
	local value = player:GetAttribute("Kills")
	return if typeof(value) == "number" then value else 0
end

local function setPhase(phase: string, duration: number)
	MatchState.Phase = phase
	matchFolder:SetAttribute("Phase", phase)
	matchFolder:SetAttribute("PhaseEndsAt", workspace:GetServerTimeNow() + duration)
end

-- Players who are in the match (not still on the main menu), best first.
local function sortedPlayers(): { Player }
	local players = {}
	for _, player in Players:GetPlayers() do
		if PlayService.IsInGame(player) then
			table.insert(players, player)
		end
	end
	table.sort(players, function(a, b)
		if kills(a) ~= kills(b) then
			return kills(a) > kills(b)
		end
		return (a:GetAttribute("Deaths") or 0) < (b:GetAttribute("Deaths") or 0)
	end)
	return players
end

local function updateLeader()
	local leader = sortedPlayers()[1]
	matchFolder:SetAttribute("LeaderName", if leader and kills(leader) > 0 then leader.DisplayName else "")
	matchFolder:SetAttribute("LeaderKills", if leader then kills(leader) else 0)
end

local function recountVotes()
	local counts: { [string]: number } = {}
	for _, mapId in MatchConfig.Maps do
		counts[mapId] = 0
	end
	for player, mapId in votes do
		if player.Parent and counts[mapId] then
			counts[mapId] += 1
		end
	end
	for mapId, count in counts do
		matchFolder:SetAttribute(`Votes_{mapId}`, count)
	end
	return counts
end

-- The map with the most votes; ties are broken at random. With no votes, the map
-- rotates to the next one so the same map doesn't repeat forever.
local function chooseMap(): string
	local counts = recountVotes()
	local best, tied = -1, {}
	for _, mapId in MatchConfig.Maps do
		local count = counts[mapId]
		if count > best then
			best, tied = count, { mapId }
		elseif count == best then
			table.insert(tied, mapId)
		end
	end
	if best <= 0 then
		local currentMap = MapService.GetCurrent()
		local index = currentMap and table.find(MatchConfig.Maps, currentMap.Id) or 0
		return MatchConfig.Maps[index % #MatchConfig.Maps + 1]
	end
	return tied[random:NextInteger(1, #tied)]
end

local function loadMap(mapId: string)
	MapService.Load(mapId)
	local map = MapService.GetCurrent()
	matchFolder:SetAttribute("MapId", mapId)
	matchFolder:SetAttribute("MapName", if map then map.DisplayName else mapId)
end

-- Everyone who's playing (not still in the main menu) gets a fresh spawn.
local function respawnEveryone()
	for _, player in Players:GetPlayers() do
		task.spawn(PlayService.Spawn, player)
	end
end

local function anyoneInGame(): boolean
	for _, player in Players:GetPlayers() do
		if PlayService.IsInGame(player) then
			return true
		end
	end
	return false
end

local function intermission()
	-- Votes cast on the results screen carry over into the warm-up.
	matchFolder:SetAttribute("VoteOptions", table.concat(MatchConfig.Maps, ","))
	recountVotes()
	setPhase("Intermission", MatchConfig.IntermissionTime)
	task.wait(MatchConfig.IntermissionTime)
	-- Don't start a match for an empty server; keep warming up until someone plays.
	while not anyoneInGame() do
		setPhase("Intermission", MatchConfig.IntermissionTime)
		task.wait(MatchConfig.IntermissionTime)
	end
end

local function playMatch()
	for _, player in Players:GetPlayers() do
		StatsService.Reset(player)
	end
	updateLeader()
	matchFolder:SetAttribute("Winner", "")
	MatchState.CombatEnabled = true
	MatchState.FirstBloodTaken = false
	respawnEveryone()
	setPhase("Playing", MatchConfig.Duration)

	local endsAt = os.clock() + MatchConfig.Duration
	local winner: Player? = nil
	local disconnect = StatsService.KillRecorded:Connect(function(killer: Player)
		updateLeader()
		if not winner and kills(killer) >= MatchConfig.KillTarget then
			winner = killer
		end
	end)
	while not winner and os.clock() < endsAt do
		task.wait(0.2)
	end
	disconnect()

	-- Out of time: whoever has the most kills wins (nobody, if nobody scored).
	local ranked = sortedPlayers()
	if not winner and ranked[1] and kills(ranked[1]) > 0 then
		winner = ranked[1]
	end

	MatchState.CombatEnabled = false
	for place, player in ranked do
		local scored = kills(player) > 0
		local won = player == winner
		if won then
			DataService.AddCoins(player, MatchConfig.Rewards.Win, "MATCH WON")
		elseif place <= 3 and scored then
			DataService.AddCoins(player, MatchConfig.Rewards.TopThree, `TOP 3 (#{place})`)
		end
		DataService.Update(player, function(profile)
			profile.Stats.MatchesPlayed += 1
			if won then
				profile.Stats.Wins += 1
			end
		end)
	end
	local standings = {}
	for i = 1, math.min(STANDINGS_SHOWN, #ranked) do
		local player = ranked[i]
		table.insert(standings, {
			Name = player.DisplayName,
			UserId = player.UserId,
			Kills = kills(player),
			Deaths = player:GetAttribute("Deaths") or 0,
			Headshots = player:GetAttribute("Headshots") or 0,
			BestStreak = player:GetAttribute("BestStreak") or 0,
		})
	end
	local finalWinner = winner
	matchFolder:SetAttribute("Winner", if finalWinner then finalWinner.DisplayName else "")
	resultsEvent:FireAllClients({
		Winner = if finalWinner then finalWinner.DisplayName else "",
		WinnerUserId = if finalWinner then finalWinner.UserId else 0,
		MapName = matchFolder:GetAttribute("MapName"),
		Standings = standings,
	})
	table.clear(votes)
	recountVotes()
	setPhase("Results", MatchConfig.ResultsTime)
	task.wait(MatchConfig.ResultsTime)
	MatchState.CombatEnabled = true
end

function MatchService.Start()
	matchFolder:SetAttribute("Mode", MatchConfig.Mode)
	matchFolder:SetAttribute("KillTarget", MatchConfig.KillTarget)
	matchFolder.Parent = ReplicatedStorage

	voteEvent.OnServerEvent:Connect(function(player: Player, mapId: any)
		local phase = matchFolder:GetAttribute("Phase")
		if (phase ~= "Intermission" and phase ~= "Results") or typeof(mapId) ~= "string" then
			return
		end
		if table.find(MatchConfig.Maps, mapId) then
			votes[player] = mapId
			recountVotes()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		votes[player] = nil
		recountVotes()
		updateLeader()
	end)

	task.spawn(function()
		loadMap(MatchConfig.FirstMap)
		respawnEveryone()
		while true do
			intermission()
			local nextMap = chooseMap()
			local currentMap = MapService.GetCurrent()
			if not currentMap or currentMap.Id ~= nextMap then
				loadMap(nextMap)
			end
			playMatch()
		end
	end)
end

return MatchService
