--!strict
-- Client entry point. Hides the default Roblox HUD pieces this game replaces, then
-- starts every controller. Settings and the profile start first since almost
-- everything else reads them.

local StarterGui = game:GetService("StarterGui")

local Controllers = script.Parent.Controllers

local SettingsController = require(Controllers.SettingsController)
local ProfileController = require(Controllers.ProfileController)
local MovementController = require(Controllers.MovementController)
local WeaponController = require(Controllers.WeaponController)
local KnifeController = require(Controllers.KnifeController)
local CameraController = require(Controllers.CameraController)
local GraphicsController = require(Controllers.GraphicsController)
local SoundController = require(Controllers.SoundController)
local EffectsController = require(Controllers.EffectsController)
local CharacterPoseController = require(Controllers.CharacterPoseController)
local DeathCamController = require(Controllers.DeathCamController)
local WeaponHud = require(Controllers.WeaponHud)
local FlowHud = require(Controllers.FlowHud)
local KillFeedHud = require(Controllers.KillFeedHud)
local MatchHud = require(Controllers.MatchHud)
local ScoreboardHud = require(Controllers.ScoreboardHud)
local MenuController = require(Controllers.MenuController)
local MainMenuController = require(Controllers.MainMenuController)
local TouchController = require(Controllers.TouchController)
local DebugHud = require(Controllers.DebugHud)

for _, coreGui in { Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Health, Enum.CoreGuiType.Backpack } do
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreGui, false)
end

SettingsController.Start()
ProfileController.Start()
MovementController.Start()
WeaponController.Start()
KnifeController.Start()
CameraController.Start()
GraphicsController.Start()
SoundController.Start()
EffectsController.Start()
CharacterPoseController.Start()
DeathCamController.Start()
WeaponHud.Start()
FlowHud.Start()
KillFeedHud.Start()
MatchHud.Start()
ScoreboardHud.Start()
MenuController.Start()
MainMenuController.Start()
TouchController.Start()
DebugHud.Start()
