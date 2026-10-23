--!strict
-- Client entry point. Starts every controller in order.

local Controllers = script.Parent.Controllers

local MovementController = require(Controllers.MovementController)
local WeaponController = require(Controllers.WeaponController)
local CameraController = require(Controllers.CameraController)
local WeaponHud = require(Controllers.WeaponHud)
local DebugHud = require(Controllers.DebugHud)

MovementController.Start()
WeaponController.Start()
CameraController.Start()
WeaponHud.Start()
DebugHud.Start()
