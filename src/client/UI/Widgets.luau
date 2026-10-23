--!strict
-- Small UI building blocks with one consistent look: buttons, text, sliders,
-- toggles, choice pickers and stat bars. Hover and click sounds included.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Widgets = {}

Widgets.Colors = {
	Background = Color3.fromRGB(14, 14, 18),
	Panel = Color3.fromRGB(24, 24, 30),
	PanelLight = Color3.fromRGB(36, 36, 44),
	Text = Color3.fromRGB(240, 240, 240),
	Muted = Color3.fromRGB(150, 150, 160),
	Accent = Color3.fromRGB(255, 140, 40),
	Good = Color3.fromRGB(90, 220, 120),
	Bad = Color3.fromRGB(255, 80, 80),
	Gold = Color3.fromRGB(255, 210, 80),
}
local C = Widgets.Colors
local HOVER = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Set by MenuController so widgets don't depend on the sound system directly.
Widgets.PlaySound = function(_name: string) end

function Widgets.Corner(parent: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 6)
	corner.Parent = parent
end

function Widgets.Padding(parent: Instance, all: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, all)
	padding.PaddingBottom = UDim.new(0, all)
	padding.PaddingLeft = UDim.new(0, all)
	padding.PaddingRight = UDim.new(0, all)
	padding.Parent = parent
end

function Widgets.List(parent: Instance, spacing: number, horizontal: boolean?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, spacing)
	layout.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	layout.Parent = parent
	return layout
end

function Widgets.Frame(parent: Instance, props: { [string]: any }?): Frame
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = C.Panel
	for key, value in props or {} do
		(frame :: any)[key] = value
	end
	frame.Parent = parent
	return frame
end

function Widgets.Text(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextColor3 = C.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Size = UDim2.new(1, 0, 0, 20)
	for key, value in props or {} do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

-- A button that grows slightly and brightens on hover.
function Widgets.Button(parent: Instance, text: string, onClick: () -> (), props: { [string]: any }?): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.BackgroundColor3 = C.PanelLight
	button.Font = Enum.Font.GothamBold
	button.TextSize = 15
	button.TextColor3 = C.Text
	button.Text = text
	button.Size = UDim2.fromOffset(120, 34)
	for key, value in props or {} do
		(button :: any)[key] = value
	end
	Widgets.Corner(button)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	local baseColor = button.BackgroundColor3
	button.MouseEnter:Connect(function()
		Widgets.PlaySound("UiHover")
		TweenService:Create(scale, HOVER, { Scale = 1.04 }):Play()
		TweenService:Create(button, HOVER, { BackgroundColor3 = baseColor:Lerp(Color3.new(1, 1, 1), 0.12) }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, HOVER, { Scale = 1 }):Play()
		TweenService:Create(button, HOVER, { BackgroundColor3 = baseColor }):Play()
	end)
	button.MouseButton1Click:Connect(function()
		Widgets.PlaySound("UiClick")
		onClick()
	end)
	button.Parent = parent
	return button
end

-- Changes a button's resting color (keeps hover working).
function Widgets.SetButtonColor(button: TextButton, color: Color3)
	button.BackgroundColor3 = color
end

local function row(parent: Instance, labelText: string, order: number): Frame
	local container = Widgets.Frame(parent, {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = C.PanelLight,
		BackgroundTransparency = 0.4,
		LayoutOrder = order,
	})
	Widgets.Corner(container)
	Widgets.Text(container, labelText, {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(0.5, -12, 1, 0),
		TextSize = 14,
	})
	return container
end

-- A draggable slider with − and + buttons. `format` turns the value into text.
function Widgets.Slider(
	parent: Instance,
	labelText: string,
	order: number,
	min: number,
	max: number,
	step: number,
	value: number,
	format: (number) -> string,
	onChange: (number) -> ()
): (Frame, (number) -> ())
	local container = row(parent, labelText, order)
	local valueText = Widgets.Text(container, "", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 0),
		Size = UDim2.fromOffset(60, 40),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.Accent,
	})
	local track = Widgets.Frame(container, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -110, 0.5, 0),
		Size = UDim2.new(0.5, -150, 0, 6),
		BackgroundColor3 = C.Background,
		Active = true,
	})
	Widgets.Corner(track, 3)
	local fill = Widgets.Frame(track, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Accent })
	Widgets.Corner(fill, 3)
	local knob = Widgets.Frame(track, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = C.Text,
	})
	Widgets.Corner(knob, 7)

	local current = value
	local function show(v: number)
		current = v
		local alpha = (v - min) / (max - min)
		fill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.fromScale(alpha, 0.5)
		valueText.Text = format(v)
	end
	local function setValue(v: number)
		local snapped = math.clamp(min + math.floor((v - min) / step + 0.5) * step, min, max)
		if math.abs(snapped - current) > 1e-6 then
			show(snapped)
			onChange(snapped)
		end
	end
	show(value)

	local dragging = false
	local function dragTo(x: number)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		setValue(min + alpha * (max - min))
	end
	track.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			dragTo(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			dragTo(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)

	-- − sits just right of the label, + just left of the value: [label][−][track][+][value]
	Widgets.Button(container, "−", function()
		setValue(current - step)
	end, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0.5, 8, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		TextSize = 16,
	})
	Widgets.Button(container, "+", function()
		setValue(current + step)
	end, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -78, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		TextSize = 16,
	})
	return container, show
