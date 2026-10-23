--!strict
-- Combat HUD: the crosshair (style, color, size and gap from settings, opening with
-- spread), the scope or red-dot overlay, hitmarkers, the kill banner with tags and
-- multi-kills, coin popups, ammo, health and a damage flash.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SettingsConfig = require(ReplicatedStorage.Shared.Config.SettingsConfig)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local ProfileController = require(script.Parent.ProfileController)
local SettingsController = require(script.Parent.SettingsController)
local WeaponController = require(script.Parent.WeaponController)

local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local RED = Color3.fromRGB(255, 60, 60)
local ACCENT = Color3.fromRGB(255, 140, 40)
local GOLD = Color3.fromRGB(255, 210, 80)
local FONT = Enum.Font.GothamBold

local HITMARKER_TIME = 0.2
local KILL_BANNER_TIME = 1.6
local COIN_POPUP_TIME = 1.4
local MULTI_KILL_WINDOW = 4 -- kills within this many seconds of each other chain
local MULTI_KILL_NAMES = { [2] = "DOUBLE KILL", [3] = "TRIPLE KILL" }
local MULTI_KILL_MAX_NAME = "RAMPAGE"
local DAMAGE_FLASH_TIME = 0.4

local WeaponHud = {}

local function frame(parent: Instance, props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = WHITE
	for key, value in props do
		(f :: any)[key] = value
	end
	f.Parent = parent
	return f
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextColor3 = WHITE
	l.TextStrokeTransparency = 0.7
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

type Crosshair = {
	Root: Frame,
	Arms: { Frame },
	Dot: Frame,
	Circle: Frame,
	Strokes: { UIStroke },
}

local function outline(parent: GuiObject, strokes: { UIStroke })
	local stroke = Instance.new("UIStroke")
	stroke.Color = BLACK
	stroke.Transparency = 0.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	table.insert(strokes, stroke)
end

local function buildCrosshair(gui: ScreenGui): Crosshair
	local strokes = {}
	local root = frame(gui, {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
	})
	local dot = frame(root, { AnchorPoint = Vector2.new(0.5, 0.5) })
	Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
	outline(dot, strokes)

	local circle = frame(root, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1 })
	Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)
	local ring = Instance.new("UIStroke")
	ring.Name = "Ring"
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = circle

	local arms = {}
	for _ = 1, 4 do
		local arm = frame(root, { AnchorPoint = Vector2.new(0.5, 0.5) })
		outline(arm, strokes)
		table.insert(arms, arm)
	end
	return { Root = root, Arms = arms, Dot = dot, Circle = circle, Strokes = strokes }
end

-- Applies the crosshair settings. `spreadPixels` opens the gap with weapon spread.
local function layoutCrosshair(crosshair: Crosshair, spreadPixels: number)
	local style = SettingsController.Get("CrosshairStyle")
	local color = SettingsConfig.CrosshairColors[SettingsController.Get("CrosshairColor")] or WHITE
	local size = SettingsController.Get("CrosshairSize")
	local gap = SettingsController.Get("CrosshairGap") + spreadPixels
	local thickness = SettingsController.Get("CrosshairThickness")
	local showOutline = SettingsController.Get("CrosshairOutline")

	local showArms = style == "Cross" or style == "Cross + dot"
	local showDot = style == "Dot" or style == "Cross + dot"
	local showCircle = style == "Circle"

	local offset = gap + size / 2
	local positions =
		{ Vector2.new(-offset, 0), Vector2.new(offset, 0), Vector2.new(0, -offset), Vector2.new(0, offset) }
	for i, arm in crosshair.Arms do
		arm.Visible = showArms
		arm.BackgroundColor3 = color
		arm.Position = UDim2.fromOffset(positions[i].X, positions[i].Y)
		arm.Size = if i <= 2 then UDim2.fromOffset(size, thickness) else UDim2.fromOffset(thickness, size)
	end
	crosshair.Dot.Visible = showDot
	crosshair.Dot.BackgroundColor3 = color
	local dotSize = thickness + 1
	crosshair.Dot.Size = UDim2.fromOffset(dotSize, dotSize)

	crosshair.Circle.Visible = showCircle
	local diameter = (gap + size) * 2
	crosshair.Circle.Size = UDim2.fromOffset(diameter, diameter)
	local ring = crosshair.Circle:FindFirstChild("Ring") :: UIStroke
	ring.Color = color
	ring.Thickness = thickness

	for _, stroke in crosshair.Strokes do
		stroke.Enabled = showOutline
	end
end

