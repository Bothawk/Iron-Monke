--!strict
-- The first-person sniper, built from parts as placeholder art until the real
-- model arrives in phase 3. It's moved with the camera every frame.

type PartSpec = {
	Name: string,
	Size: Vector3,
	Offset: CFrame,
	Color: Color3,
	Material: Enum.Material?,
}

export type Pose = {
	AdsAlpha: number, -- 0 = hip, 1 = scoped
	KickBack: number, -- studs pushed back by recoil
	KickPitch: number, -- radians tipped up by recoil
	Dip: number, -- radians tipped down (bolting, reloading)
	BoltPull: number, -- 0..1 how far the bolt handle is pulled back
	Sway: Vector2, -- radians (yaw, pitch) lag behind camera turns
	Bob: Vector2, -- studs (x, y) from walking
}

local GUNMETAL = Color3.fromRGB(58, 60, 66)
local DARK = Color3.fromRGB(28, 29, 33)
local ACCENT = Color3.fromRGB(255, 140, 40)

local SCOPE_HEIGHT = 0.3 -- scope center above the body's center line

local PARTS: { PartSpec } = {
	{ Name = "Body", Size = Vector3.new(0.28, 0.32, 2), Offset = CFrame.new(0, 0, 0), Color = GUNMETAL },
	{
		Name = "Barrel",
		Size = Vector3.new(0.11, 0.11, 1.7),
		Offset = CFrame.new(0, 0.06, -1.85),
		Color = DARK,
		Material = Enum.Material.Metal,
	},
	{ Name = "Muzzle", Size = Vector3.new(0.17, 0.17, 0.25), Offset = CFrame.new(0, 0.06, -2.75), Color = DARK },
	{ Name = "Scope", Size = Vector3.new(0.2, 0.2, 0.95), Offset = CFrame.new(0, SCOPE_HEIGHT, -0.15), Color = DARK },
	{
		Name = "ScopeFront",
		Size = Vector3.new(0.26, 0.26, 0.14),
		Offset = CFrame.new(0, SCOPE_HEIGHT, -0.62),
		Color = DARK,
	},
	{
		Name = "ScopeLens",
		Size = Vector3.new(0.18, 0.18, 0.02),
		Offset = CFrame.new(0, SCOPE_HEIGHT, -0.7),
		Color = ACCENT,
		Material = Enum.Material.Glass,
	},
	{ Name = "Stock", Size = Vector3.new(0.22, 0.38, 0.85), Offset = CFrame.new(0, -0.08, 1.35), Color = GUNMETAL },
	{
		Name = "Grip",
		Size = Vector3.new(0.16, 0.38, 0.2),
		Offset = CFrame.new(0, -0.3, 0.55) * CFrame.Angles(math.rad(-15), 0, 0),
		Color = DARK,
	},
	{ Name = "Mag", Size = Vector3.new(0.18, 0.34, 0.3), Offset = CFrame.new(0, -0.3, -0.3), Color = DARK },
	{ Name = "Bolt", Size = Vector3.new(0.26, 0.06, 0.06), Offset = CFrame.new(0.17, 0.1, 0.35), Color = ACCENT },
}

local MUZZLE_OFFSET = CFrame.new(0, 0.06, -2.9)
local BOLT_TRAVEL = 0.3
local HIP_OFFSET = CFrame.new(0.75, -0.75, -1.7)
local ADS_OFFSET = CFrame.new(0, -SCOPE_HEIGHT, -1.1)

local Viewmodel = {}
Viewmodel.__index = Viewmodel

export type Viewmodel = typeof(setmetatable(
	{} :: {
		Model: Model,
		Parts: { BasePart },
		Handle: CFrame,
		Visible: boolean,
	},
	Viewmodel
))

function Viewmodel.new(): Viewmodel
	local model = Instance.new("Model")
	model.Name = "Viewmodel"
	local parts = {}
	for _, spec in PARTS do
		local part = Instance.new("Part")
		part.Name = spec.Name
		part.Size = spec.Size
		part.Color = spec.Color
		part.Material = spec.Material or Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Parent = model
		table.insert(parts, part)
	end
	return setmetatable({ Model = model, Parts = parts, Handle = CFrame.identity, Visible = true }, Viewmodel)
end

local function easeOut(alpha: number): number
	return 1 - (1 - alpha) ^ 3
end

function Viewmodel.SetVisible(self: Viewmodel, visible: boolean)
	if self.Visible == visible then
		return
	end
	self.Visible = visible
	for _, part in self.Parts do
		part.LocalTransparencyModifier = if visible then 0 else 1
	end
end

function Viewmodel.Update(self: Viewmodel, camera: Camera, pose: Pose)
	if self.Model.Parent ~= camera then
		self.Model.Parent = camera
	end

	local offset = HIP_OFFSET:Lerp(ADS_OFFSET, easeOut(pose.AdsAlpha))
		* CFrame.new(pose.Bob.X, pose.Bob.Y, pose.KickBack)
		* CFrame.Angles(pose.KickPitch - pose.Dip + pose.Sway.Y, pose.Sway.X, 0)
	self.Handle = camera.CFrame * offset

	local cframes = table.create(#PARTS)
	for i, spec in PARTS do
		local partCFrame = self.Handle * spec.Offset
		if spec.Name == "Bolt" then
			partCFrame *= CFrame.new(0, 0, pose.BoltPull * BOLT_TRAVEL)
		end
		cframes[i] = partCFrame
	end
	workspace:BulkMoveTo(self.Parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

function Viewmodel.GetMuzzlePosition(self: Viewmodel): Vector3
	return (self.Handle * MUZZLE_OFFSET).Position
end

return Viewmodel
