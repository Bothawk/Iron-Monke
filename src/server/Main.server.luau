--!strict
-- Server entry point. MatchService loads the first map and runs the match loop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.MovementConfig)
local Services = script.Parent.Services

local AntiCheatService = require(Services.AntiCheatService)
local CombatService = require(Services.CombatService)
local LagCompensation = require(Services.LagCompensation)
local LightingService = require(Services.LightingService)
local MapService = require(Services.MapService)
local MatchService = require(Services.MatchService)
local SpawnService = require(Services.SpawnService)
local StatsService = require(Services.StatsService)
local WorldWeaponService = require(Services.WorldWeaponService)

workspace.Gravity = Config.Gravity

LightingService.Start()
MapService.Start()
AntiCheatService.Start()
LagCompensation.Start()
StatsService.Start()
SpawnService.Start()
CombatService.Start()
WorldWeaponService.Start()
MatchService.Start()
