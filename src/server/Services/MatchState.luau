--!strict
-- Shared flags other services read about the current match, set by MatchService.
-- Kept separate so CombatService can read it without depending on MatchService.

local MatchState = {
	CombatEnabled = true, -- off on the results screen
}

return MatchState
