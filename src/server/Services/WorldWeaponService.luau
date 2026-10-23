--!strict
-- Gives every character a sniper other players can see, welded to the right hand.
-- Clients raise the arms into an aiming pose (CharacterPoseController), and the
-- owner hides their own copy since they see the first-person one instead.

local Players = game:GetService("Players")

local WorldWeaponService = {}

local SCALE = 1.5
local PRIMARY = Color3.fromRGB(58, 60, 66)
local SECONDARY = Color3.fromRGB(28, 29, 33)
local ACCENT = Color3.fromRGB(255, 140, 40)

type PartSpec = { Name: string, Size: Vector3, Offset: Vector3, Color: Color3 }

-- Offsets are from the gun's body center, before scaling. Forward is -Z.
local PARTS: { PartSpec } = {
	{ Name = "Barrel", Size = Vector3.new(0.1, 0.1, 1.8), Offset = Vector3.new(0, 0.06, -1.9), Color = SECONDARY },
	{ Name = "Muzzle", Size = Vector3.new(0.18, 0.16, 0.3), Offset = Vector3.new(0, 0.06, -2.85), Color = SECONDARY },
	{ Name = "Scope", Size = Vector3.new(0.2, 0.2, 1.1), Offset = Vector3.new(0, 0.3, -0.15), Color = SECONDARY },
	{ Name = "Stock", Size = Vector3.new(0.2, 0.36, 0.9), Offset = Vector3.new(0, -0.08, 1.35), Color = PRIMARY },
	{ Name = "Stripe", Size = Vector3.new(0.21, 0.05, 0.6), Offset = Vector3.new(0, 0.02, 1.35), Color = ACCENT },
	{ Name = "Mag", Size = Vector3.new(0.17, 0.34, 0.32), Offset = Vector3.new(0, -0.32, -0.3), Color = SECONDARY },
}
local GRIP_OFFSET = Vector3.new(0, -0.3, 0.55)

local function makePart(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size * SCALE
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = true
	return part
end

local function weld(part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame)
	local w = Instance.new("Weld")
	w.Part0 = part0
	w.Part1 = part1
	w.C0 = c0
	w.C1 = c1
	w.Parent = part1
end

local function attach(character: Model)
	local hand = character:WaitForChild("RightHand", 10) or character:FindFirstChild("Right Arm")
	if not hand or not hand:IsA("BasePart") then
		return
	end

	local model = Instance.new("Model")
	model.Name = "WorldWeapon"
	local body = makePart("Body", Vector3.new(0.26, 0.3, 1.9), PRIMARY)
	body.Parent = model
	for _, spec in PARTS do
		local part = makePart(spec.Name, spec.Size, spec.Color)
		weld(body, part, CFrame.new(spec.Offset * SCALE), CFrame.identity)
		part.Parent = model
	end

	-- The arm points the hand's -Y forward when aiming, so turn the barrel (-Z) to match,
	-- with the grip sitting in the palm.
	local handGrip = CFrame.new(0, -hand.Size.Y * 0.3, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	weld(hand, body, handGrip, CFrame.new(GRIP_OFFSET * SCALE))
	model.Parent = character
end

function WorldWeaponService.Start()
	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(attach, character)
		end)
		if player.Character then
			task.spawn(attach, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return WorldWeaponService
