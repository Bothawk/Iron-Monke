--!strict
-- Match HUD: the timer and leader at the top, "MATCH START" / "MATCH OVER"
-- banners, the warm-up map vote, and the results screen with a top-3 podium and
-- standings. Reads the attributes MatchService keeps on ReplicatedStorage.Match.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local SoundController = require(script.Parent.SoundController)

local player = Players.LocalPlayer

local VOTE_KEYS = { Enum.KeyCode.F1, Enum.KeyCode.F2, Enum.KeyCode.F3, Enum.KeyCode.F4 }
local MAP_NAMES = { CinderTerraces = "Cinder Terraces", TestRange = "Test Range" }
local BANNER_TIME = 2.5
local ACCENT = Color3.fromRGB(255, 140, 40)
local PANEL = Color3.fromRGB(14, 14, 18)
local PODIUM_COLORS = { Color3.fromRGB(255, 196, 60), Color3.fromRGB(200, 205, 215), Color3.fromRGB(205, 130, 80) }

local MatchHud = {}

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.7
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

local function formatTime(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

function MatchHud.Start()
	local match = ReplicatedStorage:WaitForChild("Match")
	local voteEvent = Net.Event(Net.Names.MatchVote)

	local gui = Instance.new("ScreenGui")
	gui.Name = "MatchHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8

	-- Top center: timer and goal.
	local timer = label(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(200, 34),
		Font = Enum.Font.GothamBlack,
		TextSize = 30,
	})
	local goal = label(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 42),
		Size = UDim2.fromOffset(500, 18),
		TextSize = 14,
		TextColor3 = Color3.fromRGB(200, 200, 200),
	})

	local banner = label(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(700, 60),
		Font = Enum.Font.GothamBlack,
		TextSize = 52,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	local bannerSub = label(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.3, 42),
		Size = UDim2.fromOffset(700, 24),
		TextSize = 18,
		TextColor3 = ACCENT,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})

	-- Map vote, shown during warm-up and on the results screen.
	local votePanel = Instance.new("Frame")
	votePanel.AnchorPoint = Vector2.new(0.5, 0)
	votePanel.Position = UDim2.new(0.5, 0, 0, 70)
	votePanel.Size = UDim2.fromOffset(0, 40)
	votePanel.AutomaticSize = Enum.AutomaticSize.X
	votePanel.BackgroundTransparency = 1
	votePanel.Visible = false
	local voteLayout = Instance.new("UIListLayout")
	voteLayout.FillDirection = Enum.FillDirection.Horizontal
	voteLayout.Padding = UDim.new(0, 8)
	voteLayout.SortOrder = Enum.SortOrder.LayoutOrder
	voteLayout.Parent = votePanel
	votePanel.Parent = gui
	local voteButtons: { [string]: TextButton } = {}
	local myVote: string? = nil

	local function getOptions(): { string }
		local raw = match:GetAttribute("VoteOptions")
		return if typeof(raw) == "string" and raw ~= "" then raw:split(",") else {}
	end

	local function vote(mapId: string)
		myVote = mapId
		voteEvent:FireServer(mapId)
		SoundController.Play("UiClick", "UI")
	end

	local function refreshVoteButtons(results: boolean)
		local options = getOptions()
		for mapId, button in voteButtons do
			if not table.find(options, mapId) then
				button:Destroy()
				voteButtons[mapId] = nil
			end
		end
		for i, mapId in options do
			local button = voteButtons[mapId]
			if not button then
				local newButton = Instance.new("TextButton")
				newButton.Size = UDim2.fromOffset(200, 40)
				newButton.BackgroundColor3 = PANEL
				newButton.BackgroundTransparency = 0.2
				newButton.BorderSizePixel = 0
				newButton.Font = Enum.Font.GothamBold
				newButton.TextSize = 15
				newButton.TextColor3 = Color3.new(1, 1, 1)
				newButton.AutoButtonColor = true
				Instance.new("UICorner", newButton).CornerRadius = UDim.new(0, 6)
				local stroke = Instance.new("UIStroke")
				stroke.Name = "Selected"
				stroke.Color = ACCENT
				stroke.Thickness = 2
				stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				stroke.Parent = newButton
				newButton.MouseButton1Click:Connect(function()
					vote(mapId)
				end)
				newButton.MouseEnter:Connect(function()
					SoundController.Play("UiHover", "UI")
				end)
				newButton.Parent = votePanel
				voteButtons[mapId] = newButton
				button = newButton
			end
			local count = match:GetAttribute(`Votes_{mapId}`) or 0
			button.LayoutOrder = i
			button.Text = string.format("F%d  %s   %d", i, MAP_NAMES[mapId] or mapId, count)
			button.Modal = results -- frees the mouse on the results screen so the buttons can be clicked
			local selected = button:FindFirstChild("Selected") :: UIStroke
			selected.Enabled = myVote == mapId
		end
	end

	-- Results screen.
	local results = Instance.new("Frame")
	results.AnchorPoint = Vector2.new(0.5, 0.5)
	results.Position = UDim2.fromScale(0.5, 0.5)
	results.Size = UDim2.fromOffset(640, 440)
	results.BackgroundColor3 = PANEL
	results.BackgroundTransparency = 0.1
	results.BorderSizePixel = 0
	results.Visible = false
	Instance.new("UICorner", results).CornerRadius = UDim.new(0, 10)
	results.Parent = gui
	local resultsTitle = label(results, {
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 40),
		Font = Enum.Font.GothamBlack,
		TextSize = 34,
	})
	local resultsMap = label(results, {
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 14,
		TextColor3 = Color3.fromRGB(170, 170, 170),
	})
	local podium = Instance.new("Frame")
	podium.Position = UDim2.fromOffset(0, 90)
	podium.Size = UDim2.new(1, 0, 0, 170)
	podium.BackgroundTransparency = 1
	podium.Parent = results
	local standingsList = Instance.new("Frame")
	standingsList.Position = UDim2.fromOffset(40, 270)
	standingsList.Size = UDim2.new(1, -80, 0, 160)
	standingsList.BackgroundTransparency = 1
	standingsList.Parent = results
	local standingsLayout = Instance.new("UIListLayout")
	standingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	standingsLayout.Padding = UDim.new(0, 2)
	standingsLayout.Parent = standingsList

	local function showResults(payload: any)
		for _, child in podium:GetChildren() do
			child:Destroy()
		end
		for _, child in standingsList:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
		local winner = tostring(payload.Winner or "")
		resultsTitle.Text = if winner ~= "" then `{winner} WINS` else "NO WINNER"
		resultsTitle.TextColor3 = if payload.WinnerUserId == player.UserId then ACCENT else Color3.new(1, 1, 1)
		resultsMap.Text = tostring(payload.MapName or "")

		local standings = if typeof(payload.Standings) == "table" then payload.Standings else {}
		-- Podium order left to right: 2nd, 1st, 3rd.
		local slots = {
			{ Rank = 2, X = 0.2, Height = 120 },
			{ Rank = 1, X = 0.5, Height = 150 },
			{ Rank = 3, X = 0.8, Height = 100 },
		}
		for _, slot in slots do
			local entry = standings[slot.Rank]
			if entry then
				local column = Instance.new("Frame")
				column.AnchorPoint = Vector2.new(0.5, 1)
				column.Position = UDim2.fromScale(slot.X, 1)
				column.Size = UDim2.fromOffset(150, slot.Height)
				column.BackgroundTransparency = 1
				column.Parent = podium
				local avatar = Instance.new("ImageLabel")
				avatar.AnchorPoint = Vector2.new(0.5, 0)
				avatar.Position = UDim2.fromScale(0.5, 0)
				avatar.Size = UDim2.fromOffset(64, 64)
				avatar.BackgroundColor3 = PODIUM_COLORS[slot.Rank]
				avatar.Image = `rbxthumb://type=AvatarHeadShot&id={entry.UserId}&w=150&h=150`
				Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)
				avatar.Parent = column
				label(column, {
					Position = UDim2.fromOffset(0, 68),
					Size = UDim2.new(1, 0, 0, 20),
					TextSize = 16,
					Text = tostring(entry.Name),
				})
				label(column, {
					Position = UDim2.fromOffset(0, 88),
					Size = UDim2.new(1, 0, 0, 18),
					TextSize = 14,
					TextColor3 = PODIUM_COLORS[slot.Rank],
					Text = `#{slot.Rank}  ·  {entry.Kills} kills`,
				})
			end
		end

		for rank, entry in standings do
			local mine = entry.UserId == player.UserId
			label(standingsList, {
				LayoutOrder = rank,
				Size = UDim2.new(1, 0, 0, 18),
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = if mine then ACCENT else Color3.new(1, 1, 1),
				Text = string.format(
					"%d.  %s   —   %d kills   %d deaths   %d headshots   best streak %d",
					rank,
					tostring(entry.Name),
					entry.Kills,
					entry.Deaths,
					entry.Headshots,
					entry.BestStreak
				),
			})
		end
	end

	Net.Event(Net.Names.MatchResults).OnClientEvent:Connect(function(payload: any)
		if typeof(payload) == "table" then
			showResults(payload)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		local index = table.find(VOTE_KEYS, input.KeyCode)
		local phase = match:GetAttribute("Phase")
		if index and (phase == "Intermission" or phase == "Results") then
			local mapId = getOptions()[index]
			if mapId then
				vote(mapId)
			end
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")

	local lastPhase: any = nil
	local bannerShownAt = -math.huge

	local function showBanner(text: string, sub: string)
		banner.Text = text
		bannerSub.Text = sub
		bannerShownAt = os.clock()
	end

	RunService.RenderStepped:Connect(function()
		local phase = match:GetAttribute("Phase")
		local endsAt = match:GetAttribute("PhaseEndsAt")
		local remaining = if typeof(endsAt) == "number" then endsAt - workspace:GetServerTimeNow() else 0
		local mapName = tostring(match:GetAttribute("MapName") or "")

		if phase ~= lastPhase then
			if phase == "Playing" then
				showBanner("MATCH START", `{match:GetAttribute("Mode")}  ·  {mapName}`)
				SoundController.Play("MatchStart", "UI")
			elseif phase == "Results" then
				-- Votes open on the results screen and carry into the warm-up.
				myVote = nil
				showBanner("MATCH OVER", "")
				SoundController.Play("MatchEnd", "UI")
			end
			lastPhase = phase
		end

		local myKills = player:GetAttribute("Kills") or 0
		if phase == "Playing" then
			timer.Text = formatTime(remaining)
			local leaderName = tostring(match:GetAttribute("LeaderName") or "")
			local leaderText = if leaderName ~= ""
				then `leader {leaderName} ({match:GetAttribute("LeaderKills")})`
				else "no kills yet"
			goal.Text = `FIRST TO {match:GetAttribute("KillTarget")}  ·  you {myKills}  ·  {leaderText}`
		elseif phase == "Intermission" then
			timer.Text = formatTime(remaining)
			goal.Text = `WARM-UP  ·  next match in {math.max(0, math.ceil(remaining))}s  ·  vote with F1 / F2`
		elseif phase == "Results" then
			timer.Text = ""
			goal.Text = `next match in {math.max(0, math.ceil(remaining + MatchConfig.IntermissionTime))}s`
		else
			timer.Text = ""
			goal.Text = ""
		end

		results.Visible = phase == "Results"
		local voting = phase == "Intermission" or phase == "Results"
		votePanel.Visible = voting
		if voting then
			votePanel.Position = if phase == "Results" then UDim2.new(0.5, 0, 0.5, 240) else UDim2.new(0.5, 0, 0, 70)
			refreshVoteButtons(phase == "Results")
		end

		local age = (os.clock() - bannerShownAt) / BANNER_TIME
		local fade = math.clamp((age - 0.6) / 0.4, 0, 1)
		banner.TextTransparency = fade
		banner.TextStrokeTransparency = math.max(0.6, fade)
		bannerSub.TextTransparency = fade
		bannerSub.TextStrokeTransparency = math.max(0.6, fade)
	end)
end

return MatchHud
