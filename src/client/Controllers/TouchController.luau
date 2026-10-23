--!strict
-- On-screen buttons for phones and tablets. Movement uses Roblox's own thumbstick
-- (pushing it all the way forward sprints, see AutoSprint), the camera turns by
-- dragging anywhere else, and these buttons do the rest:
--   FIRE (knife: slash), SCOPE (knife: lunge), JUMP, SLIDE (hold), RELOAD, SWAP,
--   INSPECT and MENU.
-- They only show while the last input was touch, and their size is a setting.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local KnifeController = require(script.Parent.KnifeController)
local MenuController = require(script.Parent.MenuController)
local MovementController = require(script.Parent.MovementController)
local SettingsController = require(script.Parent.SettingsController)
local WeaponController = require(script.Parent.WeaponController)

local player = Players.LocalPlayer

local TouchController = {}

type ButtonSpec = {
	Name: string,
	Text: string,
	Size: number,
	Position: UDim2, -- of the button's center
	OnPress: () -> (),
	OnRelease: (() -> ())?,
}

local function knifeOut(): boolean
	return WeaponController.State.Equipped == "Knife"
end

local SPECS: { ButtonSpec } = {
	{
		Name = "Fire",
		Text = "FIRE",
		Size = 96,
		Position = UDim2.new(1, -90, 1, -110),
		OnPress = function()
			if knifeOut() then
				KnifeController.Slash()
			else
				WeaponController.Fire()
			end
		end,
	},
	{
		Name = "Scope",
		Text = "SCOPE",
		Size = 72,
		Position = UDim2.new(1, -200, 1, -80),
		OnPress = function()
			if knifeOut() then
				KnifeController.Lunge()
			else
				WeaponController.ToggleScope()
			end
		end,
	},
	{
		Name = "Jump",
		Text = "JUMP",
		Size = 72,
		Position = UDim2.new(1, -90, 1, -230),
		OnPress = MovementController.QueueJump,
	},
	{
		Name = "Slide",
		Text = "SLIDE",
		Size = 64,
		Position = UDim2.new(1, -190, 1, -190),
		OnPress = function()
			MovementController.SetTouchCrouch(true)
		end,
		OnRelease = function()
			MovementController.SetTouchCrouch(false)
		end,
	},
	{
		Name = "Reload",
		Text = "R",
		Size = 50,
		Position = UDim2.new(1, -280, 1, -150),
		OnPress = WeaponController.Reload,
	},
	{
		Name = "Swap",
		Text = "SWAP",
		Size = 50,
		Position = UDim2.new(1, -90, 1, -320),
		OnPress = WeaponController.Swap,
	},
	{
		Name = "Inspect",
		Text = "F",
		Size = 40,
		Position = UDim2.new(1, -165, 1, -300),
		OnPress = WeaponController.StartInspect,
	},
	{
		Name = "Menu",
		Text = "☰",
		Size = 44,
		Position = UDim2.new(0, 40, 0, 110),
		OnPress = function()
			MenuController.Open("LOADOUT")
		end,
	},
}

function TouchController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TouchButtons"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Enabled = false

	local buttons: { { Button: TextButton, Spec: ButtonSpec } } = {}
	for _, spec in SPECS do
		local button = Instance.new("TextButton")
		button.Name = spec.Name
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		button.Position = spec.Position
		button.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
		button.BackgroundTransparency = 0.35
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Font = Enum.Font.GothamBold
		button.AutoButtonColor = false
		button.Text = spec.Text
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = button
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Transparency = 0.6
		stroke.Thickness = 1.5
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = button

		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				button.BackgroundTransparency = 0.1
				spec.OnPress()
			end
		end)
		button.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				button.BackgroundTransparency = 0.35
				if spec.OnRelease then
					spec.OnRelease()
				end
			end
		end)
		button.Parent = gui
		table.insert(buttons, { Button = button, Spec = spec })
	end

	local function applyScale()
		local scale = SettingsController.Get("TouchButtonScale")
		for _, entry in buttons do
			local size = entry.Spec.Size * scale
			entry.Button.Size = UDim2.fromOffset(size, size)
			entry.Button.TextSize = math.floor(math.clamp(size * 0.22, 11, 22))
		end
	end
	applyScale()
	SettingsController.Changed:Connect(function(id: string)
		if id == "TouchButtonScale" then
			applyScale()
		end
	end)

	local function updateVisibility()
		local lastInput = UserInputService:GetLastInputType()
		local touching = lastInput == Enum.UserInputType.Touch
			or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
		gui.Enabled = touching and player.Character ~= nil
		if not gui.Enabled then
			-- Don't leave a slide held if the buttons disappear mid-press.
			MovementController.SetTouchCrouch(false)
		end
	end
	UserInputService.LastInputTypeChanged:Connect(updateVisibility)
	player.CharacterAdded:Connect(updateVisibility)
	updateVisibility()

	gui.Parent = player:WaitForChild("PlayerGui")
end

return TouchController
