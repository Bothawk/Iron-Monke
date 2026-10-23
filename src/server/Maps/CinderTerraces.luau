--!strict
-- CINDER TERRACES: a cliffside resort town at golden hour above a teal sea.
-- Three lanes run east to west between raised spawn terraces:
--   North: rooftops with long sightlines and gaps you need momentum to clear.
--   Middle: a plaza around a clock tower, with sloped streets made for sliding.
--   South: tight alleys between houses, 9-stud gaps set up for wall-kick chains,
--          and a promenade along the cliff edge. Falling into the sea is a death.

local MapKit = require(script.Parent.MapKit)

local COLORS = {
	Stone = Color3.fromRGB(234, 224, 208),
	StoneDark = Color3.fromRGB(198, 186, 168),
	Paving = Color3.fromRGB(216, 202, 182),
	Cobble = Color3.fromRGB(176, 160, 142),
	Terracotta = Color3.fromRGB(196, 98, 62),
	Trim = Color3.fromRGB(244, 238, 226),
	Window = Color3.fromRGB(58, 78, 94),
	Accent = Color3.fromRGB(255, 140, 40),
	Teal = Color3.fromRGB(46, 140, 150),
	Coral = Color3.fromRGB(230, 110, 90),
	Rock = Color3.fromRGB(120, 104, 96),
	Clock = Color3.fromRGB(250, 236, 200),
}

local HOUSE: MapKit.BuildingStyle = {
	Wall = COLORS.Stone,
	WallMaterial = Enum.Material.Plaster,
	Roof = COLORS.Terracotta,
	RoofMaterial = Enum.Material.ClayRoofTiles,
	Trim = COLORS.Trim,
	Window = COLORS.Window,
}

local HALF_WIDTH = 256 -- map spans x -256..256
local NORTH_EDGE = 192
local SOUTH_EDGE = -190
local CENTER = Vector3.zero

type Segment = { X0: number, X1: number, Height: number }

local CinderTerraces = {
	Id = "CinderTerraces",
	DisplayName = "Cinder Terraces",
	KillY = -15,
	HasDummies = false,
	Lighting = {
		ClockTime = 17.4,
		Brightness = 2.4,
		OutdoorAmbient = Color3.fromRGB(150, 122, 120),
		AtmosphereColor = Color3.fromRGB(255, 196, 166),
		AtmosphereDecay = Color3.fromRGB(176, 108, 118),
		AtmosphereDensity = 0.3,
		AtmosphereHaze = 1.6,
		Tint = Color3.fromRGB(255, 242, 228),
		SunRays = 0.08,
	},
}

local function ground(map: Instance)
	-- Three strips with different paving so each lane reads differently.
	local width = HALF_WIDTH * 2
	MapKit.Part(
		map,
		"NorthGround",
		Vector3.new(width, 4, NORTH_EDGE - 60),
		CFrame.new(0, -2, (NORTH_EDGE + 60) / 2),
		COLORS.Paving,
		Enum.Material.Limestone
	)
	MapKit.Part(
		map,
		"PlazaGround",
		Vector3.new(width, 4, 120),
		CFrame.new(0, -2, 0),
		COLORS.Paving,
		Enum.Material.Pavement
	)
	MapKit.Part(
		map,
		"SouthGround",
		Vector3.new(width, 4, -60 - SOUTH_EDGE),
		CFrame.new(0, -2, (SOUTH_EDGE - 60) / 2),
		COLORS.Cobble,
		Enum.Material.Cobblestone
	)

	-- The cliff face and the sea below it.
	MapKit.Part(
		map,
		"Cliff",
		Vector3.new(width + 40, 60, 8),
		CFrame.new(0, -30, SOUTH_EDGE - 4),
		COLORS.Rock,
		Enum.Material.Rock
	)
	workspace.Terrain:FillBlock(CFrame.new(0, -48, -420), Vector3.new(1600, 8, 460), Enum.Material.Water)
	MapKit.Part(
		map,
		"CliffRailing",
		Vector3.new(width, 3, 1),
		CFrame.new(0, 1.5, SOUTH_EDGE + 1),
		COLORS.Trim,
		Enum.Material.Limestone
	)
