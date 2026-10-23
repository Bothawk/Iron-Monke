--!strict
-- First-person weapons (sniper or knife) and arms, built from parts so they need no
-- uploaded model. Colors come from a palette, so skins (phase 8) only swap the palette.

export type Palette = {
	Primary: Color3,
	Secondary: Color3,
	Accent: Color3,
	Material: Enum.Material,
}

type Role = "Primary" | "Secondary" | "Accent" | "Skin" | "Sleeve"

type PartSpec = {
	Name: string,
	Size: Vector3,
	Offset: CFrame,
	Role: Role,
	Material: Enum.Material?, -- overrides the palette material
	Shape: Enum.PartType?,
	MovesWithBolt: boolean?,
}

export type Kind = "Sniper" | "Knife"

export type Pose = {
	AdsAlpha: number, -- 0 = hip, 1 = scoped
	Lower: number, -- 0 = held, 1 = dropped out of view (while switching weapons)
	Extra: CFrame?, -- extra motion on top, like a knife swing
	KickBack: number, -- studs pushed back by recoil
	KickPitch: number, -- radians tipped up by recoil
	Dip: number, -- radians tipped down (bolting, reloading)
	BoltPull: number, -- 0..1 how far the bolt handle is pulled back
	Sway: Vector2, -- radians (yaw, pitch) lag behind camera turns
	Bob: Vector2, -- studs (x, y) from walking
}

local DEFAULT_PALETTE: Palette = {
	Primary = Color3.fromRGB(58, 60, 66),
	Secondary = Color3.fromRGB(28, 29, 33),
	Accent = Color3.fromRGB(255, 140, 40),
	Material = Enum.Material.SmoothPlastic,
}
local SLEEVE_COLOR = Color3.fromRGB(34, 36, 42)
local DEFAULT_SKIN = Color3.fromRGB(234, 184, 146)

local SCOPE_HEIGHT = 0.3 -- scope center above the body's center line

-- A box stretched between two points, for arms.
local function limb(from: Vector3, to: Vector3): (Vector3, CFrame)
	local length = (to - from).Magnitude
	return Vector3.new(0.3, 0.3, length), CFrame.lookAt((from + to) / 2, to)
end

local RIGHT_HAND = Vector3.new(0.02, -0.38, 0.62)
local RIGHT_ELBOW = Vector3.new(0.55, -1.0, 2.1)
local LEFT_HAND = Vector3.new(0, -0.25, -1.05)
local LEFT_ELBOW = Vector3.new(-0.7, -0.95, -0.15)
local rightArmSize, rightArmOffset = limb(RIGHT_ELBOW, RIGHT_HAND)
local leftArmSize, leftArmOffset = limb(LEFT_ELBOW, LEFT_HAND)

