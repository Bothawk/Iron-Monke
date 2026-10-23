--!strict
-- After dying, the camera flies to just behind the killer's head and looks back at
-- where you fell, with a panel showing who it was, their health, the weapon, the
-- distance and how they got you. It hands the camera back on respawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local WeaponController = require(script.Parent.WeaponController)

local player = Players.LocalPlayer

local FLY_TIME = 0.6
local BEHIND_KILLER = 4 -- studs behind the killer's head
local ABOVE_KILLER = 1.5
local ORBIT_DISTANCE = 12 -- with no killer (a fall), circle the body instead
local ACCENT = Color3.fromRGB(255, 140, 40)
local RED = Color3.fromRGB(255, 60, 60)

local DeathCamController = {}

type KillInfo = {
	Killer: string,
	KillerUserId: number,
	Weapon: string,
	Distance: number,
	Tags: { string },
}

function DeathCamController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DeathCam"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 5

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -90)
	panel.Size = UDim2.fromOffset(420, 110)
	panel.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
	panel.BackgroundTransparency = 0.2
	panel.BorderSizePixel = 0
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
	panel.Parent = gui

	local function text(props: { [string]: any }): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Font = Enum.Font.GothamBold
		for key, value in props do
			(label :: any)[key] = value
		end
		label.Parent = panel
		return label
	end

	local title = text({ Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 0, 18), TextSize = 13 })
	title.TextColor3 = Color3.fromRGB(170, 170, 170)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "ELIMINATED BY"
	local killerName = text({
		Position = UDim2.fromOffset(16, 28),
		Size = UDim2.new(1, -32, 0, 30),
		TextSize = 26,
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local details = text({
		Position = UDim2.fromOffset(16, 60),
		Size = UDim2.new(1, -32, 0, 18),
		TextSize = 14,
		TextColor3 = ACCENT,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local healthBack = Instance.new("Frame")
	healthBack.Position = UDim2.fromOffset(16, 88)
	healthBack.Size = UDim2.new(1, -32, 0, 6)
	healthBack.BackgroundColor3 = Color3.new(0, 0, 0)
	healthBack.BackgroundTransparency = 0.4
	healthBack.BorderSizePixel = 0
	healthBack.Parent = panel
	local healthFill = Instance.new("Frame")
	healthFill.Size = UDim2.fromScale(1, 1)
	healthFill.BorderSizePixel = 0
	healthFill.BackgroundColor3 = Color3.new(1, 1, 1)
	healthFill.Parent = healthBack
	local respawnText = text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 10),
		Size = UDim2.fromOffset(300, 20),
		TextSize = 14,
	})

	gui.Parent = player:WaitForChild("PlayerGui")

	local lastKill: KillInfo? = nil
	local active = false
	local diedAt = 0
	local deathPosition = Vector3.zero
	local startCFrame = CFrame.identity

	WeaponController.Damaged:Connect(function(info: any)
		if typeof(info) == "table" and info.Killed then
			lastKill = {
				Killer = tostring(info.Killer),
				KillerUserId = tonumber(info.KillerUserId) or 0,
				Weapon = tostring(info.Weapon),
				Distance = tonumber(info.Distance) or 0,
				Tags = if typeof(info.Tags) == "table" then info.Tags else {},
			}
		end
	end)

	local function onDied()
		local camera = workspace.CurrentCamera
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		deathPosition = if head and head:IsA("BasePart") then head.Position else camera.CFrame.Position
		startCFrame = camera.CFrame
		diedAt = os.clock()
		active = true
		camera.CameraType = Enum.CameraType.Scriptable

		local kill = lastKill
		if kill then
			killerName.Text = kill.Killer
			local parts = { kill.Weapon, `{math.floor(kill.Distance + 0.5)} studs` }
			for _, tag in kill.Tags do
				table.insert(parts, tag)
			end
			details.Text = table.concat(parts, "  ·  ")
			panel.Visible = true
		else
			panel.Visible = false
		end
		gui.Enabled = true
	end

	local function onCharacterAdded(character: Model)
		active = false
		lastKill = nil
		gui.Enabled = false
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		camera.CameraSubject = humanoid
		humanoid.Died:Connect(onDied)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end

	RunService.RenderStepped:Connect(function()
		if not active then
			return
		end
		local camera = workspace.CurrentCamera
		local age = os.clock() - diedAt
		respawnText.Text = string.format("Respawning in %.1f", math.max(0, WeaponConfig.RespawnTime - age))

		local kill = lastKill
		local killer = if kill then Players:GetPlayerByUserId(kill.KillerUserId) else nil
		local killerCharacter = killer and killer.Character
		local killerHead = killerCharacter and killerCharacter:FindFirstChild("Head")
		local killerHumanoid = killerCharacter and killerCharacter:FindFirstChildOfClass("Humanoid")

		local target: CFrame
		if killerHead and killerHead:IsA("BasePart") then
			-- Behind the killer, looking past them at where you fell.
			local toVictim = deathPosition - killerHead.Position
			local flat = Vector3.new(toVictim.X, 0, toVictim.Z)
			local back = if flat.Magnitude > 1e-3 then -flat.Unit else Vector3.zAxis
			local eye = killerHead.Position + back * BEHIND_KILLER + Vector3.yAxis * ABOVE_KILLER
			target = CFrame.lookAt(eye, deathPosition)
		else
			local angle = age * 0.5
			local eye = deathPosition
				+ Vector3.new(math.cos(angle) * ORBIT_DISTANCE, ORBIT_DISTANCE * 0.5, math.sin(angle) * ORBIT_DISTANCE)
			target = CFrame.lookAt(eye, deathPosition)
		end
		local alpha = math.clamp(age / FLY_TIME, 0, 1)
		alpha = 1 - (1 - alpha) ^ 3
		camera.CFrame = startCFrame:Lerp(target, alpha)

		if killerHumanoid then
			local fraction = math.clamp(killerHumanoid.Health / killerHumanoid.MaxHealth, 0, 1)
			healthFill.Size = UDim2.fromScale(fraction, 1)
			healthFill.BackgroundColor3 = if fraction < 0.35 then RED else Color3.new(1, 1, 1)
		end
	end)
end

return DeathCamController
