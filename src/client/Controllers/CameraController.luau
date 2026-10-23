--!strict
-- First-person camera feel: slide/crouch drop, landing dip, strafe tilt, scope zoom,
-- and FOV changes for sprint, slide and Flow.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.MovementConfig)
local Spring = require(ReplicatedStorage.Shared.Util.Spring)
local MovementController = require(script.Parent.MovementController)
local WeaponController = require(script.Parent.WeaponController)

local player = Players.LocalPlayer
local CameraConfig = Config.Camera

local CameraController = {}

-- Frame-rate independent smoothing toward a target.
local function smooth(current: number, target: number, sharpness: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-sharpness * dt))
end

function CameraController.Start()
	local movementState = MovementController.State
	local weaponState = WeaponController.State
	player.CameraMode = Enum.CameraMode.LockFirstPerson

	local drop = 0
	local roll = 0
	local fov = CameraConfig.BaseFov
	local dip = Spring.new(0, CameraConfig.SpringStiffness, CameraConfig.SpringDamping)
	local seenLandCount = movementState.LandCount

	-- Runs right after the default camera script, which rebuilds its CFrame from
	-- scratch every frame, so the roll applied here never stacks up.
	RunService:BindToRenderStep("SniperCamera", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		local camera = workspace.CurrentCamera
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not camera or not humanoid then
			return
		end

		if movementState.LandCount ~= seenLandCount then
			seenLandCount = movementState.LandCount
			local kick = math.min(movementState.LastLandSpeed * CameraConfig.LandDipScale, CameraConfig.LandDipMax)
			dip:Impulse(-kick)
		end

		local targetDrop = if movementState.Sliding
			then CameraConfig.SlideDrop
			elseif movementState.Crouching then CameraConfig.CrouchDrop
			else 0
		drop = smooth(drop, targetDrop, CameraConfig.DropSharpness, dt)
		humanoid.CameraOffset = Vector3.new(0, -drop + dip:Update(dt), 0)

		-- No tilt while scoping: a leaning scope is hard to aim with.
		local tiltAmount = if weaponState.AdsAlpha > 0
			then 0
			elseif movementState.Sliding then CameraConfig.SlideTilt
			elseif not movementState.Grounded then CameraConfig.AirStrafeTilt
			else 0
		-- Negative roll leans the view to the right.
		roll = smooth(roll, -movementState.StrafeInput * tiltAmount, CameraConfig.TiltSharpness, dt)
		camera.CFrame *= CFrame.Angles(0, 0, math.rad(roll))

		local targetFov = CameraConfig.BaseFov
			+ Config.Flow.Tiers[movementState.Tier].FovBonus
			+ (if movementState.Sliding then CameraConfig.SlideFovBoost else 0)
			+ (if movementState.Sprinting then CameraConfig.SprintFovBoost else 0)
		fov = smooth(fov, targetFov, CameraConfig.FovSharpness, dt)
		camera.FieldOfView = WeaponController.ApplyZoom(fov)
	end)
end

return CameraController
