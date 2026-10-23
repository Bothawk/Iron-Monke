--!strict
-- This player's saved profile (coins, owned weapons, loadouts, unlock progress and
-- lifetime stats) as last sent by the server, plus the loadout for the current life.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local WeaponStats = require(ReplicatedStorage.Shared.Combat.WeaponStats)

local ProfileController = {}

ProfileController.Changed = Signal.new() -- (profile) whenever the server sends an update
ProfileController.LoadoutChanged = Signal.new() -- (stats: WeaponStats.Stats) the weapon for this life
ProfileController.CoinsEarned = Signal.new() -- (amount: number, reason: string)
ProfileController.ShopResult = Signal.new() -- (ok: boolean, message: string)

local profile: any = nil
local lifeStats: WeaponStats.Stats = WeaponStats.Compute(WeaponConfig.DefaultWeapon, nil)

function ProfileController.Get(): any
	return profile
end

-- Stats of the sniper being used this life.
function ProfileController.GetLifeStats(): WeaponStats.Stats
	return lifeStats
end

function ProfileController.ShopAction(action: string, a: string?, b: string?)
	Net.Event(Net.Names.ShopAction):FireServer(action, a, b)
end

function ProfileController.Start()
	Net.Event(Net.Names.ProfileUpdated).OnClientEvent:Connect(function(data: any)
		if typeof(data) == "table" then
			profile = data
			ProfileController.Changed:Fire(data)
		end
	end)
	Net.Event(Net.Names.Loadout).OnClientEvent:Connect(function(data: any)
		if typeof(data) == "table" and typeof(data.WeaponId) == "string" then
			lifeStats = WeaponStats.Compute(data.WeaponId, data.Attachments)
			ProfileController.LoadoutChanged:Fire(lifeStats)
		end
	end)
	Net.Event(Net.Names.CoinsEarned).OnClientEvent:Connect(function(data: any)
		if typeof(data) == "table" and typeof(data.Amount) == "number" then
			ProfileController.CoinsEarned:Fire(data.Amount, tostring(data.Reason or ""))
		end
	end)
	Net.Event(Net.Names.ShopResult).OnClientEvent:Connect(function(data: any)
		if typeof(data) == "table" then
			ProfileController.ShopResult:Fire(data.Ok == true, tostring(data.Message or ""))
		end
	end)
	-- Ask once listening, in case the server's first push arrived before this.
	Net.Event(Net.Names.RequestProfile):FireServer()
end

return ProfileController
