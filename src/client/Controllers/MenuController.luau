--!strict
-- The in-game menu (press M): LOADOUT (pick a sniper and attachments, with stat bars
-- that preview changes), SHOP (buy snipers with coins), SETTINGS and STATS.
-- The mouse is freed while it's open. Loadout changes apply on the next spawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local SettingsConfig = require(ReplicatedStorage.Shared.Config.SettingsConfig)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local WeaponStats = require(ReplicatedStorage.Shared.Combat.WeaponStats)
local ProfileController = require(script.Parent.ProfileController)
local SettingsController = require(script.Parent.SettingsController)
local SoundController = require(script.Parent.SoundController)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local player = Players.LocalPlayer
local C = Widgets.Colors

local TOGGLE_KEYS = { Enum.KeyCode.M }
local TABS = { "LOADOUT", "SHOP", "SETTINGS", "STATS" }
local WINDOW_SIZE = Vector2.new(860, 540)
local TOAST_TIME = 3

local MenuController = {}

-- 0..1 bars for comparing snipers. Higher is always better.
type Bar = { Label: string, Value: (WeaponStats.Stats) -> number }
local BARS: { Bar } = {
	{
		Label = "Damage",
		Value = function(s)
			return s.BodyDamage / 100
		end,
	},
	{
		Label = "Fire rate",
		Value = function(s)
			local cycle = s.FireInterval * (s.ShotsPerCycle - 1) + s.BoltTime
			return (s.ShotsPerCycle / cycle) / 3
		end,
	},
	{
		Label = "Scope speed",
		Value = function(s)
			return (0.26 - s.AdsTime) / 0.18
		end,
	},
	{
		Label = "Zoom",
		Value = function(s)
			return s.Zoom / 7.5
		end,
	},
	{
		Label = "Magazine",
		Value = function(s)
			return s.MagSize / 10
		end,
	},
	{
		Label = "Reload speed",
		Value = function(s)
			return (3 - s.ReloadTime) / 2
		end,
	},
	{
		Label = "Mobility",
		Value = function(s)
			return (s.MoveSpeedMultiplier - 0.85) / 0.25
		end,
	},
}

local function formatSetting(setting: SettingsConfig.Setting, value: number): string
	local decimals = setting.Decimals or 0
	return string.format(`%.{decimals}f`, value)
end

