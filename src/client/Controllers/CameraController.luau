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
	-- Firing punches the FOV and kicks the view up; both springs settle back to 0.
	local fovPunch = Spring.new(0, CameraConfig.SpringStiffness, CameraConfig.SpringDamping)
	local viewKick = Spring.new(0, CameraConfig.SpringStiffness, CameraConfig.SpringDamping)
	WeaponController.Fired:Connect(function()
		fovPunch:Impulse(CameraConfig.FireFovPunch)
		viewKick:Impulse(math.rad(CameraConfig.FireViewKick))
	end)

	MovementController.Landed:Connect(function(fallSpeed: number)
		dip:Impulse(-math.min(fallSpeed * CameraConfig.LandDipScale, CameraConfig.LandDipMax))
	end)

	-- Runs right after the default camera script, which rebuilds its CFrame from
	-- scratch every frame, so the roll applied here never stacks up.
	RunService:BindToRenderStep("SniperCamera", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		local camera = workspace.CurrentCamera
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		-- The death cam takes over the camera (Scriptable) while dead.
		if not camera or not humanoid or camera.CameraType ~= Enum.CameraType.Custom then
			return
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
		local sway = weaponState.AimSway
		camera.CFrame *= CFrame.Angles(viewKick:Update(dt) + sway.Y, sway.X, math.rad(roll))

		local targetFov = CameraConfig.BaseFov
			+ Config.Flow.Tiers[movementState.Tier].FovBonus
			+ (if movementState.Sliding then CameraConfig.SlideFovBoost else 0)
			+ (if movementState.Sprinting then CameraConfig.SprintFovBoost else 0)
		fov = smooth(fov, targetFov, CameraConfig.FovSharpness, dt)
		camera.FieldOfView = WeaponController.ApplyZoom(fov + fovPunch:Update(dt))
	end)
end

return CameraController
