--!strict
-- The knife. Left click slashes (50 damage, short reach). Right click lunges: a
-- quick dash forward that hits the first enemy it reaches for 100 damage. Hits are
-- checked here first, then the server re-checks reach and line of sight.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local KillTags = require(ReplicatedStorage.Shared.Combat.KillTags)
local MovementConfig = require(ReplicatedStorage.Shared.Config.MovementConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local MovementController = require(script.Parent.MovementController)
local WeaponController = require(script.Parent.WeaponController)
local Inspect = require(script.Parent.Parent.Weapon.Inspect)
local Viewmodel = require(script.Parent.Parent.Weapon.Viewmodel)

local player = Players.LocalPlayer
local Knife = WeaponConfig.Knife

local SLASH_INPUTS = { Enum.UserInputType.MouseButton1 }
local SLASH_BUTTONS = { Enum.KeyCode.ButtonR2 }
local LUNGE_INPUTS = { Enum.UserInputType.MouseButton2 }
local LUNGE_BUTTONS = { Enum.KeyCode.ButtonL2 }

local SLASH_ANIMATION_TIME = 0.25
local LUNGE_ANIMATION_TIME = 0.35
local BOB_AMOUNT = 0.04
local BOB_SPEED = 0.55

local KnifeController = {}

KnifeController.Swung = Signal.new() -- (kind: "Slash" | "Lunge")

local meleeHit = Net.Event(Net.Names.MeleeHit)
local viewmodel = Viewmodel.new("Knife")

local lastSlashAt = -math.huge
local lastLungeAt = -math.huge
local lungeHitDone = true
local bobPhase = 0

local function ready(): boolean
	local weapon = WeaponController.State
	return weapon.Alive and weapon.Equipped == "Knife" and weapon.SwitchProgress >= 1
end

-- Finds a living enemy character in a short sphere sweep.
local function sweep(origin: Vector3, direction: Vector3, distance: number, radius: number): Model?
	local ignore: { Instance } = { workspace.CurrentCamera }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Spherecast(origin, radius, direction * distance, params)
	if not hit then
		return nil
	end
	local model = hit.Instance:FindFirstAncestorOfClass("Model")
	while model and not model:FindFirstChildOfClass("Humanoid") do
		model = model:FindFirstAncestorOfClass("Model")
	end
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if model and humanoid and humanoid.Health > 0 then
		return model
	end
	return nil
end

local function context(): KillTags.ShotContext
	local movement = MovementController.State
	return {
		AdsAlpha = 0,
		ScopedFor = 0,
		Airborne = not movement.Grounded,
		Overflow = movement.OverflowRemaining > 0,
	}
end

local function reportHit(kind: "Slash" | "Lunge", victim: Model)
	meleeHit:FireServer(kind, victim, workspace:GetServerTimeNow(), context())
	WeaponController.Hit:Fire("Body", false)
end

local function slash()
	local now = os.clock()
	if not ready() or now - lastSlashAt < Knife.Slash.Cooldown or now - lastLungeAt < LUNGE_ANIMATION_TIME then
		return
	end
	lastSlashAt = now
	WeaponController.CancelInspect()
	KnifeController.Swung:Fire("Slash")

	local camera = workspace.CurrentCamera
	local victim = sweep(camera.CFrame.Position, camera.CFrame.LookVector, Knife.Slash.Range, Knife.Slash.Radius)
	if victim then
		reportHit("Slash", victim)
	end
end

local function lunge()
	local now = os.clock()
	if not ready() or now - lastLungeAt < Knife.Lunge.Cooldown then
		return
	end
	lastLungeAt = now
	lungeHitDone = false
	WeaponController.CancelInspect()
	KnifeController.Swung:Fire("Lunge")
	MovementController.Dash(workspace.CurrentCamera.CFrame.LookVector, Knife.Lunge.DashDistance, Knife.Lunge.DashTime)
end

-- While the lunge dash lasts, check just ahead of the player each frame.
local function updateLunge()
	if lungeHitDone then
		return
	end
	if not MovementController.IsDashing() and os.clock() - lastLungeAt > Knife.Lunge.DashTime then
		lungeHitDone = true
		return
	end
	local camera = workspace.CurrentCamera
	local victim = sweep(camera.CFrame.Position, camera.CFrame.LookVector, Knife.Lunge.HitRange, Knife.Lunge.Radius)
	if victim then
		lungeHitDone = true
		reportHit("Lunge", victim)
	end
end

-- A sideways slash arc, or a straight stab for the lunge.
local function swingOffset(now: number): CFrame
	local slashAge = (now - lastSlashAt) / SLASH_ANIMATION_TIME
	if slashAge >= 0 and slashAge < 1 then
		local curve = math.sin(slashAge * math.pi)
		return CFrame.new(-0.6 * curve, 0.15 * curve, -0.3 * curve)
			* CFrame.Angles(math.rad(-15) * curve, math.rad(70) * curve, math.rad(-40) * curve)
	end
	local lungeAge = (now - lastLungeAt) / LUNGE_ANIMATION_TIME
	if lungeAge >= 0 and lungeAge < 1 then
		local curve = math.sin(lungeAge * math.pi)
		return CFrame.new(-0.4 * curve, 0.2 * curve, -0.9 * curve) * CFrame.Angles(math.rad(-25) * curve, 0, 0)
	end
	return CFrame.identity
end

-- For the touch buttons.
KnifeController.Slash = slash
KnifeController.Lunge = lunge

function KnifeController.Start()
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or WeaponController.State.Equipped ~= "Knife" then
			return
		end
		if table.find(SLASH_INPUTS, input.UserInputType) or table.find(SLASH_BUTTONS, input.KeyCode) then
			slash()
		elseif table.find(LUNGE_INPUTS, input.UserInputType) or table.find(LUNGE_BUTTONS, input.KeyCode) then
			lunge()
		end
	end)

	player.CharacterAdded:Connect(function(character)
		viewmodel:SetSkinColor(character)
	end)
	player.CharacterAppearanceLoaded:Connect(function(character)
		viewmodel:SetSkinColor(character)
	end)

	RunService:BindToRenderStep("Knife", Enum.RenderPriority.Camera.Value + 3, function(dt: number)
		local now = os.clock()
		updateLunge()

		local movement = MovementController.State
		local bob = Vector2.zero
		if movement.Grounded and not movement.Sliding then
			bobPhase += movement.Speed * dt * BOB_SPEED * math.pi
			local strength = math.clamp(movement.Speed / MovementConfig.SprintSpeed, 0, 1) * BOB_AMOUNT
			bob = Vector2.new(math.sin(bobPhase) * strength, -math.abs(math.cos(bobPhase)) * strength)
		end

		local detached, glow = CFrame.identity, 0
		local style, elapsed = WeaponController.GetInspect("Knife")
		if style then
			local motion, _, inspectGlow = Inspect.Pose(style, elapsed)
			detached, glow = motion, inspectGlow
		end
		viewmodel:SetGlow(glow)

		local lower = WeaponController.GetLower("Knife")
		viewmodel:SetVisible(WeaponController.State.Alive and lower < 1)
		viewmodel:Update(workspace.CurrentCamera, {
			AdsAlpha = 0,
			Lower = lower,
			Extra = swingOffset(now),
			Detached = detached,
			KickBack = 0,
			KickPitch = 0,
			Dip = 0,
			BoltPull = 0,
			Sway = Vector2.zero,
			Bob = bob,
		})
	end)
end

return KnifeController
