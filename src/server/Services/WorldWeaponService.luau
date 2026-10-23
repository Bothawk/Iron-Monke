--!strict
-- Gives every character a sniper and a knife other players can see, welded to the
-- right hand, showing whichever is equipped. Clients pose the arms to match
-- (CharacterPoseController), and the owner hides their own copy since they see the
-- first-person one instead.

local Players = game:GetService("Players")

local WorldWeaponService = {}

type Palette = { Primary: Color3, Secondary: Color3, Accent: Color3 }

-- Colors asked for before the gun was built (the loadout can arrive first).
local pendingPalettes: { [Model]: Palette } = {}

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

local KNIFE_PARTS: { PartSpec } = {
	{ Name = "Blade", Size = Vector3.new(0.04, 0.2, 0.9), Offset = Vector3.new(0, 0.02, -0.55), Color = ACCENT },
	{ Name = "Guard", Size = Vector3.new(0.1, 0.32, 0.06), Offset = Vector3.new(0, 0, -0.08), Color = SECONDARY },
}

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
	-- Remembered so SetPalette knows which color each part takes.
	part:SetAttribute("Role", if color == PRIMARY then "Primary" elseif color == ACCENT then "Accent" else "Secondary")
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

	-- The arm points the hand's -Y forward when aiming, so turn the weapon's
	-- forward (-Z) to match, with the grip sitting in the palm.
	local handGrip = CFrame.new(0, -hand.Size.Y * 0.3, 0) * CFrame.Angles(math.rad(-90), 0, 0)

	local sniper = Instance.new("Model")
	sniper.Name = "Sniper"
	local body = makePart("Body", Vector3.new(0.26, 0.3, 1.9), PRIMARY)
	body.Parent = sniper
	for _, spec in PARTS do
		local part = makePart(spec.Name, spec.Size, spec.Color)
		weld(body, part, CFrame.new(spec.Offset * SCALE), CFrame.identity)
		part.Parent = sniper
	end
	weld(hand, body, handGrip, CFrame.new(GRIP_OFFSET * SCALE))
	sniper.Parent = model

	local knife = Instance.new("Model")
	knife.Name = "Knife"
	local handle = makePart("Handle", Vector3.new(0.12, 0.16, 0.45), SECONDARY)
	handle.Parent = knife
	for _, spec in KNIFE_PARTS do
		local part = makePart(spec.Name, spec.Size, spec.Color)
		weld(handle, part, CFrame.new(spec.Offset * SCALE), CFrame.identity)
		part.Parent = knife
	end
	weld(hand, handle, handGrip, CFrame.identity)
	knife.Parent = model

	model.Parent = character
	WorldWeaponService.SetEquipped(character, "Sniper")
	local palette = pendingPalettes[character]
	if palette then
		pendingPalettes[character] = nil
		WorldWeaponService.SetPalette(character, palette)
	end
end

-- Recolors the third-person sniper to match the equipped weapon (or skin).
function WorldWeaponService.SetPalette(character: Model, palette: Palette)
	local model = character:FindFirstChild("WorldWeapon")
	local sniper = model and model:FindFirstChild("Sniper")
	if not sniper then
		pendingPalettes[character] = palette
		-- Forget it if the character goes away before the gun is built.
		character.AncestryChanged:Once(function()
			pendingPalettes[character] = nil
		end)
		return
	end
	for _, part in sniper:GetChildren() do
		if part:IsA("BasePart") then
			local role = part:GetAttribute("Role")
			part.Color = if role == "Accent"
				then palette.Accent
				elseif role == "Primary" then palette.Primary
				else palette.Secondary
		end
	end
end

-- Shows the equipped weapon and tells clients which arm pose to use.
function WorldWeaponService.SetEquipped(character: Model, slot: string)
	character:SetAttribute("Equipped", slot)
	local model = character:FindFirstChild("WorldWeapon")
	if not model then
		return
	end
	for _, weapon in model:GetChildren() do
		local shown = weapon.Name == slot
		for _, part in weapon:GetDescendants() do
			if part:IsA("BasePart") then
				part.Transparency = if shown then 0 else 1
			end
		end
	end
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
