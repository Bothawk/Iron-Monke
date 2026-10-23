--!strict
-- Hold Tab (or the controller's View/Back button) for the scoreboard: rank, name,
-- kills, deaths, K/D, headshot % and ping, sorted by kills. Reads the stat
-- attributes the server keeps on each Player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local KEYS = { Enum.KeyCode.Tab, Enum.KeyCode.ButtonSelect }
local REFRESH_INTERVAL = 0.25
local ROW_HEIGHT = 30
local COLUMNS = {
	{ Title = "#", Width = 40 },
	{ Title = "PLAYER", Width = 240 },
	{ Title = "K", Width = 60 },
	{ Title = "D", Width = 60 },
	{ Title = "K/D", Width = 70 },
	{ Title = "HS%", Width = 70 },
	{ Title = "PING", Width = 70 },
}
local ACCENT = Color3.fromRGB(255, 140, 40)

local ScoreboardHud = {}

local function stat(target: Player, name: string): number
	local value = target:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function makeRow(parent: Instance, values: { string }, header: boolean): Frame
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.BackgroundColor3 = Color3.new(1, 1, 1)
	row.BackgroundTransparency = if header then 1 else 0.94
	row.BorderSizePixel = 0
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	for i, column in COLUMNS do
		local cell = Instance.new("TextLabel")
		cell.LayoutOrder = i
		cell.Size = UDim2.new(0, column.Width, 1, 0)
		cell.BackgroundTransparency = 1
		cell.Font = if header then Enum.Font.GothamBold else Enum.Font.Gotham
		cell.TextSize = if header then 13 else 16
		cell.TextColor3 = if header then Color3.fromRGB(170, 170, 170) else Color3.new(1, 1, 1)
		cell.TextXAlignment = if i == 2 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
		cell.Text = values[i] or ""
		cell.Parent = row
	end
	row.Parent = parent
	return row
end

function ScoreboardHud.Start()
	local width = 0
	for _, column in COLUMNS do
		width += column.Width
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ScoreboardHud"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 10

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.45)
	panel.Size = UDim2.fromOffset(width + 24, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
	local padding = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(padding :: any)[side] = UDim.new(0, 12)
	end
	padding.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 3)
	layout.Parent = panel
	panel.Parent = gui

	-- Mode, map and goal above the columns.
	local title = Instance.new("TextLabel")
	title.LayoutOrder = -1
	title.Size = UDim2.new(1, 0, 0, 26)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 16
	title.TextColor3 = ACCENT
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local headerValues = {}
	for _, column in COLUMNS do
		table.insert(headerValues, column.Title)
	end
	makeRow(panel, headerValues, true).LayoutOrder = 0

	local rows: { Frame } = {}

	local function refresh()
		local match = ReplicatedStorage:FindFirstChild("Match")
		if match then
			title.Text = string.format(
				"%s  ·  %s  ·  FIRST TO %s",
				tostring(match:GetAttribute("Mode") or ""),
				tostring(match:GetAttribute("MapName") or ""),
				tostring(match:GetAttribute("KillTarget") or "")
			)
		end
		for _, row in rows do
			row:Destroy()
		end
		table.clear(rows)

		local everyone = Players:GetPlayers()
		table.sort(everyone, function(a, b)
			local ak, bk = stat(a, "Kills"), stat(b, "Kills")
			if ak ~= bk then
				return ak > bk
			end
			return stat(a, "Deaths") < stat(b, "Deaths")
		end)
		for rank, target in everyone do
			local kills, deaths = stat(target, "Kills"), stat(target, "Deaths")
			local headshots = stat(target, "Headshots")
			local row = makeRow(panel, {
				tostring(rank),
				target.DisplayName,
				tostring(kills),
				tostring(deaths),
				string.format("%.2f", kills / math.max(deaths, 1)),
				if kills > 0 then `{math.floor(headshots / kills * 100 + 0.5)}%` else "-",
				tostring(stat(target, "Ping")),
			}, false)
			row.LayoutOrder = rank
			if target == player then
				row.BackgroundColor3 = ACCENT
				row.BackgroundTransparency = 0.75
			end
			table.insert(rows, row)
		end
	end

	gui.Parent = player:WaitForChild("PlayerGui")

	local open = false
	UserInputService.InputBegan:Connect(function(input)
		if table.find(KEYS, input.KeyCode) and not UserInputService:GetFocusedTextBox() then
			open = true
			gui.Enabled = true
			task.spawn(function()
				while open do
					refresh()
					task.wait(REFRESH_INTERVAL)
				end
			end)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if table.find(KEYS, input.KeyCode) then
			open = false
			gui.Enabled = false
		end
	end)
end

return ScoreboardHud
