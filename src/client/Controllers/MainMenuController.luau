--!strict
-- The title screen players see when they join: the game's name, the equipped
-- sniper turning slowly in 3D, PLAY, shortcuts into the menu, and a camera
-- circling the map behind it. Pressing PLAY asks the server to spawn the player.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local MenuController = require(script.Parent.MenuController)
local ProfileController = require(script.Parent.ProfileController)
local SoundController = require(script.Parent.SoundController)
local Viewmodel = require(script.Parent.Parent.Weapon.Viewmodel)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local player = Players.LocalPlayer
local C = Widgets.Colors

local ORBIT_RADIUS = 140
local ORBIT_HEIGHT = 55
local ORBIT_SPEED = 0.04 -- radians per second
local SHOWCASE_SPIN = 0.5 -- radians per second
local FADE = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local MainMenuController = {}

function MainMenuController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MainMenu"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 15

	-- A dark fade from the left so the text is readable over the map.
	local shade = Widgets.Frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0) })
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.55, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = shade

	-- Keeps the mouse free while the title screen is up.
	local mouseFree = Instance.new("TextButton")
	mouseFree.Modal = true
	mouseFree.BackgroundTransparency = 1
	mouseFree.Text = ""
	mouseFree.Size = UDim2.fromOffset(0, 0)
	mouseFree.Parent = gui

	local column = Widgets.Frame(gui, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 70, 0.5, 0),
		Size = UDim2.fromOffset(380, 520),
		BackgroundTransparency = 1,
	})
	Widgets.Text(column, GameConfig.Name, {
		Size = UDim2.new(1, 0, 0, 64),
		Font = Enum.Font.GothamBlack,
		TextSize = 56,
		TextScaled = true,
	})
	Widgets.Text(column, GameConfig.Tagline, {
		Position = UDim2.fromOffset(2, 66),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 15,
		TextColor3 = C.Accent,
	})

	local buttons = Widgets.Frame(column, {
		Position = UDim2.fromOffset(0, 120),
		Size = UDim2.new(1, 0, 0, 320),
		BackgroundTransparency = 1,
	})
	Widgets.List(buttons, 10)

	local playing = false
	local function play()
		if playing then
			return
		end
		playing = true
		Net.Event(Net.Names.PlayRequest):FireServer()
		SoundController.Play("MatchStart", "UI")
		local fade = TweenService:Create(shade, FADE, { BackgroundTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		gui.Enabled = false
		GuiService.SelectedObject = nil
	end

	local playButton = Widgets.Button(buttons, "PLAY", play, {
		Size = UDim2.new(1, 0, 0, 64),
		LayoutOrder = 1,
		TextSize = 28,
		Font = Enum.Font.GothamBlack,
		BackgroundColor3 = C.Accent,
	})
	for order, tab in { "LOADOUT", "SHOP", "SETTINGS", "STATS" } do
		Widgets.Button(buttons, tab, function()
			MenuController.Open(tab)
		end, {
			Size = UDim2.new(1, 0, 0, 44),
			LayoutOrder = order + 1,
		})
	end

	local summary = Widgets.Text(column, "", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 14,
		TextColor3 = C.Muted,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Bottom,
	})

	-- The equipped sniper, turning in its own little 3D view.
	local viewport = Instance.new("ViewportFrame")
	viewport.AnchorPoint = Vector2.new(1, 0.5)
	viewport.Position = UDim2.new(1, -40, 0.5, 0)
	viewport.Size = UDim2.fromScale(0.5, 0.6)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(150, 150, 160)
	viewport.LightColor = Color3.fromRGB(255, 236, 214)
	viewport.LightDirection = Vector3.new(-0.5, -1, -0.6)
	viewport.Parent = gui
	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport
	local viewCamera = Instance.new("Camera")
	viewCamera.FieldOfView = 30
	viewCamera.CFrame = CFrame.lookAt(Vector3.new(0, 0.8, 9), Vector3.new(0, 0.1, 0))
	viewCamera.Parent = viewport
	viewport.CurrentCamera = viewCamera
	local weaponName = Widgets.Text(gui, "", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -60, 0.8, 0),
		Size = UDim2.fromOffset(400, 30),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamBlack,
		TextSize = 26,
	})

	local showcase = Viewmodel.new("Sniper")
	showcase:SetArmsVisible(false)
	showcase.Model.Parent = worldModel

	local function refresh(profile: any)
		local weaponId = if profile then profile.EquippedWeapon else WeaponConfig.DefaultWeapon
		local weapon = WeaponConfig.Weapons[weaponId] or WeaponConfig.Weapons[WeaponConfig.DefaultWeapon]
		showcase:SetPalette(weapon.Palette)
		weaponName.Text = weapon.DisplayName
		if profile then
			local stats = profile.Stats
			summary.Text = `{profile.Coins} coins  ·  {stats.Kills} kills  ·  {stats.Wins} wins`
		end
	end
	ProfileController.Changed:Connect(refresh)
	refresh(ProfileController.Get())

	gui.Parent = player:WaitForChild("PlayerGui")

	-- Controllers start with PLAY selected.
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = playButton
	end

	local orbit = 0
	local spin = 0
	RunService.RenderStepped:Connect(function(dt)
		if not gui.Enabled then
			return
		end
		spin += dt * SHOWCASE_SPIN
		-- A slow turn with a gentle bob, angled so the scope and stripe catch the light.
		showcase:PlaceAt(
			CFrame.new(0, math.sin(spin * 1.3) * 0.08, 0)
				* CFrame.Angles(math.rad(8), spin, 0)
				* CFrame.Angles(0, math.pi / 2, 0)
		)

		-- Until spawned, the camera circles the map.
		if not player.Character then
			orbit += dt * ORBIT_SPEED
			local camera = workspace.CurrentCamera
			camera.CameraType = Enum.CameraType.Scriptable
			local eye = Vector3.new(math.cos(orbit) * ORBIT_RADIUS, ORBIT_HEIGHT, math.sin(orbit) * ORBIT_RADIUS)
			camera.CFrame = CFrame.lookAt(eye, Vector3.new(0, 10, 0))
		end
	end)
end

return MainMenuController