end

local function boundaries(map: Instance)
	local depth = NORTH_EDGE - SOUTH_EDGE
	local middleZ = (NORTH_EDGE + SOUTH_EDGE) / 2
	for _, side in { -1, 1 } do
		MapKit.Part(
			map,
			"EdgeWall",
			Vector3.new(4, 14, depth),
			CFrame.new(side * (HALF_WIDTH - 2), 7, middleZ),
			COLORS.StoneDark,
			Enum.Material.Limestone
		)
		MapKit.Blocker(map, Vector3.new(4, 140, depth), CFrame.new(side * (HALF_WIDTH - 2), 84, middleZ))
	end
	MapKit.Part(
		map,
		"NorthWall",
		Vector3.new(HALF_WIDTH * 2, 14, 4),
		CFrame.new(0, 7, NORTH_EDGE - 2),
		COLORS.StoneDark,
		Enum.Material.Limestone
	)
	MapKit.Blocker(map, Vector3.new(HALF_WIDTH * 2, 140, 4), CFrame.new(0, 84, NORTH_EDGE - 2))
end

-- Raised terraces at both ends with sloped streets running down to the plaza.
local function spawnTerraces(map: Instance, spawns: Instance)
	for _, side in { -1, 1 } do
		MapKit.Part(
			map,
			"SpawnTerrace",
			Vector3.new(46, 8, 92),
			CFrame.new(side * 218, 4, 0),
			COLORS.StoneDark,
			Enum.Material.Limestone
		)
		local rampStart = Vector3.new(side * 130, 0, 0)
		MapKit.Ramp(
			map,
			"SlopedStreet",
			rampStart,
			Vector3.new(side, 0, 0),
			66,
			7,
			70,
			COLORS.Paving,
			Enum.Material.Pavement
		)
		for _, z in { -36, 36 } do
			-- Low planter walls along the street edges.
			MapKit.Planter(map, Vector3.new(side * 150, 0, z), Vector3.new(24, 3, 3), COLORS.Stone)
			MapKit.Lamp(map, Vector3.new(side * 175, 0, z))
		end
		for _, z in { -30, -10, 10, 30 } do
			MapKit.Spawn(spawns, Vector3.new(side * 225, 8, z), CENTER)
		end
	end
end

local function clockTower(map: Instance)
	MapKit.Part(map, "Tower", Vector3.new(18, 46, 18), CFrame.new(0, 23, 0), COLORS.Stone, Enum.Material.Plaster)
	for i = 0, 3 do
		local angle = i * math.pi / 2
		local outward = Vector3.new(math.sin(angle), 0, math.cos(angle))
		local face = MapKit.Part(
			map,
			"ClockFace",
			Vector3.new(0.4, 9, 9),
			CFrame.lookAt(outward * 9.2 + Vector3.new(0, 38, 0), outward * 20 + Vector3.new(0, 38, 0))
				* CFrame.Angles(0, math.pi / 2, 0),
			COLORS.Clock,
			Enum.Material.Neon
		)
		face.Shape = Enum.PartType.Cylinder
		MapKit.Ghost(face)
	end
	MapKit.Part(
		map,
		"TowerRoof",
		Vector3.new(21, 1, 21),
		CFrame.new(0, 46.5, 0),
		COLORS.Terracotta,
		Enum.Material.ClayRoofTiles
	)
	MapKit.Part(
		map,
		"TowerCap",
		Vector3.new(12, 6, 12),
		CFrame.new(0, 50, 0),
		COLORS.Terracotta,
		Enum.Material.ClayRoofTiles
	)
	MapKit.Ghost(
		MapKit.Part(map, "Spire", Vector3.new(2.5, 12, 2.5), CFrame.new(0, 59, 0), COLORS.Accent, Enum.Material.Metal)
	)

	-- The balcony: a strong position that's exposed from every side.
	MapKit.Part(
		map,
		"Balcony",
		Vector3.new(32, 1, 32),
		CFrame.new(0, 17.5, 0),
		COLORS.StoneDark,
		Enum.Material.Limestone
	)
	for i = 0, 3 do
		local angle = i * math.pi / 2
		local rotation = CFrame.Angles(0, angle, 0)
		-- Two rail pieces per side with a gap in the middle to drop through.
		for _, offset in { -9, 9 } do
			MapKit.Part(
				map,
				"BalconyRail",
				Vector3.new(10, 2.5, 0.8),
				CFrame.new(0, 19.25, 0) * rotation * CFrame.new(offset, 0, 15.6),
				COLORS.Trim,
				Enum.Material.Limestone
			)
		end
		-- Ladders up the outside of the balcony.
		local truss = Instance.new("TrussPart")
		truss.Name = "Ladder"
		truss.Anchored = true
		truss.Size = Vector3.new(2, 18, 2)
		truss.Color = COLORS.Rock
		truss.Material = Enum.Material.Metal
		truss.CFrame = CFrame.new(0, 9, 0) * rotation * CFrame.new(0, 0, 17)
		truss.Parent = map
	end
