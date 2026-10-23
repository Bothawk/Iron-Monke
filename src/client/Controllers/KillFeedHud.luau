--!strict
-- Kill feed in the top right: who killed whom, with what and how. Lines involving
-- this player are highlighted. Old lines fade out.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)

local player = Players.LocalPlayer

local MAX_LINES = 5
local LINE_HEIGHT = 26
local LINE_LIFETIME = 6
local FADE_TIME = 0.6
local ACCENT = "#ff8c28"
local RED = "#ff4a4a"

local KillFeedHud = {}

type Line = { Frame: Frame, Label: TextLabel, CreatedAt: number }

local function escape(text: string): string
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

function KillFeedHud.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "KillFeedHud"
	gui.ResetOnSpawn = false

	local list = Instance.new("Frame")
	list.AnchorPoint = Vector2.new(1, 0)
	list.Position = UDim2.new(1, -20, 0, 16)
	list.Size = UDim2.fromOffset(460, MAX_LINES * (LINE_HEIGHT + 4))
	list.BackgroundTransparency = 1
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = list

	gui.Parent = player:WaitForChild("PlayerGui")

	local lines: { Line } = {}
	local order = 0

	Net.Event(Net.Names.KillFeed).OnClientEvent:Connect(function(entry: any)
		if typeof(entry) ~= "table" then
			return
		end
		local mine = entry.KillerUserId == player.UserId
		local victimIsMe = entry.VictimUserId == player.UserId
		local tags = if typeof(entry.Tags) == "table" then entry.Tags else {}
		local how = escape(tostring(entry.Weapon))
		if #tags > 0 then
			how ..= " · " .. escape(table.concat(tags, " · "))
		end
		local killerColor = if mine then ACCENT else "#ffffff"
		local victimColor = if victimIsMe then RED else "#ffffff"

		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromOffset(0, LINE_HEIGHT)
		frame.AutomaticSize = Enum.AutomaticSize.X
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BackgroundTransparency = if mine or victimIsMe then 0.35 else 0.6
		frame.BorderSizePixel = 0
		order -= 1 -- newest on top
		frame.LayoutOrder = order
		Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 4)
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 10)
		padding.PaddingRight = UDim.new(0, 10)
		padding.Parent = frame

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0, 1)
		label.AutomaticSize = Enum.AutomaticSize.X
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 15
		label.TextColor3 = Color3.new(1, 1, 1)
		label.RichText = true
		if entry.Killer == "" then
			-- No killer: they fell off the map.
			label.Text = string.format(
				'<font color="%s">%s</font>  <font color="#aaaaaa">fell</font>',
				victimColor,
				escape(tostring(entry.Victim))
			)
		else
			label.Text = string.format(
				'<font color="%s">%s</font>  <font color="#aaaaaa">[%s]</font>  <font color="%s">%s</font>',
				killerColor,
				escape(tostring(entry.Killer)),
				how,
				victimColor,
				escape(tostring(entry.Victim))
			)
		end
		label.Parent = frame
		frame.Parent = list

		table.insert(lines, { Frame = frame, Label = label, CreatedAt = os.clock() })
		while #lines > MAX_LINES do
			table.remove(lines, 1).Frame:Destroy()
		end
	end)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for i = #lines, 1, -1 do
			local line = lines[i]
			local age = now - line.CreatedAt
			if age > LINE_LIFETIME + FADE_TIME then
				line.Frame:Destroy()
				table.remove(lines, i)
			elseif age > LINE_LIFETIME then
				local fade = (age - LINE_LIFETIME) / FADE_TIME
				line.Label.TextTransparency = fade
				line.Frame.BackgroundTransparency = math.max(line.Frame.BackgroundTransparency, fade)
			end
		end
	end)
end

return KillFeedHud
