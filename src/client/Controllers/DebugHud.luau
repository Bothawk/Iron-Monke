--!strict
-- Developer readout of speed, Flow and movement state. Press F3 to show or hide it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config.MovementConfig)
local MovementController = require(script.Parent.MovementController)

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

	gui.Parent = player:WaitForChild("PlayerGui")

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == TOGGLE_KEY then
			gui.Enabled = not gui.Enabled
		end
	end)

	local fps = 60
	RunService.RenderStepped:Connect(function(dt)
		if not gui.Enabled then
			return
		end
		fps += (1 / math.max(dt, 1e-3) - fps) * 0.05
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
			math.floor(player:GetNetworkPing() * 1000 + 0.5),
			state.Speed,
			cap,
			math.floor(state.Flow),
			tierName,
			action
		)
	end)
end

return DebugHud
