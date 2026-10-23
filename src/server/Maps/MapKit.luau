--!strict
-- Building blocks for maps made in code: parts, ramps, stairs, buildings, signs,
-- spawn points, Slingshot ramps and small decorations.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.Shared.Config.MovementConfig)

local MapKit = {}

export type BuildingStyle = {
	Wall: Color3,
	WallMaterial: Enum.Material,
	Roof: Color3,
	RoofMaterial: Enum.Material,
	Trim: Color3,
	Window: Color3?,
}

function MapKit.Part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Decoration that players pass through and shots and movement probes ignore.
function MapKit.Ghost(part: BasePart): BasePart
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

-- An invisible solid wall (map edges, smoothing out snag points).
function MapKit.Blocker(parent: Instance, size: Vector3, cframe: CFrame): Part
	local part = MapKit.Part(parent, "Blocker", size, cframe, Color3.new(1, 1, 1))
	part.Transparency = 1
	part.CastShadow = false
	return part
end

-- A ramp whose top surface starts at `start` (usually on the ground) and climbs
-- `angleDegrees` along the flat `direction`. Returns the ramp and its top end.
function MapKit.Ramp(
	parent: Instance,
	name: string,
	start: Vector3,
	direction: Vector3,
	length: number,
	angleDegrees: number,
	width: number,
	color: Color3,
	material: Enum.Material?
): (Part, Vector3)
	local forward = Vector3.new(direction.X, 0, direction.Z).Unit
	local angle = math.rad(angleDegrees)
	-- Look along `forward`, then tip the front up.
	local rotation = CFrame.lookAt(Vector3.zero, forward) * CFrame.Angles(angle, 0, 0)
	local rise = forward * math.cos(angle) + Vector3.yAxis * math.sin(angle)
	-- Shift down half the thickness so the top surface meets the ground with no lip.
	local center = start + rise * (length / 2) - rotation.UpVector * 0.5
	local ramp =
		MapKit.Part(parent, name, Vector3.new(width, 1, length), CFrame.new(center) * rotation, color, material)
	return ramp, start + rise * length
end

-- Steps climbing from `bottom` along `direction`. Each step is a solid block down to
-- the ground so nothing can be walked under. Returns the top landing position.
function MapKit.Stairs(
	parent: Instance,
	name: string,
	bottom: Vector3,
	direction: Vector3,
	steps: number,
	rise: number,
	run: number,
	width: number,
	color: Color3,
	material: Enum.Material?
): Vector3
	local forward = Vector3.new(direction.X, 0, direction.Z).Unit
	local facing = CFrame.lookAt(Vector3.zero, forward)
	for i = 1, steps do
		local height = rise * i
		local center = bottom + forward * (run * (i - 0.5)) + Vector3.new(0, height / 2, 0)
		MapKit.Part(
			parent,
			`{name}Step{i}`,
			Vector3.new(width, height, run),
			CFrame.new(center) * facing,
			color,
			material
		)
	end
	return bottom + forward * (run * steps) + Vector3.new(0, rise * steps, 0)
end

-- A solid building with a roof slab, a trim band and a few dark windows on the
-- long sides. `base` is the center of its footprint on the ground.
function MapKit.Building(
	parent: Instance,
	name: string,
	base: Vector3,
	size: Vector3,
	style: BuildingStyle,
	parapet: number?
): Model
	local model = Instance.new("Model")
	model.Name = name
	local height = size.Y
	MapKit.Part(model, "Walls", size, CFrame.new(base + Vector3.new(0, height / 2, 0)), style.Wall, style.WallMaterial)
	MapKit.Part(
		model,
		"Roof",
		Vector3.new(size.X + 1, 0.6, size.Z + 1),
		CFrame.new(base + Vector3.new(0, height + 0.3, 0)),
		style.Roof,
		style.RoofMaterial
	)
	MapKit.Ghost(
		MapKit.Part(
			model,
			"Trim",
			Vector3.new(size.X + 0.4, 0.5, size.Z + 0.4),
			CFrame.new(base + Vector3.new(0, height - 2, 0)),
			style.Trim,
			Enum.Material.SmoothPlastic
		)
	)

	if parapet and parapet > 0 then
		local top = base.Y + height + 0.6
		local half = Vector3.new(size.X / 2 + 0.5, 0, size.Z / 2 + 0.5)
		for _, side in { -1, 1 } do
			MapKit.Part(
				model,
				"Parapet",
				Vector3.new(size.X + 1, parapet, 0.8),
				CFrame.new(base.X, top + parapet / 2, base.Z + side * half.Z),
				style.Trim
			)
		end
	end

	local windowColor = style.Window
	if windowColor then
		local columns = math.max(1, math.floor(size.X / 9))
		local rows = math.max(1, math.floor((height - 4) / 7))
		for _, side in { -1, 1 } do
			for column = 1, columns do
				for row = 1, rows do
					local x = base.X - size.X / 2 + (column - 0.5) * (size.X / columns)
					local y = base.Y + 3 + (row - 0.5) * ((height - 4) / rows)
					local z = base.Z + side * (size.Z / 2 + 0.05)
					MapKit.Ghost(
						MapKit.Part(
							model,
							"Window",
							Vector3.new(3, 4, 0.2),
							CFrame.new(x, y, z),
							windowColor,
							Enum.Material.Glass
						)
					)
				end
			end
		end
	end

	model.Parent = parent
	return model
