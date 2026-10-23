--!strict
-- Buying snipers with coins and choosing the loadout. Every request is checked
-- here; the client only asks. Loadout changes take effect on the next spawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local DataService = require(script.Parent.DataService)

local MAX_ACTIONS_PER_SECOND = 10

local ShopService = {}

local actionTimes: { [Player]: { number } } = {}
local shopResult = Net.Event(Net.Names.ShopResult)

local function reply(player: Player, ok: boolean, message: string)
	shopResult:FireClient(player, { Ok = ok, Message = message })
end

local function underRateLimit(player: Player): boolean
	local times = actionTimes[player] or {}
	actionTimes[player] = times
	local now = os.clock()
	while times[1] and now - times[1] > 1 do
		table.remove(times, 1)
	end
	if #times >= MAX_ACTIONS_PER_SECOND then
		return false
	end
	table.insert(times, now)
	return true
end

local function buyWeapon(player: Player, weaponId: any)
	local weapon = if typeof(weaponId) == "string" then WeaponConfig.Weapons[weaponId] else nil
	local profile = DataService.Get(player)
	if not weapon or not profile then
		return reply(player, false, "That weapon doesn't exist.")
	end
	if profile.OwnedWeapons[weaponId] then
		return reply(player, false, "You already own it.")
	end
	if profile.Coins < weapon.Price then
		return reply(player, false, `You need {weapon.Price - profile.Coins} more coins.`)
	end
	DataService.Update(player, function(p)
		p.Coins -= weapon.Price
		p.OwnedWeapons[weaponId] = true
	end)
	reply(player, true, `Bought {weapon.DisplayName}!`)
end

local function equipWeapon(player: Player, weaponId: any)
	local profile = DataService.Get(player)
	if typeof(weaponId) ~= "string" or not WeaponConfig.Weapons[weaponId] or not profile then
		return reply(player, false, "That weapon doesn't exist.")
	end
	if not profile.OwnedWeapons[weaponId] then
		return reply(player, false, "Buy it in the shop first.")
	end
	DataService.Update(player, function(p)
		p.EquippedWeapon = weaponId
	end)
	reply(player, true, `{WeaponConfig.Weapons[weaponId].DisplayName} equipped for your next life.`)
end

local function equipAttachment(player: Player, weaponId: any, attachmentId: any)
	local profile = DataService.Get(player)
	local attachment = if typeof(attachmentId) == "string" then WeaponConfig.AttachmentsById[attachmentId] else nil
	if typeof(weaponId) ~= "string" or not WeaponConfig.Weapons[weaponId] or not attachment or not profile then
		return reply(player, false, "That attachment doesn't exist.")
	end
	if not profile.OwnedWeapons[weaponId] then
		return reply(player, false, "Buy the weapon first.")
	end
	local kills = profile.WeaponKills[weaponId] or 0
	if kills < attachment.UnlockKills then
		return reply(player, false, `Unlocks at {attachment.UnlockKills} kills with this weapon ({kills} so far).`)
	end
	DataService.Update(player, function(p)
		local loadout = p.Loadouts[weaponId] or {}
		loadout[attachment.Slot] = attachment.Id
		p.Loadouts[weaponId] = loadout
	end)
	reply(player, true, `{attachment.DisplayName} equipped.`)
end

function ShopService.Start()
	Net.Event(Net.Names.ShopAction).OnServerEvent:Connect(function(player, action: any, a: any, b: any)
		if not underRateLimit(player) then
			return
		end
		if action == "BuyWeapon" then
			buyWeapon(player, a)
		elseif action == "EquipWeapon" then
			equipWeapon(player, a)
		elseif action == "EquipAttachment" then
			equipAttachment(player, a, b)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		actionTimes[player] = nil
	end)
end

return ShopService
