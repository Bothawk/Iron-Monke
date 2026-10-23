--!strict
-- Applies the Graphics quality setting on this player's screen only:
--   High: shadows, bloom and sun rays on.
--   Medium: no sun rays.
--   Low: no shadows, bloom or sun rays (best FPS).
-- Impact effects read the same setting (see EffectsController). The server never
-- changes these switches after startup, so setting them here is safe.

local Lighting = game:GetService("Lighting")

local SettingsController = require(script.Parent.SettingsController)

local GraphicsController = {}

local function setEnabled(name: string, enabled: boolean)
	local effect = Lighting:FindFirstChild(name)
	if effect and effect:IsA("PostEffect") then
		effect.Enabled = enabled
	end
end

local function apply()
	local quality = SettingsController.Get("Graphics")
	Lighting.GlobalShadows = quality ~= "Low"
	setEnabled("GameBloom", quality ~= "Low")
	setEnabled("GameSunRays", quality == "High")
end

function GraphicsController.Start()
	SettingsController.Changed:Connect(function(id: string)
		if id == "Graphics" then
			apply()
		end
	end)
	-- The effects may replicate a moment after the player joins.
	Lighting.ChildAdded:Connect(function()
		task.defer(apply)
	end)
	apply()
end

return GraphicsController
