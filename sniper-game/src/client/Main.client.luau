--!strict
-- Client entry point. Starts every controller in order.

local Controllers = script.Parent.Controllers

local MovementController = require(Controllers.MovementController)
local CameraController = require(Controllers.CameraController)
local DebugHud = require(Controllers.DebugHud)

MovementController.Start()
CameraController.Start()
DebugHud.Start()
