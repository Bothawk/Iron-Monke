--!strict
-- TEST RANGE: a gray map with labeled movement areas (slopes, wall-kick alley,
-- Slingshot, gap jumps) and a shooting range with dummies. Good for tuning.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.MovementConfig)

local COLORS = {
	Floor = Color3.fromRGB(140, 140, 145),
	Grid = Color3.fromRGB(95, 95, 100),
	Block = Color3.fromRGB(165, 165, 170),
	Sign = Color3.fromRGB(30, 30, 36),
	Accent = Color3.fromRGB(255, 140, 40),
}

local FLOOR_SIZE = 600
local GRID_SPACING = 20

local TestRange = {
	Id = "TestRange",
	DisplayName = "Test Range",
	KillY = -50,
	HasDummies = true, -- TestDummyService fills the shooting range
	Lighting = {
		ClockTime = 14.5,
		Brightness = 2.6,
		OutdoorAmbient = Color3.fromRGB(128, 120, 132),
		AtmosphereColor = Color3.fromRGB(220, 220, 230),
		AtmosphereDecay = Color3.fromRGB(120, 120, 140),
		AtmosphereDensity = 0.2,
		AtmosphereHaze = 0.6,
		Tint = Color3.fromRGB(255, 255, 255),
		SunRays = 0.04,
	},
}