local function buildScope(gui: ScreenGui): (Frame, Frame)
	local root = frame(gui, {
		Name = "Scope",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
	})
	-- A round hole: a transparent circle whose huge border fills the rest of the screen.
	local lens = frame(root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
	})
	Instance.new("UICorner", lens).CornerRadius = UDim.new(1, 0)
	local ring = Instance.new("UIStroke")
	ring.Color = BLACK
	ring.Thickness = 4000
	ring.Parent = lens
	-- Solid blocks outside the lens's square, so the edges stay black even if the
	-- border above is drawn thinner than asked on some devices.
	local far = 8000
	for _, side in
		{
			{ Anchor = Vector2.new(1, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(far, far) },
			{ Anchor = Vector2.new(0, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(far, far) },
			{ Anchor = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(1, 0, 0, far) },
			{ Anchor = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(1, 0, 0, far) },
		}
	do
		frame(lens, {
			AnchorPoint = side.Anchor,
			Position = side.Position,
			Size = side.Size,
			BackgroundColor3 = BLACK,
		})
	end

	frame(lens, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = BLACK,
	})
	frame(lens, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = BLACK,
	})
	local dot = frame(lens, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(4, 4),
		BackgroundColor3 = RED,
	})
	Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
	return root, lens
end

-- The red-dot sight: no black ring, just a glowing dot with a faint circle.
local function buildRedDot(gui: ScreenGui): Frame
	local root = frame(gui, {
		Name = "RedDot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Visible = false,
	})
	local dot =
		frame(root, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = RED })
	Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
	local glow = frame(root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = RED,
		BackgroundTransparency = 0.75,
	})
	Instance.new("UICorner", glow).CornerRadius = UDim.new(1, 0)
	local circle = frame(
		root,
		{ AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(90, 90), BackgroundTransparency = 1 }
	)
	Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = RED
	stroke.Transparency = 0.6
	stroke.Thickness = 1.5
	stroke.Parent = circle
	return root
end

local function buildHitmarker(gui: ScreenGui): (Frame, { Frame })
	local root = frame(gui, {
		Name = "Hitmarker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
	})
	local bars = {}
	for i = 0, 3 do
		local angle = 45 + i * 90
		local direction = Vector2.new(math.cos(math.rad(angle)), math.sin(math.rad(angle)))
		local bar = frame(root, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(direction.X * 10, direction.Y * 10),
			Size = UDim2.fromOffset(9, 2),
			Rotation = angle,
			BackgroundTransparency = 1,
		})
		table.insert(bars, bar)
	end
	return root, bars
end

