--!strict
-- Shot impacts: a burst of sparks or dust that matches the surface, a bullet hole
-- that fades after a few seconds, and a red puff when a character is hit. Also
-- draws other players' tracers (unless their gun is suppressed). Everything comes
-- from small reusable pools; Low graphics skips bullet holes and thins the bursts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local SettingsController = require(script.Parent.SettingsController)
local Tracers = require(script.Parent.Parent.Weapon.Tracers)
local WeaponController = require(script.Parent.WeaponController)

local IMPACT_POOL = 8
local HOLE_POOL = 30
local HOLE_LIFETIME = 6
local HOLE_FADE = TweenInfo.new(1, Enum.EasingStyle.Linear)

local METAL = Color3.fromRGB(255, 210, 120)
local DUST = Color3.fromRGB(200, 195, 185)
local BLOOD = Color3.fromRGB(200, 30, 40)

local SPARK_MATERIALS: { [Enum.Material]: boolean } = {
	[Enum.Material.Metal] = true,
	[Enum.Material.DiamondPlate] = true,
	[Enum.Material.CorrodedMetal] = true,
	[Enum.Material.Foil] = true,
	[Enum.Material.Neon] = true,
}

local EffectsController = {}

type Impact = { Attachment: Attachment, Emitter: ParticleEmitter }

local folder = Instance.new("Folder")
folder.Name = "ImpactEffects"
local impacts: { Impact } = {}
local holes: { { Part: Part, Tween: Tween? } } = {}
local nextImpact = 1
local nextHole = 1

local function buildPools()
	for _ = 1, IMPACT_POOL do
		local attachment = Instance.new("Attachment")
		local emitter = Instance.new("ParticleEmitter")
		emitter.Enabled = false
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.SpreadAngle = Vector2.new(55, 55)
		emitter.Lifetime = NumberRange.new(0.12, 0.3)
		emitter.Speed = NumberRange.new(10, 22)
		emitter.Drag = 6
		emitter.Acceleration = Vector3.new(0, -40, 0)
		emitter.LightEmission = 0.6
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.18),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Parent = attachment
		attachment.Parent = workspace.Terrain
		table.insert(impacts, { Attachment = attachment, Emitter = emitter })
	end

	for _ = 1, HOLE_POOL do
		local hole = Instance.new("Part")
		hole.Name = "BulletHole"
		hole.Anchored = true
		hole.CanCollide = false
		hole.CanQuery = false
		hole.CanTouch = false
		hole.CastShadow = false
		hole.Shape = Enum.PartType.Cylinder
		hole.Size = Vector3.new(0.02, 0.28, 0.28)
		hole.Color = Color3.fromRGB(20, 20, 22)
		hole.Material = Enum.Material.SmoothPlastic
		hole.Transparency = 1
		hole.Parent = folder
		table.insert(holes, { Part = hole, Tween = nil })
	end
	folder.Parent = workspace
end

local function burst(position: Vector3, normal: Vector3, color: Color3, count: number, lightEmission: number)
	local impact = impacts[nextImpact]
	nextImpact = nextImpact % #impacts + 1
	-- The emitter sprays along the attachment's up axis, so point it out of the surface.
	impact.Attachment.WorldCFrame = CFrame.lookAt(position, position + normal) * CFrame.Angles(-math.pi / 2, 0, 0)
	impact.Emitter.Color = ColorSequence.new(color)
	impact.Emitter.LightEmission = lightEmission
	local quality = SettingsController.Get("Graphics")
	impact.Emitter:Emit(if quality == "Low" then math.ceil(count / 3) else count)
end

local function placeHole(position: Vector3, normal: Vector3)
	local entry = holes[nextHole]
	nextHole = nextHole % #holes + 1
	if entry.Tween then
		entry.Tween:Cancel()
	end
	local hole = entry.Part
	-- A cylinder's flat faces are along its X axis, so face X out of the surface.
	hole.CFrame = CFrame.lookAt(position + normal * 0.01, position + normal) * CFrame.Angles(0, math.pi / 2, 0)
	hole.Transparency = 0.1
	local tween = TweenService:Create(hole, HOLE_FADE, { Transparency = 1 })
	entry.Tween = tween
	task.delay(HOLE_LIFETIME, function()
		if entry.Tween == tween then
			tween:Play()
		end
	end)
end

local function showImpact(endPoint: Vector3, normal: Vector3?, material: Enum.Material?, hitCharacter: boolean)
	if not normal then
		return
	end
	if hitCharacter then
		burst(endPoint, normal, BLOOD, 10, 0)
		return
	end
	local isMetal = material ~= nil and SPARK_MATERIALS[material] == true
	burst(endPoint, normal, if isMetal then METAL else DUST, if isMetal then 14 else 9, if isMetal then 0.8 else 0)
	if SettingsController.Get("Graphics") ~= "Low" then
		placeHole(endPoint, normal)
	end
end

function EffectsController.Start()
	buildPools()

	WeaponController.Fired:Connect(function(info: WeaponController.ShotInfo)
		showImpact(info.EndPoint, info.Normal, info.Material, info.HitCharacter)
	end)

	Net.Event(Net.Names.ShotEffect).OnClientEvent:Connect(function(effect: any)
		if typeof(effect) ~= "table" or typeof(effect.Origin) ~= "Vector3" or typeof(effect.EndPoint) ~= "Vector3" then
			return
		end
		if effect.Suppressed ~= true then
			Tracers.Show(effect.Origin, effect.EndPoint)
		end
		local normal = if typeof(effect.Normal) == "Vector3" then effect.Normal else nil
		local material = if typeof(effect.Material) == "EnumItem" then effect.Material else nil
		showImpact(effect.EndPoint, normal, material, effect.HitCharacter == true)
	end)
end

return EffectsController
