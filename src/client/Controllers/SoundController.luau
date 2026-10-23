--!strict
-- Plays every game sound by listening to movement and weapon events.
-- Sounds are created once and reused, so nothing is created while playing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Net = require(ReplicatedStorage.Shared.Net)
local SoundConfig = require(ReplicatedStorage.Shared.Config.SoundConfig)
local KnifeController = require(script.Parent.KnifeController)
local MovementController = require(script.Parent.MovementController)
local SettingsController = require(script.Parent.SettingsController)
local WeaponController = require(script.Parent.WeaponController)

local player = Players.LocalPlayer

local VOICES_PER_LAYER = 3 -- how many copies of a sound can overlap
local SPATIAL_VOICES = 6
local HARD_LANDING_SPEED = 45
local SUPPRESSED_VOLUME = 0.35
local BOLT_SOUND_DELAY = 0.18 -- the bolt is worked a moment after the shot

export type Category = "Effects" | "Hits" | "UI"

local SoundController = {}

-- Volume (0..1) for a category, with the master volume applied. Both come from settings.
local CATEGORY_SETTINGS: { [Category]: string } = {
	Effects = "EffectsVolume",
	Hits = "HitsVolume",
	UI = "UiVolume",
}

local function volumeFor(category: Category): number
	return SettingsController.Get(CATEGORY_SETTINGS[category]) * SettingsController.Get("MasterVolume")
end

type Voices = { Sounds: { Sound }, Next: number }

local folder = Instance.new("Folder")
folder.Name = "GameSounds"
local voicesByLayer: { [string]: { Voices } } = {}
local random = Random.new()

local function makeSound(layer: SoundConfig.Layer, parent: Instance): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = layer.Id
	sound.Parent = parent
	return sound
end

local function getVoices(name: string): { Voices }?
	local existing = voicesByLayer[name]
	if existing then
		return existing
	end
	local event = SoundConfig.Events[name]
	if not event then
		warn(`[Sound] no sound named {name}`)
		return nil
	end
	local list = {}
	for _, layer in event do
		local sounds = {}
		for _ = 1, VOICES_PER_LAYER do
			table.insert(sounds, makeSound(layer, folder))
		end
		table.insert(list, { Sounds = sounds, Next = 1 })
	end
	voicesByLayer[name] = list
	return list
end

-- Plays a sound for this player only (not positioned in the world).
function SoundController.Play(name: string, category: Category?, extraPitch: number?)
	local voices = getVoices(name)
	if not voices then
		return
	end
	local categoryVolume = volumeFor(category or "Effects")
	for i, layer in SoundConfig.Events[name] do
		local layerVoices = voices[i]
		local sound = layerVoices.Sounds[layerVoices.Next]
		layerVoices.Next = layerVoices.Next % #layerVoices.Sounds + 1
		local variation = layer.PitchVariation or 0
		sound.PlaybackSpeed = layer.Pitch + (extraPitch or 0) + random:NextNumber(-variation, variation)
		sound.Volume = layer.Volume * categoryVolume
		sound.TimePosition = 0
		sound:Play()
	end
end