function WeaponHud.Start()
	local weapon = WeaponController.State

	local gui = Instance.new("ScreenGui")
	gui.Name = "WeaponHud"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false

	local damageFlash = frame(gui, {
		Name = "DamageFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = RED,
		BackgroundTransparency = 1,
	})

	local scope, scopeLens = buildScope(gui)
	local redDot = buildRedDot(gui)
	local crosshair = buildCrosshair(gui)
	local hitmarker, hitBars = buildHitmarker(gui)

	local killBanner = label(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.68),
		Size = UDim2.fromOffset(500, 40),
		Font = Enum.Font.GothamBlack,
		TextSize = 32,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	local killScale = Instance.new("UIScale")
	killScale.Parent = killBanner
	local killDetails = label(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.68, 30),
		Size = UDim2.fromOffset(600, 22),
		TextSize = 16,
		TextColor3 = ACCENT,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	local coinPopup = label(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.68, 56),
		Size = UDim2.fromOffset(300, 22),
		TextSize = 18,
		TextColor3 = GOLD,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})

	local ammoText = label(gui, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -32, 1, -28),
		Size = UDim2.fromOffset(200, 44),
		TextSize = 40,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local weaponName = label(gui, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -32, 1, -74),
		Size = UDim2.fromOffset(200, 20),
		TextSize = 16,
		TextColor3 = ACCENT,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local reloadBack = frame(gui, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -32, 1, -22),
		Size = UDim2.fromOffset(120, 3),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.5,
	})
	local reloadFill = frame(reloadBack, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = ACCENT })

	local healthBack = frame(gui, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 32, 1, -32),
		Size = UDim2.fromOffset(220, 6),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.5,
	})
	local healthFill = frame(healthBack, { Size = UDim2.fromScale(1, 1) })
	local healthText = label(gui, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 32, 1, -42),
		Size = UDim2.fromOffset(120, 32),
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	gui.Parent = player:WaitForChild("PlayerGui")

	local hitShownAt = -math.huge
	local killShownAt = -math.huge
	local coinsShownAt = -math.huge
	local damageShownAt = -math.huge
	local shownHealth = WeaponConfig.MaxHealth
	local multiKill = 0
	local coinTotal = 0

	WeaponController.Hit:Connect(function(zone: string, killed: boolean)
		hitShownAt = os.clock()
		local color = if zone == "Head" or killed then RED else WHITE
		for _, bar in hitBars do
			bar.BackgroundColor3 = color
			bar.Size = if killed then UDim2.fromOffset(13, 3) else UDim2.fromOffset(9, 2)
		end
	end)

	WeaponController.Killed:Connect(function(result: any)
		local now = os.clock()
		multiKill = if now - killShownAt <= MULTI_KILL_WINDOW then multiKill + 1 else 1
		killShownAt = now

		local tags = table.clone(result.Tags) :: { string }
		if multiKill >= 2 then
			table.insert(tags, 1, MULTI_KILL_NAMES[multiKill] or MULTI_KILL_MAX_NAME)
		end
		-- The first tag is the headline; the rest go underneath with the distance.
		local headline = table.remove(tags, 1) or "ELIMINATED"
		table.insert(tags, `{math.floor(result.Distance + 0.5)} studs`)
		killBanner.Text = headline
		killBanner.TextColor3 = if headline == "ELIMINATED" then WHITE else RED
		killDetails.Text = table.concat(tags, "  ·  ")
		killScale.Scale = 1.35
	end)

	-- Coins from kills close together add up into one popup.
	ProfileController.CoinsEarned:Connect(function(amount: number)
		local now = os.clock()
		coinTotal = if now - coinsShownAt < COIN_POPUP_TIME then coinTotal + amount else amount
		coinsShownAt = now
		coinPopup.Text = `+{coinTotal} coins`
	end)

	WeaponController.Damaged:Connect(function()
		damageShownAt = os.clock()
	end)

	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local camera = workspace.CurrentCamera
		local viewport = camera.ViewportSize
		local stats = weapon.Stats
		local knifeOut = weapon.Equipped == "Knife"

		-- The crosshair gap matches the real spread cone on screen.
		local spread = if knifeOut then 0 else weapon.Spread
		local spreadPixels = math.tan(math.rad(spread)) / math.tan(math.rad(camera.FieldOfView) / 2) * (viewport.Y / 2)
		layoutCrosshair(crosshair, spreadPixels)
		crosshair.Root.Visible = weapon.Alive and not weapon.Scoped

		scope.Visible = weapon.Scoped and not stats.RedDot
		redDot.Visible = weapon.Scoped and stats.RedDot
		local diameter = viewport.Y * 0.95
		scopeLens.Size = UDim2.fromOffset(diameter, diameter)

		local hitAge = (now - hitShownAt) / HITMARKER_TIME
		for _, bar in hitBars do
			bar.BackgroundTransparency = math.clamp(hitAge, 0, 1)
		end
		hitmarker.Visible = hitAge < 1

		local killAge = (now - killShownAt) / KILL_BANNER_TIME
		local killFade = math.clamp(killAge * killAge, 0, 1)
		killBanner.TextTransparency = killFade
		killBanner.TextStrokeTransparency = math.clamp(0.6 + killAge, 0, 1)
		killDetails.TextTransparency = killFade
		killDetails.TextStrokeTransparency = math.clamp(0.6 + killAge, 0, 1)
		-- Pops in big and settles to normal size.
		killScale.Scale += (1 - killScale.Scale) * (1 - math.exp(-14 * dt))

		local coinAge = (now - coinsShownAt) / COIN_POPUP_TIME
		coinPopup.TextTransparency = math.clamp(coinAge * coinAge, 0, 1)
		coinPopup.TextStrokeTransparency = math.clamp(0.6 + coinAge, 0, 1)

		local damageAge = (now - damageShownAt) / DAMAGE_FLASH_TIME
		damageFlash.BackgroundTransparency = math.clamp(0.75 + damageAge * 0.25, 0.75, 1)

		weaponName.Text = if knifeOut then WeaponConfig.Knife.DisplayName else stats.DisplayName
		ammoText.Text = if knifeOut
			then "∞"
			elseif weapon.Reloading then "RELOADING"
			else `{weapon.Ammo} / {stats.MagSize}`
		ammoText.TextSize = if weapon.Reloading and not knifeOut then 24 else 40
		reloadBack.Visible = weapon.Reloading and not knifeOut
		reloadFill.Size = UDim2.fromScale(weapon.ReloadProgress, 1)

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local health = if humanoid then math.max(0, humanoid.Health) else 0
		local maxHealth = if humanoid then humanoid.MaxHealth else WeaponConfig.MaxHealth
		-- The bar slides to the new value instead of jumping.
		shownHealth += (health - shownHealth) * (1 - math.exp(-12 * dt))
		healthFill.Size = UDim2.fromScale(math.clamp(shownHealth / maxHealth, 0, 1), 1)
		healthFill.BackgroundColor3 = if health / maxHealth < 0.35 then RED else WHITE
		healthText.Text = tostring(math.ceil(health))
	end)
end

return WeaponHud
