--!strict
-- Every player setting: what the settings menu shows, the default, and the allowed
-- range. The server uses Sanitize to check values before saving them.

export type Kind = "Slider" | "Toggle" | "Choice"

export type Setting = {
	Id: string,
	Label: string,
	Category: string,
	Kind: Kind,
	Default: any,
	Min: number?,
	Max: number?,
	Step: number?,
	Decimals: number?, -- how many decimals the menu shows for sliders
	Options: { string }?,
	Hint: string?,
}

local CROSSHAIR_COLORS: { [string]: Color3 } = {
	White = Color3.fromRGB(255, 255, 255),
	Green = Color3.fromRGB(80, 255, 120),
	Cyan = Color3.fromRGB(80, 230, 255),
	Yellow = Color3.fromRGB(255, 230, 70),
	Pink = Color3.fromRGB(255, 110, 200),
	Red = Color3.fromRGB(255, 70, 70),
	Orange = Color3.fromRGB(255, 150, 50),
}

local LIST: { Setting } = {
	-- Controls
	{
		Id = "Sensitivity",
		Label = "Mouse sensitivity",
		Category = "Controls",
		Kind = "Slider",
		Default = 1,
		Min = 0.05,
		Max = 3,
		Step = 0.05,
		Decimals = 2,
	},
	{
		Id = "ScopedSensitivity",
		Label = "Scoped sensitivity",
		Category = "Controls",
		Kind = "Slider",
		Default = 1,
		Min = 0.1,
		Max = 2,
		Step = 0.05,
		Decimals = 2,
		Hint = "1 = moves the same on screen as unscoped",
	},
	{
		Id = "ToggleScope",
		Label = "Toggle scope (click instead of hold)",
		Category = "Controls",
		Kind = "Toggle",
		Default = false,
	},
	{
		Id = "ToggleSprint",
		Label = "Toggle sprint",
		Category = "Controls",
		Kind = "Toggle",
		Default = false,
	},
	{
		Id = "AutoSprint",
		Label = "Auto-sprint (controller / touch)",
		Category = "Controls",
		Kind = "Toggle",
		Default = true,
		Hint = "Push the stick all the way forward to sprint",
	},
	{
		Id = "TouchButtonScale",
		Label = "Touch button size",
		Category = "Controls",
		Kind = "Slider",
		Default = 1,
		Min = 0.6,
		Max = 1.6,
		Step = 0.05,
		Decimals = 2,
	},

	-- Video
	{
		Id = "FieldOfView",
		Label = "Field of view",
		Category = "Video",
		Kind = "Slider",
		Default = 80,
		Min = 70,
		Max = 100,
		Step = 1,
		Decimals = 0,
		Hint = "Roblox measures FOV vertically; 80 is about 110 horizontal",
	},
	{
		Id = "Graphics",
		Label = "Graphics quality",
		Category = "Video",
		Kind = "Choice",
		Default = "High",
		Options = { "Low", "Medium", "High" },
		Hint = "Low turns off shadows and most effects for more FPS",
	},
	{ Id = "CameraMotion", Label = "Camera motion (tilt, dips)", Category = "Video", Kind = "Toggle", Default = true },
	{ Id = "ViewBob", Label = "Weapon bob", Category = "Video", Kind = "Toggle", Default = true },
	{ Id = "SpeedLines", Label = "Speed lines", Category = "Video", Kind = "Toggle", Default = true },
	{ Id = "ShowFps", Label = "Show FPS and ping", Category = "Video", Kind = "Toggle", Default = false },

	-- Crosshair
	{
		Id = "CrosshairStyle",
		Label = "Style",
		Category = "Crosshair",
		Kind = "Choice",
		Default = "Cross",
		Options = { "Cross", "Dot", "Cross + dot", "Circle" },
	},
	{
		Id = "CrosshairColor",
		Label = "Color",
		Category = "Crosshair",
		Kind = "Choice",
		Default = "White",
		Options = { "White", "Green", "Cyan", "Yellow", "Pink", "Red", "Orange" },
	},
	{
		Id = "CrosshairSize",
		Label = "Size",
		Category = "Crosshair",
		Kind = "Slider",
		Default = 9,
		Min = 3,
		Max = 24,
		Step = 1,
		Decimals = 0,
	},
	{
		Id = "CrosshairGap",
		Label = "Gap",
		Category = "Crosshair",
		Kind = "Slider",
		Default = 4,
		Min = 0,
		Max = 16,
		Step = 1,
		Decimals = 0,
	},
	{
		Id = "CrosshairThickness",
		Label = "Thickness",
		Category = "Crosshair",
		Kind = "Slider",
		Default = 2,
		Min = 1,
		Max = 5,
		Step = 1,
		Decimals = 0,
	},
	{ Id = "CrosshairOutline", Label = "Outline", Category = "Crosshair", Kind = "Toggle", Default = true },
	{
		Id = "ShowFlowRing",
		Label = "Flow ring around crosshair",
		Category = "Crosshair",
		Kind = "Toggle",
		Default = true,
	},

	-- Audio
	{
		Id = "MasterVolume",
		Label = "Master",
		Category = "Audio",
		Kind = "Slider",
		Default = 1,
		Min = 0,
		Max = 1,
		Step = 0.05,
		Decimals = 2,
	},
	{
		Id = "EffectsVolume",
		Label = "Effects",
		Category = "Audio",
		Kind = "Slider",
		Default = 1,
		Min = 0,
		Max = 1,
		Step = 0.05,
		Decimals = 2,
	},
	{
		Id = "HitsVolume",
		Label = "Hit and kill sounds",
		Category = "Audio",
		Kind = "Slider",
		Default = 1,
		Min = 0,
		Max = 1,
		Step = 0.05,
		Decimals = 2,
	},
	{
		Id = "UiVolume",
		Label = "Menus",
		Category = "Audio",
		Kind = "Slider",
		Default = 1,
		Min = 0,
		Max = 1,
		Step = 0.05,
		Decimals = 2,
	},
}

