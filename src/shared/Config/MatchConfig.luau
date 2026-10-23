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

	-- Coins. Only kills during a match pay, and only for tags the server can check.
	Rewards = {
		Kill = 25,
		Headshot = 15,
		Longshot = 10,
		Slice = 20,
		Win = 150,
		TopThree = 75, -- 2nd and 3rd place
	},

	-- Test Range dummies normally give no coins, stats or unlock progress. Turn this
	-- on to test the economy alone in Studio.
	DummyKillsCount = false,

	SpawnProtection = 1.5, -- seconds of protection after spawning, ended early by attacking
	SpawnCandidates = 6, -- how many of the best spawns to pick between at random
}

return MatchConfig