local SNIPER_PARTS: { PartSpec } = {
	-- Receiver and chassis
	{ Name = "Body", Size = Vector3.new(0.26, 0.3, 1.9), Offset = CFrame.new(0, 0, 0), Role = "Primary" },
	{ Name = "Chassis", Size = Vector3.new(0.22, 0.12, 1.4), Offset = CFrame.new(0, -0.2, -0.2), Role = "Secondary" },
	{ Name = "Rail", Size = Vector3.new(0.12, 0.04, 1.1), Offset = CFrame.new(0, 0.17, -0.15), Role = "Secondary" },

	-- Barrel
	{
		Name = "Barrel",
		Size = Vector3.new(0.1, 0.1, 1.8),
		Offset = CFrame.new(0, 0.06, -1.9),
		Role = "Secondary",
		Material = Enum.Material.Metal,
	},
	{
		Name = "MuzzleBrake",
		Size = Vector3.new(0.18, 0.16, 0.3),
		Offset = CFrame.new(0, 0.06, -2.85),
		Role = "Secondary",
	},
	{
		Name = "MuzzlePorts",
		Size = Vector3.new(0.19, 0.04, 0.08),
		Offset = CFrame.new(0, 0.06, -2.8),
		Role = "Accent",
		Material = Enum.Material.Neon,
	},

	-- Scope
	{
		Name = "ScopeTube",
		Size = Vector3.new(0.18, 0.18, 1),
		Offset = CFrame.new(0, SCOPE_HEIGHT, -0.15),
		Role = "Secondary",
	},
	{
		Name = "ScopeFront",
		Size = Vector3.new(0.26, 0.26, 0.22),
		Offset = CFrame.new(0, SCOPE_HEIGHT, -0.68),
		Role = "Secondary",
	},
	{
		Name = "ScopeRear",
		Size = Vector3.new(0.22, 0.22, 0.16),
		Offset = CFrame.new(0, SCOPE_HEIGHT, 0.4),
		Role = "Secondary",
	},
	{
		Name = "ScopeLens",
		Size = Vector3.new(0.2, 0.2, 0.02),
		Offset = CFrame.new(0, SCOPE_HEIGHT, -0.8),
		Role = "Accent",
		Material = Enum.Material.Glass,
	},
	{
		Name = "ScopeTurret",
		Size = Vector3.new(0.08, 0.1, 0.1),
		Offset = CFrame.new(0, SCOPE_HEIGHT + 0.13, -0.15),
		Role = "Primary",
	},

	-- Stock and grip
	{ Name = "Stock", Size = Vector3.new(0.2, 0.36, 0.9), Offset = CFrame.new(0, -0.08, 1.35), Role = "Primary" },
	{
		Name = "StockStripe",
		Size = Vector3.new(0.205, 0.05, 0.6),
		Offset = CFrame.new(0, 0.02, 1.35),
		Role = "Accent",
		Material = Enum.Material.Neon,
	},
	{ Name = "CheekRest", Size = Vector3.new(0.16, 0.1, 0.5), Offset = CFrame.new(0, 0.15, 1.2), Role = "Secondary" },
	{ Name = "ButtPad", Size = Vector3.new(0.22, 0.42, 0.08), Offset = CFrame.new(0, -0.08, 1.82), Role = "Secondary" },
	{
		Name = "Grip",
		Size = Vector3.new(0.15, 0.38, 0.2),
		Offset = CFrame.new(0, -0.3, 0.55) * CFrame.Angles(math.rad(-15), 0, 0),
		Role = "Secondary",
	},
	{
		Name = "TriggerGuard",
		Size = Vector3.new(0.06, 0.08, 0.3),
		Offset = CFrame.new(0, -0.22, 0.3),
		Role = "Secondary",
	},
	{ Name = "Mag", Size = Vector3.new(0.17, 0.34, 0.32), Offset = CFrame.new(0, -0.32, -0.3), Role = "Secondary" },

	-- Bolt
	{
		Name = "BoltHandle",
		Size = Vector3.new(0.24, 0.05, 0.05),
		Offset = CFrame.new(0.16, 0.1, 0.35),
		Role = "Accent",
		MovesWithBolt = true,
	},
	{
		Name = "BoltKnob",
		Size = Vector3.new(0.1, 0.1, 0.1),
		Offset = CFrame.new(0.29, 0.1, 0.35),
		Role = "Accent",
		Shape = Enum.PartType.Ball,
		MovesWithBolt = true,
	},

	-- Arms
	{ Name = "RightArm", Size = rightArmSize, Offset = rightArmOffset, Role = "Sleeve" },
	{ Name = "RightHand", Size = Vector3.new(0.3, 0.32, 0.34), Offset = CFrame.new(RIGHT_HAND), Role = "Skin" },
	{ Name = "LeftArm", Size = leftArmSize, Offset = leftArmOffset, Role = "Sleeve" },
	{ Name = "LeftHand", Size = Vector3.new(0.32, 0.26, 0.34), Offset = CFrame.new(LEFT_HAND), Role = "Skin" },
}

-- Knife held in the right hand, blade forward and slightly up.
local KNIFE_HAND = Vector3.new(0, -0.05, 0.35)
local KNIFE_ELBOW = Vector3.new(0.35, -0.7, 1.9)
local knifeArmSize, knifeArmOffset = limb(KNIFE_ELBOW, KNIFE_HAND)

local KNIFE_PARTS: { PartSpec } = {
	{
		Name = "Blade",
		Size = Vector3.new(0.04, 0.2, 0.9),
		Offset = CFrame.new(0, 0.02, -0.55),
		Role = "Accent",
		Material = Enum.Material.Metal,
	},
	{
		Name = "Edge",
		Size = Vector3.new(0.045, 0.04, 0.85),
		Offset = CFrame.new(0, -0.07, -0.55),
		Role = "Accent",
		Material = Enum.Material.Neon,
	},
	{ Name = "Guard", Size = Vector3.new(0.1, 0.32, 0.06), Offset = CFrame.new(0, 0, -0.08), Role = "Secondary" },
	{ Name = "Handle", Size = Vector3.new(0.12, 0.16, 0.45), Offset = CFrame.new(0, 0, 0.18), Role = "Primary" },
	{ Name = "Pommel", Size = Vector3.new(0.14, 0.18, 0.06), Offset = CFrame.new(0, 0, 0.43), Role = "Secondary" },
	{ Name = "RightArm", Size = knifeArmSize, Offset = knifeArmOffset, Role = "Sleeve" },
	{ Name = "RightHand", Size = Vector3.new(0.3, 0.32, 0.34), Offset = CFrame.new(KNIFE_HAND), Role = "Skin" },
}

