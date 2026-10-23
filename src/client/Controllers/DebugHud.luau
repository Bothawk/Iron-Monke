--!strict
-- Temporary test HUD for phase 1: crosshair dot, speed, Flow meter and movement state.
-- The real HUD replaces this in phase 4.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.MovementConfig)
local MovementController = require(script.Parent.MovementController)

local player = Players.LocalPlayer

local TIER_COLORS = {
	Color3.fromRGB(200, 200, 200),
	Color3.fromRGB(90, 200, 255),
	Color3.fromRGB(170, 110, 255),
	Color3.fromRGB(255, 170, 40),
}

local DebugHud = {}

function DebugHud.Start()
	local state = MovementController.State

	local gui = Instance.new("ScreenGui")
	gui.Name = "DebugHud"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false

	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(4, 4)
	dot.BackgroundColor3 = Color3.new(1, 1, 1)
	dot.BorderSizePixel = 0
	Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
	dot.Parent = gui

	local barBack = Instance.new("Frame")
	barBack.AnchorPoint = Vector2.new(0.5, 1)
	barBack.Position = UDim2.new(0.5, 0, 1, -60)
	barBack.Size = UDim2.fromOffset(320, 6)
	barBack.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	barBack.BackgroundTransparency = 0.3
	barBack.BorderSizePixel = 0
	barBack.Parent = gui

	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBack

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -72)
	label.Size = UDim2.fromOffset(600, 24)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.RobotoMono
	label.TextSize = 18
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.6
	label.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")

	RunService.RenderStepped:Connect(function()
		local color = TIER_COLORS[state.Tier]
		barFill.Size = UDim2.fromScale(state.Flow / Config.Flow.Max, 1)
		barFill.BackgroundColor3 = color

		local action = if state.Sliding
			then "SLIDING"
			elseif state.Crouching then "CROUCH"
			elseif state.Sprinting then "SPRINT"
			elseif state.Grounded then "GROUND"
			else `AIR  kicks {state.WallKicksUsed}/{Config.WallKick.MaxKicks}`
		local tierName = if state.OverflowRemaining > 0
			then string.format("OVERFLOW %.1fs", state.OverflowRemaining)
			else `TIER {state.Tier - 1}`
		label.Text =
			string.format("SPEED %5.1f   FLOW %3d  %s   %s", state.Speed, math.floor(state.Flow), tierName, action)
		label.TextColor3 = color
	end)
end

return DebugHud
