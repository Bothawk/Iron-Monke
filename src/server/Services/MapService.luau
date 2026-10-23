--!strict
-- Loads and unloads maps. Each map module in src/server/Maps builds itself into a
-- "Map" folder in Workspace. Also kills anyone who falls below the map.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local LightingService = require(script.Parent.LightingService)
local TestDummyService = require(script.Parent.TestDummyService)

export type MapModule = {
	Id: string,
	DisplayName: string,
	KillY: number,
	HasDummies: boolean,
	Lighting: LightingService.Preset,
	Build: (map: Folder) -> (),
}

local Maps = script.Parent.Parent.Maps
local MAPS: { [string]: MapModule } = {
	CinderTerraces = require(Maps.CinderTerraces) :: any,
	TestRange = require(Maps.TestRange) :: any,
}

local MapService = {}

local current: MapModule? = nil
local currentFolder: Folder? = nil
local killFeed = Net.Event(Net.Names.KillFeed)

function MapService.Get(id: string): MapModule?
	return MAPS[id]
end

function MapService.GetCurrent(): MapModule?
	return current
end

function MapService.GetSpawns(): { SpawnLocation }
	local spawns = {}
	local folder = currentFolder and currentFolder:FindFirstChild("Spawns")
	if folder then
		for _, spawn in folder:GetChildren() do
			if spawn:IsA("SpawnLocation") then
				table.insert(spawns, spawn)
			end
		end
	end
	return spawns
end

function MapService.Load(id: string)
	local map = MAPS[id]
	if not map then
		warn(`[MapService] no map called {id}`)
		return
	end

	TestDummyService.Stop()
	if currentFolder then
		currentFolder:Destroy()
	end
	-- Anything a Baseplate template or an earlier map left behind.
	for _, name in { "Map", "Baseplate", "SpawnLocation" } do
		local leftover = workspace:FindFirstChild(name)
		if leftover then
			leftover:Destroy()
		end
	end
	workspace.Terrain:Clear()

	local folder = Instance.new("Folder")
	folder.Name = "Map"
	folder:SetAttribute("MapId", map.Id)
	folder:SetAttribute("DisplayName", map.DisplayName)
	map.Build(folder)
	folder.Parent = workspace
	currentFolder = folder
	current = map

	LightingService.Apply(map.Lighting)
	if map.HasDummies then
		TestDummyService.Start(folder)
	end
end

function MapService.Start()
	-- Falling below the map counts as a death.
	RunService.Heartbeat:Connect(function()
		local map = current
		if not map then
			return
		end
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 and root.Position.Y < map.KillY then
				humanoid.Health = 0
				killFeed:FireAllClients({
					Killer = "",
					KillerUserId = 0,
					Victim = player.DisplayName,
					VictimUserId = player.UserId,
					Weapon = "FELL",
					Tags = {},
				})
			end
		end
	end)
end

return MapService