type KindSpec = { Parts: { PartSpec }, Hip: CFrame, Ads: CFrame, Muzzle: CFrame }

local KINDS: { [Kind]: KindSpec } = {
	Sniper = {
		Parts = SNIPER_PARTS,
		Hip = CFrame.new(0.75, -0.75, -1.7),
		Ads = CFrame.new(0, -SCOPE_HEIGHT, -1.1),
		Muzzle = CFrame.new(0, 0.06, -3.05),
	},
	Knife = {
		Parts = KNIFE_PARTS,
		Hip = CFrame.new(0.85, -0.8, -1.5) * CFrame.Angles(math.rad(10), math.rad(8), math.rad(-20)),
		Ads = CFrame.new(0.85, -0.8, -1.5),
		Muzzle = CFrame.new(0, 0, -1),
	},
}

local BOLT_TRAVEL = 0.3
local LOWER_OFFSET = CFrame.new(0, -1.6, 0.4) * CFrame.Angles(math.rad(-40), 0, 0)

local Viewmodel = {}
Viewmodel.__index = Viewmodel

export type Viewmodel = typeof(setmetatable(
	{} :: {
		Model: Model,
		Spec: KindSpec,
		Parts: { BasePart },
		Handle: CFrame,
		Visible: boolean,
		Palette: Palette,
		SkinColor: Color3,
	},
	Viewmodel
))

function Viewmodel.new(kind: Kind): Viewmodel
	local kindSpec = KINDS[kind]
	local model = Instance.new("Model")
	model.Name = `{kind}Viewmodel`
	local parts = {}
	for _, spec in kindSpec.Parts do
		local part = Instance.new("Part")
		part.Name = spec.Name
		part.Size = spec.Size
		part.Shape = spec.Shape or Enum.PartType.Block
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Parent = model
		table.insert(parts, part)
	end
	local self = setmetatable({
		Model = model,
		Spec = kindSpec,
		Parts = parts,
		Handle = CFrame.identity,
		Visible = true,
		Palette = DEFAULT_PALETTE,
		SkinColor = DEFAULT_SKIN,
	}, Viewmodel)
	self:ApplyColors()
	return self
end

function Viewmodel.ApplyColors(self: Viewmodel)
	local palette = self.Palette
	for i, spec in self.Spec.Parts do
		local part = self.Parts[i]
		local role = spec.Role
		part.Color = if role == "Primary"
			then palette.Primary
			elseif role == "Secondary" then palette.Secondary
			elseif role == "Accent" then palette.Accent
			elseif role == "Skin" then self.SkinColor
			else SLEEVE_COLOR
		part.Material = spec.Material
			or if role == "Skin" or role == "Sleeve" then Enum.Material.SmoothPlastic else palette.Material
	end
end

function Viewmodel.SetPalette(self: Viewmodel, palette: Palette)
	self.Palette = palette
	self:ApplyColors()
end

-- Hands match the player's own skin color.
function Viewmodel.SetSkinColor(self: Viewmodel, character: Model)
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if hand and hand:IsA("BasePart") then
		self.SkinColor = hand.Color
		self:ApplyColors()
	end
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

	local spec = self.Spec
	local offset = spec.Hip:Lerp(spec.Ads, easeOut(pose.AdsAlpha))
		* CFrame.identity:Lerp(LOWER_OFFSET, pose.Lower)
		* CFrame.new(pose.Bob.X, pose.Bob.Y, pose.KickBack)
		* CFrame.Angles(pose.KickPitch - pose.Dip + pose.Sway.Y, pose.Sway.X, 0)
		* (pose.Extra or CFrame.identity)
	self.Handle = camera.CFrame * offset

	local boltOffset = CFrame.new(0, 0, pose.BoltPull * BOLT_TRAVEL)
	local parts = spec.Parts
	local cframes = table.create(#parts)
	for i, partSpec in parts do
		cframes[i] = if partSpec.MovesWithBolt
			then self.Handle * boltOffset * partSpec.Offset
			else self.Handle * partSpec.Offset
	end
	workspace:BulkMoveTo(self.Parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

function Viewmodel.GetMuzzlePosition(self: Viewmodel): Vector3
	return (self.Handle * self.Spec.Muzzle).Position
end

return Viewmodel
