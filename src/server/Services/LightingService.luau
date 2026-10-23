--!strict
-- Sets up the game's look: warm, crisp light with a little contrast and color, a
-- soft atmosphere, light sun rays and only a hint of bloom (nothing that blurs).
-- Lighting technology (Future) is set in default.project.json, since scripts
-- can't change it.

local Lighting = game:GetService("Lighting")

local LightingService = {}

-- Per-map settings on top of the shared look (see each map's Lighting table).
export type Preset = {
	ClockTime: number,
	Brightness: number,
	OutdoorAmbient: Color3,
	AtmosphereColor: Color3,
	AtmosphereDecay: Color3,
	AtmosphereDensity: number,
	AtmosphereHaze: number,
	Tint: Color3,
	SunRays: number,
}

local function ensure(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local effect = Instance.new(className)
	effect.Name = name
	effect.Parent = Lighting
	return effect
end

function LightingService.Start()
	Lighting.ClockTime = 16.2 -- late afternoon: long shadows, warm light
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(70, 66, 78)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 120, 132)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.15

	local color = ensure("ColorCorrectionEffect", "GameColor") :: ColorCorrectionEffect
	color.Contrast = 0.05
	color.Saturation = 0.1
	color.Brightness = 0.02
	color.TintColor = Color3.fromRGB(255, 250, 244)

	local rays = ensure("SunRaysEffect", "GameSunRays") :: SunRaysEffect
	rays.Intensity = 0.05
	rays.Spread = 0.6

	local bloom = ensure("BloomEffect", "GameBloom") :: BloomEffect
	bloom.Intensity = 0.35
	bloom.Size = 18
	bloom.Threshold = 1.6

	local atmosphere = ensure("Atmosphere", "GameAtmosphere") :: Atmosphere
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(230, 200, 180)
	atmosphere.Decay = Color3.fromRGB(120, 100, 110)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2
end

function LightingService.Apply(preset: Preset)
	Lighting.ClockTime = preset.ClockTime
	Lighting.Brightness = preset.Brightness
	Lighting.OutdoorAmbient = preset.OutdoorAmbient
	local atmosphere = ensure("Atmosphere", "GameAtmosphere") :: Atmosphere
	atmosphere.Color = preset.AtmosphereColor
	atmosphere.Decay = preset.AtmosphereDecay
	atmosphere.Density = preset.AtmosphereDensity
	atmosphere.Haze = preset.AtmosphereHaze
	local color = ensure("ColorCorrectionEffect", "GameColor") :: ColorCorrectionEffect
	color.TintColor = preset.Tint
	local rays = ensure("SunRaysEffect", "GameSunRays") :: SunRaysEffect
	rays.Intensity = preset.SunRays
end

return LightingService