-- 3D sounds (other players' shots), each on its own reusable attachment.
type SpatialVoice = { Attachment: Attachment, Sounds: { Sound } }
local spatialVoices: { SpatialVoice } = {}
local nextSpatial = 1

local function ensureSpatialVoices(name: string)
	if #spatialVoices > 0 then
		return
	end
	for _ = 1, SPATIAL_VOICES do
		local attachment = Instance.new("Attachment")
		attachment.Name = "ShotSound"
		local sounds = {}
		for _, layer in SoundConfig.Events[name] do
			local sound = makeSound(layer, attachment)
			sound.RollOffMode = Enum.RollOffMode.InverseTapered
			sound.RollOffMinDistance = 20
			sound.RollOffMaxDistance = SoundConfig.DistantShotRange
			table.insert(sounds, sound)
		end
		attachment.Parent = workspace.Terrain
		table.insert(spatialVoices, { Attachment = attachment, Sounds = sounds })
	end
end

function SoundController.PlayDistantShot(position: Vector3, suppressed: boolean)
	ensureSpatialVoices("DistantShot")
	local voice = spatialVoices[nextSpatial]
	nextSpatial = nextSpatial % #spatialVoices + 1
	voice.Attachment.WorldPosition = position
	local volume = volumeFor("Effects") * (if suppressed then SUPPRESSED_VOLUME else 1)
	for i, layer in SoundConfig.Events.DistantShot do
		local sound = voice.Sounds[i]
		local variation = layer.PitchVariation or 0
		sound.PlaybackSpeed = layer.Pitch + random:NextNumber(-variation, variation)
		sound.Volume = layer.Volume * volume
		sound.TimePosition = 0
		sound:Play()
	end
end

local function headshotPitch(): number
	local streak = math.max(0, WeaponController.State.HeadshotStreak - 1)
	return math.min(streak * SoundConfig.HeadshotStreakPitchStep, SoundConfig.HeadshotStreakPitchMax)
end

function SoundController.Start()
	folder.Parent = SoundService

	WeaponController.Fired:Connect(function()
		SoundController.Play("Fire")
	end)
	WeaponController.BoltStarted:Connect(function()
		task.delay(BOLT_SOUND_DELAY, SoundController.Play, "Bolt")
	end)
	WeaponController.ReloadStarted:Connect(function()
		SoundController.Play("ReloadStart")
	end)
	WeaponController.ReloadFinished:Connect(function()
		SoundController.Play("ReloadFinish")
	end)
	WeaponController.ScopedIn:Connect(function()
		SoundController.Play("ScopeIn")
	end)
	WeaponController.Hit:Connect(function(zone: string, killed: boolean)
		if killed then
			SoundController.Play("Kill", "Hits")
		elseif zone == "Head" then
			SoundController.Play("Headshot", "Hits", headshotPitch())
		else
			SoundController.Play("HitBody", "Hits")
		end
	end)
	WeaponController.Killed:Connect(function(result: any)
		if table.find(result.Tags, "SLICE") or table.find(result.Tags, "KNIFED") then
			SoundController.Play("Slice", "Hits")
		end
		if table.find(result.Tags, "FLOW KILL") then
			SoundController.Play("FlowKill", "Hits")
		end
	end)
	WeaponController.Damaged:Connect(function()
		SoundController.Play("Damaged")
	end)
	WeaponController.EquipChanged:Connect(function()
		SoundController.Play("Equip")
	end)
	KnifeController.Swung:Connect(function(kind: string)
		SoundController.Play(if kind == "Lunge" then "KnifeLunge" else "KnifeSwing")
	end)

	MovementController.Jumped:Connect(function(kind: string)
		SoundController.Play(if kind == "PerfectHop" then "PerfectHop" else "Jump")
	end)
	MovementController.Landed:Connect(function(fallSpeed: number)
		-- Roblox already plays a normal landing sound; this adds weight to big drops.
		if fallSpeed >= HARD_LANDING_SPEED then
			SoundController.Play("Land")
		end
	end)
	MovementController.SlideStarted:Connect(function()
		SoundController.Play("Slide")
	end)
	MovementController.WallKicked:Connect(function()
		SoundController.Play("WallKick")
	end)
	MovementController.SlingshotLaunched:Connect(function()
		SoundController.Play("Slingshot")
	end)
	MovementController.OverflowStarted:Connect(function()
		SoundController.Play("OverflowStart")
	end)

	Net.Event(Net.Names.ShotEffect).OnClientEvent:Connect(function(effect: any)
		if typeof(effect) == "table" and typeof(effect.Origin) == "Vector3" then
			SoundController.PlayDistantShot(effect.Origin, effect.Suppressed == true)
		end
	end)

	-- Wind loop that rises with speed.
	local windConfig = SoundConfig.Wind
	local wind = Instance.new("Sound")
	wind.Name = "Wind"
	wind.SoundId = windConfig.Id
	wind.Looped = true
	wind.Volume = 0
	wind.Parent = folder
	wind:Play()
	RunService.RenderStepped:Connect(function(dt)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local speed = if humanoid and humanoid.Health > 0 then MovementController.State.Speed else 0
		local alpha = math.clamp((speed - windConfig.MinSpeed) / (windConfig.MaxSpeed - windConfig.MinSpeed), 0, 1)
		local target = alpha * windConfig.MaxVolume * volumeFor("Effects")
		wind.Volume += (target - wind.Volume) * (1 - math.exp(-6 * dt))
		wind.PlaybackSpeed = 0.8 + alpha * 0.5
	end)
end

return SoundController
