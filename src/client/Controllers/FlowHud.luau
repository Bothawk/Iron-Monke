--!strict
-- Shows Flow without a bar: a ring of dots around the crosshair that fills up and
-- changes color by tier, speed lines at the screen edges from tier 1, and a
-- pulsing glow during Overflow.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MovementConfig = require(ReplicatedStorage.Shared.Config.MovementConfig)
local MovementController = require(script.Parent.MovementController)
local SettingsController = require(script.Parent.SettingsController)
local WeaponController = require(script.Parent.WeaponController)

local player = Players.LocalPlayer

local DOT_COUNT = 28
local RING_RADIUS = 30
local DOT_SIZE = 3
local LINE_COUNT = 14

local TIER_COLORS = {
	Color3.fromRGB(230, 230, 230),
	Color3.fromRGB(90, 200, 255),
	Color3.fromRGB(170, 110, 255),
	Color3.fromRGB(255, 160, 40),
}

local FlowHud = {}

function FlowHud.Start()
	local movement = MovementController.State
	local weapon = WeaponController.State

	local gui = Instance.new("ScreenGui")
	gui.Name = "FlowHud"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -1 -- under the weapon HUD and scope

	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(0, 0)
	ring.BackgroundTransparency = 1
	ring.Parent = gui

	local dots: { Frame } = {}
	for i = 1, DOT_COUNT do
		-- Starts at the top and fills clockwise.
		local angle = (i - 1) / DOT_COUNT * math.pi * 2 - math.pi / 2
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromOffset(math.cos(angle) * RING_RADIUS, math.sin(angle) * RING_RADIUS)
		dot.Size = UDim2.fromOffset(DOT_SIZE, DOT_SIZE)
		dot.BorderSizePixel = 0
		Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
		dot.Parent = ring
		table.insert(dots, dot)
	end

	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromOffset(RING_RADIUS * 2 + 10, RING_RADIUS * 2 + 10)
	glow.BackgroundTransparency = 1
	Instance.new("UICorner", glow).CornerRadius = UDim.new(1, 0)
	local glowStroke = Instance.new("UIStroke")
	glowStroke.Thickness = 2
	glowStroke.Color = TIER_COLORS[4]
	glowStroke.Transparency = 1
	glowStroke.Parent = glow
	glow.Parent = ring

	-- Speed lines: thin streaks around the screen edge that slide outward.
	type Line = { Frame: Frame, Angle: number, Phase: number }
	local lines: { Line } = {}
	local random = Random.new()
	for _ = 1, LINE_COUNT do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BorderSizePixel = 0
		line.BackgroundColor3 = Color3.new(1, 1, 1)
		line.BackgroundTransparency = 1
		line.Parent = gui
		table.insert(lines, { Frame = line, Angle = random:NextNumber(0, math.pi * 2), Phase = random:NextNumber() })
	end

	gui.Parent = player:WaitForChild("PlayerGui")

	local clock = 0
	RunService.RenderStepped:Connect(function(dt)
		clock += dt
		local alive = weapon.Alive
		local color = TIER_COLORS[movement.Tier]
		local filled = math.floor(movement.Flow / MovementConfig.Flow.Max * DOT_COUNT + 0.5)
		local overflow = movement.OverflowRemaining > 0

		ring.Visible = alive and not weapon.Scoped and SettingsController.Get("ShowFlowRing")
		for i, dot in dots do
			local lit = i <= filled
			dot.BackgroundColor3 = if lit then color else Color3.new(1, 1, 1)
			dot.BackgroundTransparency = if lit then 0.1 else 0.85
		end
		glowStroke.Transparency = if overflow then 0.3 + 0.4 * (0.5 + 0.5 * math.sin(clock * 12)) else 1

		-- Lines appear from tier 1 and get stronger with each tier and with speed.
		local intensity = if alive
				and movement.Tier >= 2
				and SettingsController.Get("SpeedLines")
			then (movement.Tier - 1) / 3 * math.clamp(movement.Speed / MovementConfig.MaxSpeedCap, 0.4, 1)
			else 0
		local viewport = workspace.CurrentCamera.ViewportSize
		local center = viewport / 2
		local reach = math.max(viewport.X, viewport.Y) * 0.5
		for _, line in lines do
			line.Phase = (line.Phase + dt * (1.5 + intensity * 2)) % 1
			local distance = reach * (0.75 + line.Phase * 0.35)
			local direction = Vector2.new(math.cos(line.Angle), math.sin(line.Angle))
			local position = center + direction * distance
			line.Frame.Position = UDim2.fromOffset(position.X, position.Y)
			line.Frame.Size = UDim2.fromOffset(40 + intensity * 60, 1.5)
			line.Frame.Rotation = math.deg(line.Angle)
			line.Frame.BackgroundTransparency = 1 - intensity * 0.35 * math.sin(line.Phase * math.pi)
			if line.Phase < dt * 2 then
				line.Angle = random:NextNumber(0, math.pi * 2)
			end
		end
	end)
end

return FlowHud
