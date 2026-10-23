--!strict
-- Shared flags other services read about the current match, set by MatchService.
-- Kept separate so CombatService can read it without depending on MatchService.

local MatchState = {
	Phase = "Intermission", -- "Intermission" | "Playing" | "Results"
	CombatEnabled = true, -- off on the results screen
	FirstBloodTaken = false, -- reset at the start of every match
}

return MatchState