function MenuController.Start()
	Widgets.PlaySound = function(name: string)
		SoundController.Play(name, "UI")
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "Menu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Enabled = false

	local dim = Widgets.Frame(gui, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Active = true, -- clicks on the background don't shoot
	})
	-- A visible Modal button frees the mouse from first-person lock.
	local mouseFree = Instance.new("TextButton")
	mouseFree.Modal = true
	mouseFree.BackgroundTransparency = 1
	mouseFree.Text = ""
	mouseFree.Size = UDim2.fromOffset(0, 0)
	mouseFree.Parent = dim

	local window = Widgets.Frame(dim, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
		BackgroundColor3 = C.Background,
		Active = true,
	})
	Widgets.Corner(window, 10)
	local windowScale = Instance.new("UISizeConstraint")
	windowScale.MaxSize = WINDOW_SIZE
	windowScale.Parent = window

	-- Header: tabs on the left, coins and close on the right.
	local header = Widgets.Frame(window, { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1 })
	Widgets.Padding(header, 10)
	local tabRow = Widgets.Frame(header, { Size = UDim2.new(1, -220, 1, 0), BackgroundTransparency = 1 })
	Widgets.List(tabRow, 6, true)
	local coinsLabel = Widgets.Text(header, "", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -46, 0, 0),
		Size = UDim2.fromOffset(170, 32),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.Gold,
		TextSize = 18,
	})

	local content = Widgets.Frame(window, {
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 1, -88),
		BackgroundTransparency = 1,
	})
	Widgets.Padding(content, 12)

	local toast = Widgets.Text(window, "", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -24, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 14,
	})
	local toastShownAt = -math.huge

	local currentTab = "LOADOUT"
	local selectedWeapon = WeaponConfig.DefaultWeapon
	local selectedCategory = SettingsConfig.Categories[1]
	local tabButtons: { [string]: TextButton } = {}
	local render: () -> () -- forward declaration

	local function showToast(text: string, good: boolean)
		toast.Text = text
		toast.TextColor3 = if good then C.Good else C.Bad
		toastShownAt = os.clock()
		task.delay(TOAST_TIME, function()
			if os.clock() - toastShownAt >= TOAST_TIME - 0.05 then
				toast.Text = ""
			end
		end)
	end

	local function clearContent()
		for _, child in content:GetChildren() do
			if not child:IsA("UIPadding") then
				child:Destroy()
			end
		end
	end

	-- LOADOUT --------------------------------------------------------------------
	local function renderLoadout(profile: any)
		local listColumn = Widgets.Frame(content, { Size = UDim2.new(0, 210, 1, 0), BackgroundTransparency = 1 })
		Widgets.List(listColumn, 6)
		for order, weaponId in WeaponConfig.WeaponOrder do
			local weapon = WeaponConfig.Weapons[weaponId]
			local owned = profile.OwnedWeapons[weaponId] == true
			local equipped = profile.EquippedWeapon == weaponId
			local text = if equipped
				then `{weapon.DisplayName}  ✓`
				elseif owned then weapon.DisplayName
				else `{weapon.DisplayName}  · {weapon.Price}`
			local button = Widgets.Button(listColumn, text, function()
				selectedWeapon = weaponId
				render()
			end, {
				Size = UDim2.new(1, 0, 0, 40),
				LayoutOrder = order,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = if owned then C.Text else C.Muted,
				BackgroundColor3 = if weaponId == selectedWeapon
					then C.Accent:Lerp(C.PanelLight, 0.55)
					else C.PanelLight,
			})
			Widgets.Padding(button, 12)
		end

		local weapon = WeaponConfig.Weapons[selectedWeapon]
		local owned = profile.OwnedWeapons[selectedWeapon] == true
		local kills = profile.WeaponKills[selectedWeapon] or 0
		local loadout = WeaponStats.CleanLoadout(profile.Loadouts[selectedWeapon])
		local currentStats = WeaponStats.Compute(selectedWeapon, loadout)

		local detail = Widgets.Frame(content, {
			Position = UDim2.fromOffset(226, 0),
			Size = UDim2.new(1, -226, 1, 0),
			BackgroundTransparency = 1,
		})
		Widgets.Text(
			detail,
			weapon.DisplayName,
			{ Size = UDim2.new(1, 0, 0, 30), TextSize = 26, Font = Enum.Font.GothamBlack }
		)
		Widgets.Text(detail, weapon.Description, {
			Position = UDim2.fromOffset(0, 32),
			Size = UDim2.new(1, -150, 0, 18),
			TextSize = 13,
			TextColor3 = C.Muted,
		})
		if owned and profile.EquippedWeapon ~= selectedWeapon then
			Widgets.Button(detail, "EQUIP", function()
				ProfileController.ShopAction("EquipWeapon", selectedWeapon)
			end, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				BackgroundColor3 = C.Accent,
			})
		elseif not owned then
			Widgets.Button(detail, "GO TO SHOP", function()
				currentTab = "SHOP"
				render()
			end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0) })
		end

		local bars = Widgets.Frame(detail, {
			Position = UDim2.fromOffset(0, 60),
			Size = UDim2.new(0.42, 0, 0, 7 * 24),
			BackgroundTransparency = 1,
		})
		Widgets.List(bars, 2)
		local showBars: { (number, number?) -> () } = {}
		for order, bar in BARS do
			local _, show = Widgets.StatBar(bars, bar.Label, order)
			table.insert(showBars, show)
		end
		local function preview(previewStats: WeaponStats.Stats?)
			for i, bar in BARS do
				showBars[i](bar.Value(currentStats), if previewStats then bar.Value(previewStats) else nil)
			end
		end
		preview(nil)

		local hint = Widgets.Text(detail, `Kills with {weapon.DisplayName}: {kills}`, {
			Position = UDim2.new(0, 0, 0, 60 + 7 * 24 + 8),
			Size = UDim2.new(0.42, 0, 0, 60),
			TextSize = 13,
			TextColor3 = C.Muted,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		local defaultHint = `Kills with {weapon.DisplayName}: {kills}. Changes apply when you respawn.`
		hint.Text = defaultHint

		-- Attachments: one row per slot.
		local slots = Widgets.Frame(detail, {
			Position = UDim2.new(0.46, 0, 0, 60),
			Size = UDim2.new(0.54, 0, 1, -60),
			BackgroundTransparency = 1,
		})
		Widgets.List(slots, 8)
		for order, slot in WeaponConfig.Slots do
			local slotRow = Widgets.Frame(slots, {
				Size = UDim2.new(1, 0, 0, 60),
				BackgroundTransparency = 1,
				LayoutOrder = order,
			})
			Widgets.Text(
				slotRow,
				string.upper(slot),
				{ Size = UDim2.new(1, 0, 0, 16), TextSize = 12, TextColor3 = C.Muted }
			)
			local options = Widgets.Frame(slotRow, {
				Position = UDim2.fromOffset(0, 18),
				Size = UDim2.new(1, 0, 0, 38),
				BackgroundTransparency = 1,
			})
			Widgets.List(options, 6, true)
			local inSlot = {}
			for _, attachment in WeaponConfig.Attachments do
				if attachment.Slot == slot then
					table.insert(inSlot, attachment)
				end
			end
			for index, attachment in inSlot do
				local unlocked = kills >= attachment.UnlockKills
				local equipped = loadout[slot] == attachment.Id
				local button = Widgets.Button(
					options,
					if unlocked then attachment.DisplayName else `🔒 {attachment.UnlockKills}`,
					function()
						if not owned then
							showToast("Buy this sniper first.", false)
						elseif not unlocked then
							showToast(`Unlocks at {attachment.UnlockKills} kills with {weapon.DisplayName}.`, false)
						elseif not equipped then
							ProfileController.ShopAction("EquipAttachment", selectedWeapon, attachment.Id)
						end
					end,
					{
						LayoutOrder = index,
						Size = UDim2.new(1 / #inSlot, -6, 1, 0),
						TextSize = 12,
						TextWrapped = true,
						TextColor3 = if unlocked then C.Text else C.Muted,
						BackgroundColor3 = if equipped then C.Accent:Lerp(C.PanelLight, 0.4) else C.PanelLight,
					}
				)
				button.MouseEnter:Connect(function()
					local trial = table.clone(loadout)
					trial[slot] = attachment.Id
					preview(WeaponStats.Compute(selectedWeapon, trial))
					hint.Text = `{attachment.DisplayName}: {attachment.Description}`
						.. (if unlocked then "" else `  (unlocks at {attachment.UnlockKills} kills)`)
				end)
				button.MouseLeave:Connect(function()
					preview(nil)
					hint.Text = defaultHint
				end)
			end
		end
	end

	-- SHOP -----------------------------------------------------------------------
	local function renderShop(profile: any)
		local grid = Widgets.Frame(content, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.new(1 / 3, -10, 0, 200)
		layout.CellPadding = UDim2.fromOffset(10, 10)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		for order, weaponId in WeaponConfig.WeaponOrder do
			local weapon = WeaponConfig.Weapons[weaponId]
			local owned = profile.OwnedWeapons[weaponId] == true
			local card = Widgets.Frame(grid, { LayoutOrder = order, BackgroundColor3 = C.Panel })
			Widgets.Corner(card, 8)
			Widgets.Padding(card, 12)
			local stripe =
				Widgets.Frame(card, { Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = weapon.Palette.Accent })
			Widgets.Corner(stripe, 2)
			Widgets.Text(card, weapon.DisplayName, {
				Position = UDim2.fromOffset(0, 12),
				Size = UDim2.new(1, 0, 0, 26),
				TextSize = 22,
				Font = Enum.Font.GothamBlack,
			})
			Widgets.Text(card, weapon.Description, {
				Position = UDim2.fromOffset(0, 42),
				Size = UDim2.new(1, 0, 0, 60),
				TextSize = 13,
				TextColor3 = C.Muted,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
			})
			if owned then
				Widgets.Text(card, "OWNED", {
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, 34),
					TextColor3 = C.Good,
				})
			else
				local affordable = profile.Coins >= weapon.Price
				Widgets.Button(card, `BUY  ·  {weapon.Price}`, function()
					ProfileController.ShopAction("BuyWeapon", weaponId)
				end, {
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, 34),
					BackgroundColor3 = if affordable then C.Accent else C.PanelLight,
					TextColor3 = if affordable then C.Text else C.Muted,
				})
			end
		end
		local skins = Widgets.Frame(grid, { LayoutOrder = 99, BackgroundColor3 = C.Panel })
		Widgets.Corner(skins, 8)
		Widgets.Padding(skins, 12)
		Widgets.Text(skins, "SKINS", { Size = UDim2.new(1, 0, 0, 26), TextSize = 22, Font = Enum.Font.GothamBlack })
		Widgets.Text(skins, "Sniper skins are coming soon.", {
			Position = UDim2.fromOffset(0, 32),
			Size = UDim2.new(1, 0, 0, 40),
			TextSize = 13,
			TextColor3 = C.Muted,
			TextWrapped = true,
		})
	end

	-- SETTINGS -------------------------------------------------------------------
	local function renderSettings()
		local categories = Widgets.Frame(content, { Size = UDim2.new(0, 160, 1, 0), BackgroundTransparency = 1 })
		Widgets.List(categories, 6)
		for order, category in SettingsConfig.Categories do
			Widgets.Button(categories, string.upper(category), function()
				selectedCategory = category
				render()
			end, {
				Size = UDim2.new(1, 0, 0, 38),
				LayoutOrder = order,
				BackgroundColor3 = if category == selectedCategory
					then C.Accent:Lerp(C.PanelLight, 0.55)
					else C.PanelLight,
			})
		end
		Widgets.Button(categories, "RESET", function()
			SettingsController.ResetCategory(selectedCategory)
			task.defer(render)
		end, { Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 100, TextSize = 12, TextColor3 = C.Muted })

		local list = Instance.new("ScrollingFrame")
		list.Position = UDim2.fromOffset(176, 0)
		list.Size = UDim2.new(1, -176, 1, 0)
		list.BackgroundTransparency = 1
		list.BorderSizePixel = 0
		list.ScrollBarThickness = 4
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.CanvasSize = UDim2.new()
		list.Parent = content
		Widgets.List(list, 6)

		for order, setting in SettingsConfig.List do
			if setting.Category == selectedCategory then
				local value = SettingsController.Get(setting.Id)
				local function onChange(newValue: any)
					SettingsController.Set(setting.Id, newValue)
				end
				local rowFrame: Frame
				if setting.Kind == "Slider" then
					rowFrame = Widgets.Slider(
						list,
						setting.Label,
						order,
						setting.Min :: number,
						setting.Max :: number,
						setting.Step :: number,
						value,
						function(v)
							return formatSetting(setting, v)
						end,
						onChange
					)
				elseif setting.Kind == "Toggle" then
					rowFrame = Widgets.Toggle(list, setting.Label, order, value, onChange)
				else
					rowFrame =
						Widgets.Choice(list, setting.Label, order, setting.Options :: { string }, value, onChange)
				end
				if setting.Hint then
					rowFrame.Size = UDim2.new(1, -6, 0, 54)
					Widgets.Text(rowFrame, setting.Hint, {
						Position = UDim2.new(0, 12, 1, -18),
						Size = UDim2.new(1, -24, 0, 14),
						TextSize = 11,
						TextColor3 = C.Muted,
					})
				else
					rowFrame.Size = UDim2.new(1, -6, 0, 40)
				end
			end
		end
	end

	-- STATS ----------------------------------------------------------------------
	local function renderStats(profile: any)
		local stats = profile.Stats
		local hours = stats.TimePlayed / 3600
		local entries = {
			{ "Kills", tostring(stats.Kills) },
			{ "Deaths", tostring(stats.Deaths) },
			{ "K/D", string.format("%.2f", stats.Kills / math.max(stats.Deaths, 1)) },
			{ "Headshots", tostring(stats.Headshots) },
			{
				"Headshot %",
				if stats.Kills > 0 then `{math.floor(stats.Headshots / stats.Kills * 100 + 0.5)}%` else "-",
			},
			{ "Longest shot", `{stats.LongestShot} studs` },
			{ "Best streak", tostring(stats.BestStreak) },
			{ "Flow kills", tostring(stats.FlowKills) },
			{ "Wins", tostring(stats.Wins) },
			{ "Matches", tostring(stats.MatchesPlayed) },
			{ "Time played", string.format("%.1f h", hours) },
			{ "Coins", tostring(profile.Coins) },
		}
		local grid = Widgets.Frame(content, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.new(0.25, -10, 0, 80)
		layout.CellPadding = UDim2.fromOffset(10, 10)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		for order, entry in entries do
			local cell = Widgets.Frame(grid, { LayoutOrder = order })
			Widgets.Corner(cell, 8)
			Widgets.Padding(cell, 12)
			Widgets.Text(
				cell,
				string.upper(entry[1]),
				{ Size = UDim2.new(1, 0, 0, 16), TextSize = 12, TextColor3 = C.Muted }
			)
			Widgets.Text(cell, entry[2], {
				Position = UDim2.fromOffset(0, 22),
				Size = UDim2.new(1, 0, 0, 30),
				TextSize = 26,
				Font = Enum.Font.GothamBlack,
			})
		end
	end

	render = function()
		clearContent()
		for name, button in tabButtons do
			Widgets.SetButtonColor(button, if name == currentTab then C.Accent else C.PanelLight)
		end
		local profile = ProfileController.Get()
		coinsLabel.Text = if profile then `{profile.Coins} coins` else ""
		if currentTab == "SETTINGS" then
			renderSettings()
		elseif not profile then
			Widgets.Text(content, "Loading your profile...", { TextColor3 = C.Muted })
		elseif currentTab == "LOADOUT" then
			renderLoadout(profile)
		elseif currentTab == "SHOP" then
			renderShop(profile)
		else
			renderStats(profile)
		end
	end

	for order, name in TABS do
		tabButtons[name] = Widgets.Button(tabRow, name, function()
			currentTab = name
			render()
		end, { LayoutOrder = order, Size = UDim2.fromOffset(120, 32) })
	end
	Widgets.Button(header, "✕", function()
		gui.Enabled = false
	end, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(32, 32),
	})

	gui.Parent = player:WaitForChild("PlayerGui")

	ProfileController.Changed:Connect(function()
		if gui.Enabled and currentTab ~= "SETTINGS" then
			render()
		end
	end)
	ProfileController.ShopResult:Connect(function(ok: boolean, message: string)
		showToast(message, ok)
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not table.find(TOGGLE_KEYS, input.KeyCode) then
			return
		end
		gui.Enabled = not gui.Enabled
		if gui.Enabled then
			render()
		end
	end)
end

function MenuController.IsOpen(): boolean
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local menu = playerGui and playerGui:FindFirstChild("Menu")
	return menu ~= nil and (menu :: ScreenGui).Enabled
end

return MenuController
