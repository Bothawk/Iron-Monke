--!strict
-- Server entry point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.MovementConfig)
local Services = script.Parent.Services

local AntiCheatService = require(Services.AntiCheatService)
local TestMapBuilder = require(Services.TestMapBuilder)

workspace.Gravity = Config.Gravity

TestMapBuilder.Build()
AntiCheatService.Start()
