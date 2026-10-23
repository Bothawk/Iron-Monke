--!strict
-- Client entry point. Hides the default Roblox HUD pieces this game replaces, then
-- starts every controller.

local StarterGui = game:GetService("StarterGui")

local Controllers = script.Parent.Controllers

local MovementController = require(Controllers.MovementController)
local WeaponController = require(Controllers.WeaponController)
local KnifeController = require(Controllers.KnifeController)
local CameraController = require(Controllers.CameraController)
local SoundController = require(Controllers.SoundController)
local EffectsController = require(Controllers.EffectsController)
local CharacterPoseController = require(Controllers.CharacterPoseController)
local DeathCamController = require(Controllers.DeathCamController)
local WeaponHud = require(Controllers.WeaponHud)
local FlowHud = require(Controllers.FlowHud)
local KillFeedHud = require(Controllers.KillFeedHud)
local ScoreboardHud = require(Controllers.ScoreboardHud)
local DebugHud = require(Controllers.DebugHud)

for _, coreGui in { Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Health, Enum.CoreGuiType.Backpack } do
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreGui, false)
end

MovementController.Start()
WeaponController.Start()
KnifeController.Start()
CameraController.Start()
SoundController.Start()
EffectsController.Start()
CharacterPoseController.Start()
DeathCamController.Start()
WeaponHud.Start()
FlowHud.Start()
KillFeedHud.Start()
ScoreboardHud.Start()
DebugHud.Start()
