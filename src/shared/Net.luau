--!strict
-- RemoteEvents by name. The server creates them; clients wait for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local Net = {}

Net.Names = {
	FireShot = "FireShot", -- client → server: origin, direction, shotTime, victim?, partName?
	Reload = "Reload", -- client → server
	ShotResult = "ShotResult", -- server → shooter: confirmed hit
	TookDamage = "TookDamage", -- server → victim
	ShotEffect = "ShotEffect", -- server → other clients: tracer to draw
	Equip = "Equip", -- client → server: slot
	MeleeHit = "MeleeHit", -- client → server: kind, victim, attackTime
	KillFeed = "KillFeed", -- server → everyone: who killed whom
	MatchVote = "MatchVote", -- client → server: map id
	MatchResults = "MatchResults", -- server → everyone: final standings
	RequestProfile = "RequestProfile", -- client → server: send my profile again
	ProfileUpdated = "ProfileUpdated", -- server → owner: the saved profile
	SettingsLoaded = "SettingsLoaded", -- server → owner: saved settings
	SaveSettings = "SaveSettings", -- client → server: changed settings
	CoinsEarned = "CoinsEarned", -- server → owner: amount and reason, for the popup
	ShopAction = "ShopAction", -- client → server: buy or equip weapons and attachments
	ShopResult = "ShopResult", -- server → owner: whether it worked and why not
	Loadout = "Loadout", -- server → owner: weapon and attachments for this life
}

local function getFolder(): Instance
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder :: Instance
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

function Net.Event(name: string): RemoteEvent
	local folder = getFolder()
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing :: RemoteEvent
		end
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
		return event
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

return Net
