--!strict
-- Server entry point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.MovementConfig)
local Services = script.Parent.Services

local AntiCheatService = require(Services.AntiCheatService)
local CombatService = require(Services.CombatService)
local LagCompensation = require(Services.LagCompensation)
local LightingService = require(Services.LightingService)
local StatsService = require(Services.StatsService)
local TestDummyService = require(Services.TestDummyService)
local TestMapBuilder = require(Services.TestMapBuilder)
local WorldWeaponService = require(Services.WorldWeaponService)

workspace.Gravity = Config.Gravity

LightingService.Start()
TestMapBuilder.Build()
AntiCheatService.Start()
LagCompensation.Start()
StatsService.Start()
CombatService.Start()
WorldWeaponService.Start()
TestDummyService.Start()