end

-- An on/off switch.
function Widgets.Toggle(
	parent: Instance,
	labelText: string,
	order: number,
	value: boolean,
	onChange: (boolean) -> ()
): (Frame, (boolean) -> ())
	local container = row(parent, labelText, order)
	local switch = Instance.new("TextButton")
	switch.AutoButtonColor = false
	switch.Text = ""
	switch.AnchorPoint = Vector2.new(1, 0.5)
	switch.Position = UDim2.new(1, -12, 0.5, 0)
	switch.Size = UDim2.fromOffset(46, 24)
	switch.BorderSizePixel = 0
	Widgets.Corner(switch, 12)
	switch.Parent = container
	local knob = Widgets.Frame(switch, {
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = C.Text,
	})
	Widgets.Corner(knob, 9)

	local current = value
	local function show(v: boolean)
		current = v
		TweenService:Create(switch, HOVER, { BackgroundColor3 = if v then C.Accent else C.Background }):Play()
		TweenService
			:Create(knob, HOVER, { Position = if v then UDim2.new(1, -21, 0.5, 0) else UDim2.new(0, 3, 0.5, 0) })
			:Play()
	end
	show(value)
	switch.MouseButton1Click:Connect(function()
		Widgets.PlaySound("UiClick")
		show(not current)
		onChange(current)
	end)
	return container, show
end

-- A "< option >" picker.
function Widgets.Choice(
	parent: Instance,
	labelText: string,
	order: number,
	options: { string },
	value: string,
	onChange: (string) -> ()
): (Frame, (string) -> ())
	local container = row(parent, labelText, order)
	local valueText = Widgets.Text(container, value, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -46, 0, 0),
		Size = UDim2.fromOffset(150, 40),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.Accent,
	})
	local index = table.find(options, value) or 1
	local function show(v: string)
		index = table.find(options, v) or 1
		valueText.Text = options[index]
	end
	for _, sign in { -1, 1 } do
		Widgets.Button(container, if sign < 0 then "<" else ">", function()
			index = (index - 1 + sign) % #options + 1
			valueText.Text = options[index]
			onChange(options[index])
		end, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = if sign < 0 then UDim2.new(1, -200, 0.5, 0) else UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(28, 26),
		})
	end
	return container, show
end

-- A labeled bar from 0 to 1. Call the returned function with (value, preview?)
-- where preview shows a change in green (better) or red (worse).
function Widgets.StatBar(parent: Instance, labelText: string, order: number): (Frame, (number, number?) -> ())
	local container = Widgets.Frame(parent, {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	})
	Widgets.Text(container, labelText, { Size = UDim2.new(0.35, 0, 1, 0), TextSize = 13, TextColor3 = C.Muted })
	local track = Widgets.Frame(container, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0.63, 0, 0, 6),
		BackgroundColor3 = C.Background,
	})
	Widgets.Corner(track, 3)
	local preview = Widgets.Frame(track, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Good })
	Widgets.Corner(preview, 3)
	local fill = Widgets.Frame(track, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Text })
	Widgets.Corner(fill, 3)
	local function show(v: number, previewValue: number?)
		local base = math.clamp(v, 0, 1)
		local other = math.clamp(previewValue or v, 0, 1)
		if other > base then
			fill.Size = UDim2.fromScale(base, 1)
			preview.Size = UDim2.fromScale(other, 1)
			preview.BackgroundColor3 = C.Good
		else
			fill.Size = UDim2.fromScale(other, 1)
			preview.Size = UDim2.fromScale(base, 1)
			preview.BackgroundColor3 = if other < base then C.Bad else C.Text
		end
	end
	show(0)
	return container, show
end

return Widgets
