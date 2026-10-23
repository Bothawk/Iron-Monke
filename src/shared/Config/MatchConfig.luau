--!strict
-- Match rules and the map rotation.

local MatchConfig = {
	Mode = "FREE-FOR-ALL",
	KillTarget = 25, -- first to this many kills wins
	Duration = 8 * 60, -- or the most kills when time runs out
	ResultsTime = 8, -- results screen, no combat
	IntermissionTime = 15, -- warm-up and map vote before the next match

	FirstMap = "CinderTerraces",
	-- Every map players can vote for. Ids match the modules in src/server/Maps.
	Maps = { "CinderTerraces", "TestRange" },

	SpawnProtection = 1.5, -- seconds of protection after spawning, ended early by attacking
	SpawnCandidates = 6, -- how many of the best spawns to pick between at random
}

return MatchConfig