end

local function plaza(map: Instance)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			MapKit.Planter(map, Vector3.new(x * 40, 0, z * 25), Vector3.new(10, 3, 6), COLORS.Stone)
			MapKit.Part(
				map,
				"LowWall",
				Vector3.new(16, 4, 2),
				CFrame.new(x * 75, 2, z * 16),
				COLORS.Stone,
				Enum.Material.Limestone
			)
			MapKit.Part(
				map,
				"LowWall",
				Vector3.new(2, 4, 14),
				CFrame.new(x * 25, 2, z * 46),
				COLORS.Stone,
				Enum.Material.Limestone
			)
			MapKit.Palm(map, Vector3.new(x * 115, 0, z * 52))
			MapKit.Palm(map, Vector3.new(x * 50, 0, z * 56), 12)

			-- Market stalls: a counter for cover and an awning you can stand on.
			local stall = Vector3.new(x * 60, 0, z * 38)
			MapKit.Part(
				map,
				"Counter",
				Vector3.new(10, 3, 2),
				CFrame.new(stall + Vector3.new(0, 1.5, z * -3)),
				COLORS.StoneDark,
				Enum.Material.Wood
			)
			for _, corner in
				{ Vector3.new(-5, 0, -3.5), Vector3.new(5, 0, -3.5), Vector3.new(-5, 0, 3.5), Vector3.new(5, 0, 3.5) }
			do
				MapKit.Part(
					map,
					"StallPost",
					Vector3.new(0.5, 8, 0.5),
					CFrame.new(stall + corner + Vector3.new(0, 4, 0)),
					COLORS.Rock,
					Enum.Material.Wood
				)
			end
			MapKit.Part(
				map,
				"Awning",
				Vector3.new(12, 0.5, 9),
				CFrame.new(stall + Vector3.new(0, 8.25, 0)),
				if x * z > 0 then COLORS.Teal else COLORS.Coral,
				Enum.Material.Fabric
			)
		end
	end

	-- Slingshots: two up onto the north rooftops, two onto the south houses.
	for _, x in { -95, 95 } do
		MapKit.Slingshot(map, Vector3.new(x, 0, 76), Vector3.zAxis, COLORS.StoneDark, COLORS.Accent)
	end
	for _, x in { -70, 70 } do
		MapKit.Slingshot(map, Vector3.new(x, 0, -48), -Vector3.zAxis, COLORS.StoneDark, COLORS.Accent)
	end
end

-- Houses in a row along X between z0 and z1.
local function houseRow(map: Instance, name: string, z0: number, z1: number, segments: { Segment }, parapet: number)
	local depth = z1 - z0
	for i, segment in segments do
		local width = segment.X1 - segment.X0
		MapKit.Building(
			map,
			`{name}{i}`,
			Vector3.new((segment.X0 + segment.X1) / 2, 0, (z0 + z1) / 2),
			Vector3.new(width, segment.Height, depth),
			HOUSE,
			parapet
		)
	end
end

local function mirrored(right: { Segment }): { Segment }
	local all = table.clone(right)
	for _, segment in right do
		table.insert(all, { X0 = -segment.X1, X1 = -segment.X0, Height = segment.Height })
	end
	return all
end