end

function MapKit.Sign(parent: Instance, text: string, position: Vector3, facing: Vector3, width: number?)
	local sign = MapKit.Part(
		parent,
		"Sign",
		Vector3.new(width or 16, 4, 0.4),
		CFrame.lookAt(position, facing),
		Color3.fromRGB(30, 30, 36)
	)
	MapKit.Ghost(sign)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = gui
end

-- A spawn point. It's a real (invisible) SpawnLocation so Roblox spawns players
-- somewhere valid; SpawnService then moves them to the safest one.
function MapKit.Spawn(parent: Instance, position: Vector3, lookAt: Vector3)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	local flatLook = Vector3.new(lookAt.X, position.Y, lookAt.Z)
	spawn.CFrame = CFrame.lookAt(position + Vector3.new(0, 0.5, 0), flatLook + Vector3.new(0, 0.5, 0))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.CastShadow = false
	spawn.Duration = 0
	spawn.Neutral = true
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn.Parent = parent
end

-- A Slingshot launch ramp with its accent stripe, sliding along `direction`.
function MapKit.Slingshot(parent: Instance, start: Vector3, direction: Vector3, color: Color3, accent: Color3)
	local ramp = MapKit.Ramp(parent, "Slingshot", start, direction, 18, 25, 12, color, Enum.Material.Concrete)
	CollectionService:AddTag(ramp, MovementConfig.Slingshot.Tag)
	local stripe = MapKit.Part(
		parent,
		"SlingshotStripe",
		Vector3.new(1.2, 0.1, ramp.Size.Z),
		ramp.CFrame * CFrame.new(0, 0.55, 0),
		accent,
		Enum.Material.Neon
	)
	MapKit.Ghost(stripe)
end

function MapKit.Palm(parent: Instance, base: Vector3, height: number?)
	local trunkHeight = height or 14
	local model = Instance.new("Model")
	model.Name = "Palm"
	local trunk = MapKit.Part(
		model,
		"Trunk",
		Vector3.new(1.2, trunkHeight, 1.2),
		CFrame.new(base + Vector3.new(0, trunkHeight / 2, 0)) * CFrame.Angles(0, 0, math.rad(4)),
		Color3.fromRGB(120, 92, 66),
		Enum.Material.Wood
	)
	trunk.CanCollide = true
	local top = base + Vector3.new(0.5, trunkHeight, 0)
	for i = 0, 5 do
		local angle = i * math.pi / 3
		local frond = MapKit.Part(
			model,
			"Frond",
			Vector3.new(1.6, 0.3, 7),
			CFrame.new(top) * CFrame.Angles(0, angle, 0) * CFrame.new(0, -0.6, -3) * CFrame.Angles(math.rad(-18), 0, 0),
			Color3.fromRGB(70, 140, 80),
			Enum.Material.Grass
		)
		MapKit.Ghost(frond)
	end
	model.Parent = parent
end

function MapKit.Lamp(parent: Instance, base: Vector3)
	local post = MapKit.Part(
		parent,
		"LampPost",
		Vector3.new(0.5, 9, 0.5),
		CFrame.new(base + Vector3.new(0, 4.5, 0)),
		Color3.fromRGB(40, 40, 46),
		Enum.Material.Metal
	)
	post.CanCollide = true
	local bulb = MapKit.Part(
		parent,
		"LampLight",
		Vector3.new(1.1, 1.1, 1.1),
		CFrame.new(base + Vector3.new(0, 9.4, 0)),
		Color3.fromRGB(255, 214, 160),
		Enum.Material.Neon
	)
	MapKit.Ghost(bulb)
	local light = Instance.new("PointLight")
	light.Range = 14
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 200, 150)
	light.Shadows = false
	light.Parent = bulb
end

function MapKit.Planter(parent: Instance, base: Vector3, size: Vector3, stone: Color3)
	MapKit.Part(
		parent,
		"Planter",
		size,
		CFrame.new(base + Vector3.new(0, size.Y / 2, 0)),
		stone,
		Enum.Material.Limestone
	)
	MapKit.Ghost(
		MapKit.Part(
			parent,
			"Plants",
			Vector3.new(size.X - 0.8, 1.2, size.Z - 0.8),
			CFrame.new(base + Vector3.new(0, size.Y + 0.4, 0)),
			Color3.fromRGB(86, 150, 84),
			Enum.Material.Grass
		)
	)
end

return MapKit
