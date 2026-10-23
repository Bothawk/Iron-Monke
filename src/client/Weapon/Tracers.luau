--!strict
-- Thin bullet tracers that flash and fade. A small pool is reused so shooting
-- never creates new parts. Tracers have CanQuery off, so raycasts pass through them.

local TweenService = game:GetService("TweenService")

local POOL_SIZE = 12
local WIDTH = 0.06
local START_TRANSPARENCY = 0.15
local FADE_INFO = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local COLOR = Color3.fromRGB(255, 225, 170)

local Tracers = {}

local folder: Folder? = nil
local pool: { Part } = {}
local nextIndex = 1

local function ensurePool(): { Part }
	if folder and folder.Parent then
		return pool
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = "Tracers"
	table.clear(pool)
	for _ = 1, POOL_SIZE do
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = COLOR
		part.Transparency = 1
		part.Size = Vector3.new(WIDTH, WIDTH, 1)
		part.Parent = newFolder
		table.insert(pool, part)
	end
	newFolder.Parent = workspace
	folder = newFolder
	return pool
end

function Tracers.Show(from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local parts = ensurePool()
	local part = parts[nextIndex]
	nextIndex = nextIndex % #parts + 1

	part.Size = Vector3.new(WIDTH, WIDTH, length)
	part.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	part.Transparency = START_TRANSPARENCY
	TweenService:Create(part, FADE_INFO, { Transparency = 1 }):Play()
end

return Tracers
