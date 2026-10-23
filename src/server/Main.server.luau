--!strict
-- Server entry point. MatchService loads the first map and runs the match loop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.MovementConfig)
local Services = script.Parent.Services

local AntiCheatService = require(Services.AntiCheatService)
local CombatService = require(Services.CombatService)
local DataService = require(Services.DataService)
local LagCompensation = require(Services.LagCompensation)
local LightingService = require(Services.LightingService)
local MapService = require(Services.MapService)
local MatchService = require(Services.MatchService)
local PlayService = require(Services.PlayService)
local ShopService = require(Services.ShopService)
local SpawnService = require(Services.SpawnService)
local StatsService = require(Services.StatsService)
local WorldWeaponService = require(Services.WorldWeaponService)

workspace.Gravity = Config.Gravity

DataService.Start()
PlayService.Start()
ShopService.Start()
LightingService.Start()
MapService.Start()
AntiCheatService.Start()
LagCompensation.Start()
StatsService.Start()
SpawnService.Start()
CombatService.Start()
WorldWeaponService.Start()
MatchService.Start()