local function northLane(map: Instance, spawns: Instance)
	-- Rooftops 15 studs apart: only crossable with momentum (about 30 studs/s).
	houseRow(
		map,
		"Rooftop",
		100,
		160,
		mirrored({
			{ X0 = 15, X1 = 60, Height = 19 },
			{ X0 = 75, X1 = 125, Height = 20 },
			{ X0 = 140, X1 = 190, Height = 18 },
		}),
		1.2
	)
	-- A narrow beam across the wide middle gap.
	MapKit.Part(map, "Bridge", Vector3.new(32, 1, 4), CFrame.new(0, 18.5, 130), COLORS.Rock, Enum.Material.WoodPlanks)

	-- Stairs up at both ends, onto a walkway beside the end roofs.
	for _, side in { -1, 1 } do
		local top = MapKit.Stairs(
			map,
			"RoofStairs",
			Vector3.new(side * 200, 0, 70),
			Vector3.zAxis,
			12,
			1.5,
			2.4,
			14,
			COLORS.StoneDark,
			Enum.Material.Limestone
		)
		MapKit.Part(
			map,
			"RoofWalk",
			Vector3.new(18, 1, 160 - top.Z),
			CFrame.new(side * 199, top.Y - 0.5, (top.Z + 160) / 2),
			COLORS.StoneDark,
			Enum.Material.Limestone
		)
		MapKit.Spawn(spawns, Vector3.new(side * 100, 0, 175), CENTER)
	end

	for x = -200, 200, 50 do
		MapKit.Lamp(map, Vector3.new(x, 0, 62))
	end
end

local function southLane(map: Instance, spawns: Instance)
	-- Gaps of 9 between houses are wall-kick alleys; gaps of 20 are streets.
	houseRow(
		map,
		"HouseA",
		-110,
		-80,
		mirrored({
			{ X0 = 5, X1 = 43, Height = 18 },
			{ X0 = 52, X1 = 90, Height = 16 },
			{ X0 = 110, X1 = 151, Height = 14 },
			{ X0 = 160, X1 = 200, Height = 16 },
		}),
		0
	)
	houseRow(
		map,
		"HouseB",
		-160,
		-125,
		mirrored({
			{ X0 = 9, X1 = 50, Height = 14 },
			{ X0 = 70, X1 = 131, Height = 17 },
			{ X0 = 140, X1 = 200, Height = 15 },
		}),
		0
	)

	for _, side in { -1, 1 } do
		-- Stairs in the street between houses, up onto the 16-high roofs.
		MapKit.Stairs(
			map,
			"HouseStairs",
			Vector3.new(side * 100, 0, -82),
			-Vector3.zAxis,
			10,
			1.6,
			2.6,
			10,
			COLORS.StoneDark,
			Enum.Material.Limestone
		)
		-- Arches over the main alley.
		for _, x in { 30, 120 } do
			MapKit.Part(
				map,
				"Arch",
				Vector3.new(6, 2, 15),
				CFrame.new(side * x, 11, -117.5),
				COLORS.Trim,
				Enum.Material.Limestone
			)
		end
		for _, x in { 30, 150 } do
			MapKit.Spawn(spawns, Vector3.new(side * x, 0, -176), CENTER)
		end
		MapKit.Spawn(spawns, Vector3.new(side * 100, 0, -117), CENTER)
	end

	-- Bright awnings over doors along the alley (decoration only).
	for x = -190, 190, 38 do
		MapKit.Ghost(
			MapKit.Part(
				map,
				"DoorAwning",
				Vector3.new(6, 0.3, 2.5),
				CFrame.new(x, 8, -111.5) * CFrame.Angles(math.rad(-15), 0, 0),
				if (x // 38) % 2 == 0 then COLORS.Teal else COLORS.Coral,
				Enum.Material.Fabric
			)
		)
	end
	for x = -225, 225, 45 do
		MapKit.Lamp(map, Vector3.new(x, 0, -186))
	end
end

function CinderTerraces.Build(map: Folder)
	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = map

	ground(map)
	boundaries(map)
	spawnTerraces(map, spawns)
	clockTower(map)
	plaza(map)
	northLane(map, spawns)
	southLane(map, spawns)
end

return CinderTerraces
