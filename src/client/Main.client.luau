--!strict
-- Client entry point. Starts every controller in order.

local Controllers = script.Parent.Controllers

local MovementController = require(Controllers.MovementController)
local WeaponController = require(Controllers.WeaponController)
local CameraController = require(Controllers.CameraController)
local SoundController = require(Controllers.SoundController)
local EffectsController = require(Controllers.EffectsController)
local CharacterPoseController = require(Controllers.CharacterPoseController)
local WeaponHud = require(Controllers.WeaponHud)
local FlowHud = require(Controllers.FlowHud)
local DebugHud = require(Controllers.DebugHud)

MovementController.Start()
WeaponController.Start()
CameraController.Start()
SoundController.Start()
EffectsController.Start()
CharacterPoseController.Start()
WeaponHud.Start()
FlowHud.Start()
DebugHud.Start()
