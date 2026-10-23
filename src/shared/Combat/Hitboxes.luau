--!strict
-- Which character parts count as hitboxes, and which damage zone each one is.

export type Zone = "Head" | "Body" | "Limb"

local ZONES: { [string]: Zone } = {
	Head = "Head",

	-- R15
	UpperTorso = "Body",
	LowerTorso = "Body",
	LeftUpperArm = "Limb",
	LeftLowerArm = "Limb",
	LeftHand = "Limb",
	RightUpperArm = "Limb",
	RightLowerArm = "Limb",
	RightHand = "Limb",
	LeftUpperLeg = "Limb",
	LeftLowerLeg = "Limb",
	LeftFoot = "Limb",
	RightUpperLeg = "Limb",
	RightLowerLeg = "Limb",
	RightFoot = "Limb",

	-- R6
	Torso = "Body",
	["Left Arm"] = "Limb",
	["Right Arm"] = "Limb",
	["Left Leg"] = "Limb",
	["Right Leg"] = "Limb",
}

local Hitboxes = {}

function Hitboxes.GetZone(partName: string): Zone?
	return ZONES[partName]
end

-- The hitbox parts of a character, skipping accessories and the root part.
function Hitboxes.GetParts(character: Model): { BasePart }
	local parts = {}
	for _, child in character:GetChildren() do
		if child:IsA("BasePart") and ZONES[child.Name] then
			table.insert(parts, child)
		end
	end
	return parts
end

return Hitboxes
