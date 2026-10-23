--!strict
-- Records where every combatant's hitboxes were over the last second, so a shot
-- can be checked against where the shooter actually saw the target, not where
-- the target is by the time the shot reaches the server.
-- Hits are tested with math against the recorded boxes, so no parts are ever moved.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Hitboxes = require(ReplicatedStorage.Shared.Combat.Hitboxes)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)

local Settings = WeaponConfig.LagCompensation

type Box = { CFrame: CFrame, Size: Vector3 }
type Snapshot = { Time: number, Boxes: { [string]: Box } }

local LagCompensation = {}

local histories: { [Model]: { Snapshot } } = {}

local function capture(model: Model, now: number): Snapshot
	local boxes: { [string]: Box } = {}
	for _, part in Hitboxes.GetParts(model) do
		boxes[part.Name] = { CFrame = part.CFrame, Size = part.Size }
	end
	return { Time = now, Boxes = boxes }
end

-- Distance along the ray to where it enters the box, or nil if it misses.
local function rayBox(origin: Vector3, direction: Vector3, box: Box, padding: number): number?
	local localOrigin = box.CFrame:PointToObjectSpace(origin)
	local localDirection = box.CFrame:VectorToObjectSpace(direction)
	local half = box.Size / 2 + Vector3.one * padding

	local tMin, tMax = -math.huge, math.huge
	for _, axis in { "X", "Y", "Z" } do
		local o: number = (localOrigin :: any)[axis]
		local d: number = (localDirection :: any)[axis]
		local h: number = (half :: any)[axis]
		if math.abs(d) < 1e-8 then
			if math.abs(o) > h then
				return nil
			end
		else
			local t1 = (-h - o) / d
			local t2 = (h - o) / d
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			tMin = math.max(tMin, t1)
			tMax = math.min(tMax, t2)
			if tMin > tMax then
				return nil
			end
		end
	end
	if tMax < 0 then
		return nil
	end
	return math.max(tMin, 0)
end

-- The pose at time t, blended between the two recordings around it.
local function poseAt(history: { Snapshot }, t: number): { [string]: Box }?
	local count = #history
	if count == 0 then
		return nil
	end
	if t <= history[1].Time then
		return history[1].Boxes
	end
	if t >= history[count].Time then
		return history[count].Boxes
	end
	for i = count - 1, 1, -1 do
		local a = history[i]
		if a.Time <= t then
			local b = history[i + 1]
			local alpha = (t - a.Time) / (b.Time - a.Time)
			local boxes: { [string]: Box } = {}
			for name, boxA in a.Boxes do
				local boxB = b.Boxes[name]
				boxes[name] = if boxB then { CFrame = boxA.CFrame:Lerp(boxB.CFrame, alpha), Size = boxA.Size } else boxA
			end
			return boxes
		end
	end
	return nil
end

function LagCompensation.Track(model: Model)
	histories[model] = {}
end

function LagCompensation.Untrack(model: Model)
	histories[model] = nil
end

function LagCompensation.IsTracked(model: Model): boolean
	return histories[model] ~= nil
end

function LagCompensation.GetTrackedModels(): { Model }
	local models = {}
	for model in histories do
		table.insert(models, model)
	end
	return models
end

-- Checks a shot against `model` at every moment between fromTime and toTime.
-- If the claimed part is hit at any of those moments, that part wins; otherwise
-- the closest part hit at the first moment that hits anything is used.
-- Returns the part name and distance, or nil for a miss.
function LagCompensation.Raycast(
	model: Model,
	origin: Vector3,
	direction: Vector3,
	maxDistance: number,
	fromTime: number,
	toTime: number,
	claimedPart: string?
): (string?, number?)
	local history = histories[model]
	if not history then
		return nil, nil
	end

	-- Moments newer than the latest recording use the live pose instead.
	local latestTime = if #history > 0 then history[#history].Time else -math.huge
	local live = capture(model, toTime)
	local fallbackPart: string?, fallbackDistance: number? = nil, nil

	local t = fromTime
	while true do
		local boxes = if t > latestTime then live.Boxes else poseAt(history, t)
		if boxes then
			local closestPart: string?, closestDistance = nil, maxDistance
			for name, box in boxes do
				local distance = rayBox(origin, direction, box, Settings.HitboxPadding)
				if distance and distance <= maxDistance then
					if name == claimedPart then
						return name, distance
					end
					if distance < closestDistance then
						closestPart, closestDistance = name, distance
					end
				end
			end
			if closestPart and not fallbackPart then
				fallbackPart, fallbackDistance = closestPart, closestDistance
			end
		end
		if t >= toTime then
			break
		end
		t = math.min(t + Settings.SampleStep, toTime)
	end

	return fallbackPart, fallbackDistance
end

local function pointBoxDistance(point: Vector3, box: Box): number
	local localPoint = box.CFrame:PointToObjectSpace(point)
	local half = box.Size / 2
	local outside = Vector3.new(
		math.max(math.abs(localPoint.X) - half.X, 0),
		math.max(math.abs(localPoint.Y) - half.Y, 0),
		math.max(math.abs(localPoint.Z) - half.Z, 0)
	)
	return outside.Magnitude
end

-- The closest `model`'s hitboxes came to `point` at any moment between fromTime and
-- toTime, and where that closest box was. Used for knife reach.
function LagCompensation.ClosestDistance(
	model: Model,
	point: Vector3,
	fromTime: number,
	toTime: number
): (number, Vector3?)
	local history = histories[model]
	if not history then
		return math.huge, nil
	end
	local latestTime = if #history > 0 then history[#history].Time else -math.huge
	local live = capture(model, toTime)
	local best, bestCenter = math.huge, nil

	local t = fromTime
	while true do
		local boxes = if t > latestTime then live.Boxes else poseAt(history, t)
		if boxes then
			for _, box in boxes do
				local distance = pointBoxDistance(point, box)
				if distance < best then
					best, bestCenter = distance, box.CFrame.Position
				end
			end
		end
		if t >= toTime then
			break
		end
		t = math.min(t + Settings.SampleStep, toTime)
	end
	return best, bestCenter
end

function LagCompensation.Start()
	local interval = 1 / Settings.SnapshotRate
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < interval then
			return
		end
		elapsed = 0

		local now = workspace:GetServerTimeNow()
		for model, history in histories do
			if not model.Parent then
				histories[model] = nil
				continue
			end
			table.insert(history, capture(model, now))
			while history[1] and now - history[1].Time > Settings.History do
				table.remove(history, 1)
			end
		end
	end)
end

return LagCompensation
