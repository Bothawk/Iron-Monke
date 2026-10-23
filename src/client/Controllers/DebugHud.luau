--!strict
-- Developer readout of speed, Flow and movement state (F3 to show or hide), plus
-- the small FPS and ping counter players can turn on in settings.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config.MovementConfig)
local MovementController = require(script.Parent.MovementController)
local SettingsController = require(script.Parent.SettingsController)

local player = Players.LocalPlayer

local TOGGLE_KEY = Enum.KeyCode.F3

local DebugHud = {}

function DebugHud.Start()
	local state = MovementController.State

	local gui = Instance.new("ScreenGui")
	gui.Name = "DebugHud"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Enabled = false

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0, 0)
	label.Position = UDim2.fromOffset(12, 60)
	label.Size = UDim2.fromOffset(420, 120)
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.BackgroundTransparency = 0.5
	label.Font = Enum.Font.RobotoMono
	label.TextSize = 15
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	Instance.new("UIPadding", label).PaddingLeft = UDim.new(0, 8)
	label.Parent = gui

	local counter = Instance.new("TextLabel")
	counter.AnchorPoint = Vector2.new(0, 1)
	counter.Position = UDim2.new(0, 12, 1, -8)
	counter.Size = UDim2.fromOffset(200, 16)
	counter.BackgroundTransparency = 1
	counter.Font = Enum.Font.RobotoMono
	counter.TextSize = 13
	counter.TextColor3 = Color3.fromRGB(200, 200, 200)
	counter.TextStrokeTransparency = 0.6
	counter.TextXAlignment = Enum.TextXAlignment.Left
	local counterGui = Instance.new("ScreenGui")
	counterGui.Name = "FpsCounter"
	counterGui.IgnoreGuiInset = true
	counterGui.ResetOnSpawn = false
	counter.Parent = counterGui
	counterGui.Parent = player:WaitForChild("PlayerGui")

	gui.Parent = player:WaitForChild("PlayerGui")

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == TOGGLE_KEY then
			gui.Enabled = not gui.Enabled
		end
	end)

	local fps = 60
	RunService.RenderStepped:Connect(function(dt)
		fps += (1 / math.max(dt, 1e-3) - fps) * 0.05
		local ping = math.floor(player:GetNetworkPing() * 1000 + 0.5)
		counterGui.Enabled = SettingsController.Get("ShowFps")
		if counterGui.Enabled then
			counter.Text = `{math.floor(fps + 0.5)} FPS  ·  {ping} ms`
		end
		if not gui.Enabled then
			return
		end
		local action = if state.Sliding
			then "SLIDING"
			elseif state.Crouching then "CROUCH"
			elseif state.Sprinting then "SPRINT"
			elseif state.Grounded then "GROUND"
			else `AIR  kicks {state.WallKicksUsed}/{Config.WallKick.MaxKicks}`
		local tierName = if state.OverflowRemaining > 0
			then string.format("OVERFLOW %.1fs", state.OverflowRemaining)
			else `TIER {state.Tier - 1}`
		local cap = Config.Flow.Tiers[state.Tier].SpeedCap
		label.Text = string.format(
			"FPS   %d\nPING  %d ms\nSPEED %.1f / %d\nFLOW  %d  %s\nSTATE %s",
			math.floor(fps + 0.5),
			ping,
			state.Speed,
			cap,
			math.floor(state.Flow),
			tierName,
			action
		)
	end)
end

return DebugHud
