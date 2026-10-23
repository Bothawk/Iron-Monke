--!strict
-- Holds this player's settings. Other controllers read them with Get and react to
-- Changed. Values arrive from the server's saved profile, and changes are sent back
-- (bundled up, a moment after the last change) so they're saved.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local SettingsConfig = require(ReplicatedStorage.Shared.Config.SettingsConfig)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local SAVE_DELAY = 1.5

local SettingsController = {}

SettingsController.Changed = Signal.new() -- (id: string, value: any)

local values = SettingsConfig.Defaults()
local pending: { [string]: any } = {}
local saveScheduled = false
local saveEvent: RemoteEvent? = nil

function SettingsController.Get(id: string): any
	return values[id]
end

local function flush()
	saveScheduled = false
	if next(pending) == nil or not saveEvent then
		return
	end
	local batch = pending
	pending = {}
	saveEvent:FireServer(batch)
end

function SettingsController.Set(id: string, value: any)
	local clean = SettingsConfig.Sanitize(id, value)
	if clean == nil or values[id] == clean then
		return
	end
	values[id] = clean
	pending[id] = clean
	SettingsController.Changed:Fire(id, clean)
	if not saveScheduled then
		saveScheduled = true
		task.delay(SAVE_DELAY, flush)
	end
end

function SettingsController.ResetCategory(category: string)
	for _, setting in SettingsConfig.List do
		if setting.Category == category then
			SettingsController.Set(setting.Id, setting.Default)
		end
	end
end

-- Replaces everything with the saved values from the server.
local function load(saved: any)
	local merged = SettingsConfig.Merge(saved)
	for id, value in merged do
		if values[id] ~= value then
			values[id] = value
			SettingsController.Changed:Fire(id, value)
		end
	end
end

function SettingsController.Start()
	saveEvent = Net.Event(Net.Names.SaveSettings)
	Net.Event(Net.Names.SettingsLoaded).OnClientEvent:Connect(load)
end

return SettingsController