local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color or COLORS.Block
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Decoration that players walk through and the movement probes ignore.
local function makeGhost(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

local function makeSign(parent: Instance, text: string, position: Vector3, facing: Vector3)
	local sign = makePart(parent, "Sign", Vector3.new(16, 4, 0.4), CFrame.lookAt(position, facing), COLORS.Sign)
	makeGhost(sign)

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

-- A ramp that starts on the floor at (x, 0, zStart) and rises toward +Z.
-- Returns the height and Z where its top edge ends.
local function makeRamp(
	parent: Instance,
	name: string,
	x: number,
	zStart: number,
	length: number,
	angleDegrees: number,
	width: number
): (Part, number, number)
	local angle = math.rad(angleDegrees)
	local rotation = CFrame.Angles(-angle, 0, 0)
	-- Shift down half the thickness so the top surface meets the floor with no lip.
	local center = Vector3.new(x, length / 2 * math.sin(angle), zStart + length / 2 * math.cos(angle))
		- rotation.UpVector * 0.5
	local ramp = makePart(parent, name, Vector3.new(width, 1, length), CFrame.new(center) * rotation)
	return ramp, length * math.sin(angle), zStart + length * math.cos(angle)
end

-- A platform whose top surface is at topY, spanning zStart to zStart + length.
local function makePlatform(
	parent: Instance,
	name: string,
	x: number,
	topY: number,
	zStart: number,
	length: number,
	width: number
): Part
	return makePart(parent, name, Vector3.new(width, 1, length), CFrame.new(x, topY - 0.5, zStart + length / 2))
end

local function buildFloor(map: Instance)
	makePart(map, "Floor", Vector3.new(FLOOR_SIZE, 2, FLOOR_SIZE), CFrame.new(0, -1, 0), COLORS.Floor)

	-- Grid lines make speed easy to read while moving.
	local grid = Instance.new("Folder")
	grid.Name = "Grid"
	grid.Parent = map
	local half = FLOOR_SIZE / 2
	for offset = -half, half, GRID_SPACING do
		makeGhost(makePart(grid, "LineX", Vector3.new(FLOOR_SIZE, 0.05, 0.3), CFrame.new(0, 0.03, offset), COLORS.Grid))
		makeGhost(makePart(grid, "LineZ", Vector3.new(0.3, 0.05, FLOOR_SIZE), CFrame.new(offset, 0.03, 0), COLORS.Grid))
	end
end

local function buildSlideSlopes(map: Instance)
	local spawnPoint = Vector3.new(0, 10, 0)
	for i, angle in { 10, 20, 30 } do
		local x = -35 - i * 25
		local _, height, zEnd = makeRamp(map, `Slope{angle}`, x, 20, 60, angle, 18)
		makePlatform(map, `Slope{angle}Top`, x, height, zEnd, 24, 18)
		makeSign(map, `SLIDE SLOPE {angle}°`, Vector3.new(x, 10, 14), spawnPoint)
	end
end

local function buildWallKickAlley(map: Instance)
	-- Two walls with a 9 stud gap between their inner faces.
	makePart(map, "AlleyWallLeft", Vector3.new(2, 40, 80), CFrame.new(70, 20, 60))
	makePart(map, "AlleyWallRight", Vector3.new(2, 40, 80), CFrame.new(81, 20, 60))
	makePlatform(map, "AlleyLedge", 75.5, 16, 90, 10, 9)
	makeSign(map, "WALL KICK ALLEY (2 kicks max)", Vector3.new(75.5, 10, 14), Vector3.new(0, 10, 0))

	makePart(map, "SingleWall", Vector3.new(2, 40, 40), CFrame.new(115, 20, 60))
	makeSign(map, "SINGLE WALL", Vector3.new(115, 10, 34), Vector3.new(0, 10, 0))
end

local function buildSlingshot(map: Instance)
	local ramp, _, rampEnd = makeRamp(map, "Slingshot", 0, 40, 18, 25, 14)
	CollectionService:AddTag(ramp, Config.Slingshot.Tag)

	local stripe = makePart(
		map,
		"SlingshotStripe",
		Vector3.new(1.2, 0.1, ramp.Size.Z),
		ramp.CFrame * CFrame.new(0, 0.55, 0),
		COLORS.Accent
	)
	stripe.Material = Enum.Material.Neon
	makeGhost(stripe)

	makePlatform(map, "SlingshotLanding", 0, 18, rampEnd + 6, 40, 30)
	makeSign(map, "SLINGSHOT: slide into the stripe", Vector3.new(0, 10, 30), Vector3.new(0, 10, 0))
end

local function buildGapJumps(map: Instance)
	local x = 30
	local _, height, zEnd = makeRamp(map, "GapRamp", x, 20, 46, 10, 10)
	makePlatform(map, "GapStart", x, height, zEnd, 20, 10)

	local z = zEnd + 20
	for _, gap in { 8, 12, 16, 20, 24 } do
		z += gap
		makePlatform(map, `Gap{gap}`, x, height, z, 10, 10)
		makeSign(map, `{gap}`, Vector3.new(x, height + 8, z + 5), Vector3.new(x, height + 8, 0))
		z += 10
	end
	makeSign(map, "GAP JUMPS: build speed first", Vector3.new(x, 10, 14), Vector3.new(0, 10, 0))
end

-- Dummies are added by TestDummyService. This builds the cover wall and signs.
local function buildShootingRange(map: Instance)
	-- Thicker than any sniper can shoot through.
	makePart(map, "RangeCover", Vector3.new(30, 14, 5), CFrame.new(35, 7, -75))
	-- Thin enough for HARPOON to shoot through (at half damage).
	makePart(map, "ThinWall", Vector3.new(30, 14, 1), CFrame.new(-40, 7, -75))
	makeSign(map, "THIN WALL: only HARPOON shoots through", Vector3.new(-40, 17, -74), Vector3.new(0, 17, 0))
	makeSign(map, "SHOOTING RANGE: turn around", Vector3.new(0, 16, 12), Vector3.new(0, 16, 0))
	makeSign(map, "COVER TEST: must NOT be hittable from here", Vector3.new(35, 17, -74), Vector3.new(0, 17, 0))
end

function TestRange.Build(map: Folder)
	buildFloor(map)
	buildSlideSlopes(map)
	buildWallKickAlley(map)
	buildSlingshot(map)
	buildGapJumps(map)
	buildShootingRange(map)

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = map
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	-- Face +Z, toward the test areas.
	spawn.CFrame = CFrame.lookAt(Vector3.new(0, 0.5, 0), Vector3.new(0, 0.5, 1))
	spawn.Duration = 0
	spawn.Color = COLORS.Accent
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Parent = spawns
end

return TestRange