local BY_ID: { [string]: Setting } = {}
for _, setting in LIST do
	BY_ID[setting.Id] = setting
end

local SettingsConfig = {
	List = LIST,
	ById = BY_ID,
	Categories = { "Controls", "Video", "Crosshair", "Audio" },
	CrosshairColors = CROSSHAIR_COLORS,
}

function SettingsConfig.Defaults(): { [string]: any }
	local values = {}
	for _, setting in LIST do
		values[setting.Id] = setting.Default
	end
	return values
end

-- Returns a safe version of `value` for setting `id`, or nil if it can't be one.
function SettingsConfig.Sanitize(id: string, value: any): any
	local setting = BY_ID[id]
	if not setting then
		return nil
	end
	if setting.Kind == "Toggle" then
		return if typeof(value) == "boolean" then value else nil
	elseif setting.Kind == "Choice" then
		local options = setting.Options :: { string }
		return if typeof(value) == "string" and table.find(options, value) then value else nil
	end
	if typeof(value) ~= "number" or value ~= value then
		return nil
	end
	local min, max, step = setting.Min :: number, setting.Max :: number, setting.Step or 0
	local clamped = math.clamp(value, min, max)
	if step > 0 then
		clamped = math.clamp(min + math.floor((clamped - min) / step + 0.5) * step, min, max)
	end
	return clamped
end

-- Every known setting, filled from `saved` where valid and defaults elsewhere.
function SettingsConfig.Merge(saved: any): { [string]: any }
	local values = SettingsConfig.Defaults()
	if typeof(saved) == "table" then
		for id in values do
			local clean = SettingsConfig.Sanitize(id, saved[id])
			if clean ~= nil then
				values[id] = clean
			end
		end
	end
	return values
end

return SettingsConfig
