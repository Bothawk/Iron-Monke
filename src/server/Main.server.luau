--!strict
-- Server entry point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.MovementConfig)
local Services = script.Parent.Services

local AntiCheatService = require(Services.AntiCheatService)
local CombatService = require(Services.CombatService)
local LagCompensation = require(Services.LagCompensation)
local TestDummyService = require(Services.TestDummyService)
local TestMapBuilder = require(Services.TestMapBuilder)

workspace.Gravity = Config.Gravity

TestMapBuilder.Build()
AntiCheatService.Start()
LagCompensation.Start()
CombatService.Start()
TestDummyService.Start()
