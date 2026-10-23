--!strict
-- Casts a shot through the world. It skips accessories (hats) and, for weapons
-- that can, passes through a limited number of thin walls. The client uses it to
-- find what a shot hits; the server uses it to check nothing blocks a claimed hit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)

export type Result = {
	Hit: RaycastResult?, -- the first character part or wall that stopped the shot
	WallsPassed: number,
}

local MAX_STEPS = 8

local Ballistics = {}

-- How thick `part` is along the shot, or nil if thicker than the limit.
local function thickness(part: BasePart, entry: Vector3, direction: Vector3): number?
	local limit = WeaponConfig.MaxPenetrationThickness
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { part }
	-- Cast back from past the far side to find where the shot would come out.
	local far = entry + direction * limit
	local back = workspace:Raycast(far, -direction * limit, params)
	if not back then
		return nil
	end
	return limit - back.Distance
end

local function isCharacterPart(part: BasePart): boolean
	local parent = part.Parent
	return parent ~= nil and parent:FindFirstChildOfClass("Humanoid") ~= nil
end

-- `ignore` must include the shooter's own character.
function Ballistics.Cast(
	origin: Vector3,
	direction: Vector3,
	range: number,
	ignore: { Instance },
	penetration: number
): Result
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = table.clone(ignore)
	local start = origin
	local travelled = 0
	local wallsPassed = 0

	for _ = 1, MAX_STEPS do
		params.FilterDescendantsInstances = excluded
		local hit = workspace:Raycast(start, direction * (range - travelled), params)
		if not hit then
			return { Hit = nil, WallsPassed = wallsPassed }
		end
		local part = hit.Instance
		local accessory = part:FindFirstAncestorOfClass("Accessory")
		if accessory then
			table.insert(excluded, accessory)
		elseif isCharacterPart(part) then
			return { Hit = hit, WallsPassed = wallsPassed }
		elseif wallsPassed < penetration and thickness(part, hit.Position, direction) then
			wallsPassed += 1
			table.insert(excluded, part)
		else
			return { Hit = hit, WallsPassed = wallsPassed }
		end
		travelled = (hit.Position - origin).Magnitude
		start = hit.Position
	end
	return { Hit = nil, WallsPassed = wallsPassed }
end

-- Counts solid walls between `origin` and `distance` along `direction`, ignoring
-- characters (pass every tracked character in `ignore`). Returns how many thin
-- walls were passed, or nil if something too thick or too many walls are in the way.
function Ballistics.WallsBetween(
	origin: Vector3,
	direction: Vector3,
	distance: number,
	ignore: { Instance },
	penetration: number
): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = table.clone(ignore)
	local walls = 0
	for _ = 1, MAX_STEPS do
		params.FilterDescendantsInstances = excluded
		local hit = workspace:Raycast(origin, direction * distance, params)
		-- A small margin so a hitbox hugging a wall still counts as reachable.
		if not hit or hit.Distance >= distance - 0.5 then
			return walls
		end
		if walls >= penetration or not thickness(hit.Instance, hit.Position, direction) then
			return nil
		end
		walls += 1
		table.insert(excluded, hit.Instance)
	end
	return nil
end

return Ballistics
