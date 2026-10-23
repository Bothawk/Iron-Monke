--!strict
-- Players start on the main menu with no character. Pressing PLAY spawns them, and
-- from then on they respawn a few seconds after each death. Doing it here (instead
-- of Roblox's automatic spawning) means nobody can be shot while still in the menu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)

local PlayService = {}

-- Spawns a player who has pressed PLAY. Safe to call any time.
function PlayService.Spawn(player: Player)
	if player.Parent and player:GetAttribute("InGame") then
		player:LoadCharacter()
	end
end

function PlayService.IsInGame(player: Player): boolean
	return player:GetAttribute("InGame") == true
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		task.delay(WeaponConfig.RespawnTime, function()
			-- Only respawn if nothing else (a new match) already did.
			if player.Character == character then
				PlayService.Spawn(player)
			end
		end)
	end)
end

function PlayService.Start()
	Players.CharacterAutoLoads = false

	local function onPlayerAdded(player: Player)
		player:SetAttribute("InGame", false)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Net.Event(Net.Names.PlayRequest).OnServerEvent:Connect(function(player)
		if PlayService.IsInGame(player) then
			return
		end
		player:SetAttribute("InGame", true)
		PlayService.Spawn(player)
	end)
end

return PlayService
