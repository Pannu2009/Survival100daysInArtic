-- Queue v2 (LOBBY ONLY): Workspace.QueueFolder.Queue1.
--   Queue1.Base      = the floor part
--   Queue1.Reserved  = transparent box players touch to join
--   Queue1.In        = part inside Reserved: joiners are
--                      teleported (moved) here on touch
--   Queue1.Reserved.DataGui.PlayerLabel.Label = player count
--   Queue1.Reserved.DataGui.TimeLabel.Label   = countdown
--
-- Flow:
-- 1. Player touches Reserved -> moved to In, joins the queue.
-- 2. If the queue was empty, that first player is the HOST:
--    he gets a GUI to choose the queue size (1-5) and a
--    Create button. Until he clicks Create, other players
--    touching Reserved wait (they are not counted yet).
-- 3. After Create, other players touch Reserved to join,
--    up to the chosen size.
-- 4. When full (e.g. 5/5, or whatever size was chosen):
--    TimeLabel counts 3, 2, 1, then the party is MOVED to
--    SpawnLocation (so Reserved is empty and a new party
--    can form in the lobby right away), the queue is
--    cleared, and the old party gets a black loading
--    screen and is teleported to a PrivateGameSession
--    (a private server of this same place).
-- In Studio, TeleportService cannot run, so it prints
-- what it would teleport and removes the black screen
-- after a moment, instead of erroring.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local CrossServer = require(script.Parent:WaitForChild("CrossServer"))
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Queue = {}

local MAX_SIZE = 5

local function findLabel(queue, name)
	local reserved = queue and queue:FindFirstChild("Reserved")
	local dataGui = reserved and reserved:FindFirstChild("DataGui")
	local holder = dataGui and dataGui:FindFirstChild(name)
	if not holder then
		return nil
	end
	if holder:IsA("TextLabel") then
		return holder
	end
	local inner = holder:FindFirstChild("Label")
	if inner and inner:IsA("TextLabel") then
		return inner
	end
	return holder:FindFirstChildWhichIsA("TextLabel", true)
end

local function insideBox(part, position)
	if not (part and part:IsA("BasePart")) then
		return false
	end
	local localPos = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(localPos.X) <= half.X
		and math.abs(localPos.Y) <= half.Y + 2
		and math.abs(localPos.Z) <= half.Z
end

local function findSpawnLocation(queue)
	local spawn = Workspace:FindFirstChild("SpawnLocation")
	if spawn and spawn:IsA("BasePart") then
		return spawn
	end
	if queue then
		local qSpawn = queue:FindFirstChild("SpawnLocation")
		if qSpawn and qSpawn:IsA("BasePart") then
			return qSpawn
		end
	end
	return nil
end

local function showBlackScreen(player)
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		return nil
	end
	local old = playerGui:FindFirstChild("TeleportLoading")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "TeleportLoading"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	frame.ZIndex = 10
	frame.Parent = gui
	local loadingLabel = Instance.new("TextLabel")
	loadingLabel.Name = "LoadingLabel"
	loadingLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	loadingLabel.Size = UDim2.fromScale(0.8, 0.2)
	loadingLabel.Position = UDim2.fromScale(0.5, 0.5)
	loadingLabel.BackgroundTransparency = 1
	loadingLabel.Text = "Loading..."
	loadingLabel.TextColor3 = Color3.new(1, 1, 1)
	loadingLabel.Font = Enum.Font.GothamBold
	loadingLabel.TextScaled = true
	loadingLabel.ZIndex = 11
	loadingLabel.Parent = gui
	gui.Parent = playerGui
	return gui
end

local function makeHostGui(player, remote)
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		return nil
	end
	local old = playerGui:FindFirstChild("HostQueueGui")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "HostQueueGui"
	gui.ResetOnSpawn = false
	-- Mobile-compatible: everything in Scale, not Offset, so
	-- the GUI adapts to phone screens instead of overflowing
	-- or shrinking to a corner. Anchor in the centre.
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.85, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(11, 30, 46)
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.22)
	title.BackgroundTransparency = 1
	title.Text = "Choose Queue Size"
	title.TextColor3 = Color3.fromRGB(221, 227, 231)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.Parent = frame
	for i = 1, MAX_SIZE do
		local button = Instance.new("TextButton")
		button.Name = "Size" .. i
		button.Size = UDim2.fromScale(0.16, 0.35)
		button.Position = UDim2.new(0.04 + (i - 1) * 0.19, 0, 0.30, 0)
		button.Text = tostring(i)
		button.TextColor3 = Color3.fromRGB(11, 30, 46)
		button.BackgroundColor3 = Color3.fromRGB(221, 227, 231)
		button.Font = Enum.Font.GothamBold
		button.TextScaled = true
		button.Parent = frame
	end
	local create = Instance.new("TextButton")
	create.Name = "CreateButton"
	create.AnchorPoint = Vector2.new(0.5, 0.5)
	create.Size = UDim2.fromScale(0.5, 0.25)
	create.Position = UDim2.fromScale(0.5, 0.82)
	create.Text = "Create"
	create.TextColor3 = Color3.fromRGB(8, 17, 28)
	create.BackgroundColor3 = Color3.fromRGB(125, 211, 252)
	create.Font = Enum.Font.GothamBold
	create.TextScaled = true
	create.Parent = frame
	gui.Parent = playerGui
	return gui
end

function Queue.Start()
	local folder = Workspace:FindFirstChild("QueueFolder")
	local queue = folder and folder:FindFirstChild("Queue1")
	local reserved = queue and queue:FindFirstChild("Reserved")
	local inPart = queue and queue:FindFirstChild("In")
	if not reserved then
		warn("[Queue] Workspace.QueueFolder.Queue1.Reserved not found -- queue not started")
		return
	end
	-- Hollow from the inside: a solid Reserved box pushes a
	-- player back out the moment moveToIn puts him inside
	-- it, and the prune loop then cancels his queue -- which
	-- is why the host GUI got stuck. A queue box is a
	-- VOLUME, not a wall: no collision, touch still on.
	-- In is the same: a teleport target, never a collider.
	reserved.CanCollide = false
	reserved.CanTouch = true
	if inPart and inPart:IsA("BasePart") then
		inPart.CanCollide = false
		inPart.CanTouch = false
		inPart.Anchored = true
	end
	local playerLabel = findLabel(queue, "PlayerLabel")
	local timeLabel = findLabel(queue, "TimeLabel")
	if not playerLabel or not timeLabel then
		warn("[Queue] DataGui PlayerLabel/TimeLabel not found -- labels will not update")
	end

	-- Remote for the host GUI (created here, lobby only).
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	local hostRemote = remotes:FindFirstChild("QueueHostCreate")
	if not hostRemote then
		hostRemote = Instance.new("RemoteEvent")
		hostRemote.Name = "QueueHostCreate"
		hostRemote.Parent = remotes
	end

	local members = {} -- array of players, in join order
	local host = nil
	local queueSize = nil -- nil until the host clicks Create
	local pending = false
	local countingDown = false
	local lastTouch = {}

	local function isMember(player)
		for _, member in ipairs(members) do
			if member == player then
				return true
			end
		end
		return false
	end

	local function updateLabels(countdown)
		if playerLabel then
			if queueSize then
				playerLabel.Text = ("Players: %d/%d"):format(#members, queueSize)
			else
				playerLabel.Text = ("Players: %d/?"):format(#members)
			end
		end
		if timeLabel then
			if countdown then
				timeLabel.Text = ("Going In: %d"):format(countdown)
			elseif pending then
				timeLabel.Text = "Waiting for host..."
			elseif #members == 0 then
				timeLabel.Text = "Waiting..."
			else
				timeLabel.Text = "Waiting for players..."
			end
		end
	end

	local function resetQueue()
		if host then
			local playerGui = host:FindFirstChild("PlayerGui")
			local gui = playerGui and playerGui:FindFirstChild("HostQueueGui")
			if gui then
				gui:Destroy()
			end
		end
		members = {}
		host = nil
		queueSize = nil
		pending = false
		countingDown = false
		updateLabels(nil)
	end

	local function moveToIn(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		if inPart and inPart:IsA("BasePart") then
			root.CFrame = inPart.CFrame + Vector3.new(0, 3, 0)
		else
			root.CFrame = reserved.CFrame + Vector3.new(0, 3, 0)
		end
	end

	local function moveToSpawn(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local spawn = findSpawnLocation(queue)
		if spawn then
			root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
		else
			warn("[Queue] No SpawnLocation found -- party stays at queue")
		end
	end

	local function teleportParty(party)
		-- Black screen first, then teleport. Queue is already
		-- cleared by the caller, so a new party can form.
		for _, player in ipairs(party) do
			showBlackScreen(player)
		end
		if RunService:IsStudio() then
			print(("[Queue] Studio: would teleport %d player(s) to a private game server"):format(#party))
			task.wait(2)
			for _, player in ipairs(party) do
				local playerGui = player:FindFirstChild("PlayerGui")
				local loading = playerGui and playerGui:FindFirstChild("TeleportLoading")
				if loading then
					loading:Destroy()
				end
			end
			return
		end
		local ok, code = pcall(function()
			return TeleportService:ReserveServer(game.PlaceId)
		end)
		if not (ok and code) then
			warn("[Queue] ReserveServer failed:", code)
			return
		end
		-- MemoryStore handoff: the game server reads this
		-- party back and generates from this seed, instead
		-- of rolling its own. TeleportData carries the same
		-- seed as a fallback if MemoryStore is unavailable.
		local seedLetters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
		local seedParts = {}
		for i = 1, 6 do
			local n = math.random(1, #seedLetters)
			seedParts[i] = seedLetters:sub(n, n)
		end
		local partyKey = code .. "-" .. tostring(os.time())
		local memberIds = {}
		for _, member in ipairs(party) do
			table.insert(memberIds, member.UserId)
		end
		CrossServer.SaveParty(partyKey, { Seed = table.concat(seedParts), Members = memberIds })
		local teleportOk, teleportErr = pcall(function()
			TeleportService:TeleportToPrivateServer(
				game.PlaceId, code, party, nil,
				{ mode = "game", partyKey = partyKey, seed = table.concat(seedParts) }
			)
		end)
		if not teleportOk then
			warn("[Queue] Teleport failed:", teleportErr)
		end
	end

	local function startCountdown()
		if countingDown then
			return
		end
		countingDown = true
		task.spawn(function()
			for n = 3, 1, -1 do
				updateLabels(n)
				-- At 1: black screen, move to SpawnLocation,
				-- then teleport -- no extra wait on 1. The
				-- queue is cleared here, so a new party can
				-- form in the lobby right away.
				if n == 1 then
					local party = {}
					for _, member in ipairs(members) do
						table.insert(party, member)
					end
					for _, player in ipairs(party) do
						moveToSpawn(player)
					end
					resetQueue()
					teleportParty(party)
					break
				end
				task.wait(1)
			end
		end)
	end

	hostRemote.OnServerEvent:Connect(function(player, size)
		if player ~= host or not pending then
			return
		end
		if typeof(size) ~= "number" then
			return
		end
		size = math.floor(size)
		if size < 1 or size > MAX_SIZE then
			return
		end
		queueSize = size
		pending = false
		local playerGui = player:FindFirstChild("PlayerGui")
		local gui = playerGui and playerGui:FindFirstChild("HostQueueGui")
		if gui then
			gui:Destroy()
		end
		print(("[Queue] Host %s created a queue of %d"):format(player.Name, size))
		updateLabels(nil)
		if #members >= queueSize then
			startCountdown()
		end
	end)

	reserved.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end
		local now = os.clock()
		if now - (lastTouch[player] or 0) < 1 then
			return
		end
		lastTouch[player] = now
		if countingDown then
			return -- this party is leaving; next party forms after reset
		end
		if isMember(player) then
			return
		end
		-- First player, no queue yet: he is the host.
		if #members == 0 then
			table.insert(members, player)
			host = player
			pending = true
			queueSize = nil
			moveToIn(player)
			makeHostGui(player, hostRemote)
			updateLabels(nil)
			print(("[Queue] Host: %s -- waiting for queue size"):format(player.Name))
			return
		end
		-- Host has not created the queue yet: others wait.
		if pending then
			return
		end
		if queueSize and #members >= queueSize then
			return
		end
		table.insert(members, player)
		moveToIn(player)
		updateLabels(nil)
		if queueSize and #members >= queueSize then
			startCountdown()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		for i, member in ipairs(members) do
			if member == player then
				table.remove(members, i)
				break
			end
		end
		if player == host then
			if pending then
				resetQueue()
			else
				host = nil
			end
		end
		updateLabels(nil)
	end)

	-- Prune players who walked out of Reserved (not during
	-- countdown, when they are being moved to SpawnLocation).
	task.spawn(function()
		while true do
			task.wait(1)
			if not countingDown then
				local changed = false
				for i = #members, 1, -1 do
					local player = members[i]
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart")
					if not root or not insideBox(reserved, root.Position) then
						-- Host walking out before Create cancels the queue.
						if player == host and pending then
							resetQueue()
							changed = false
							break
						end
						table.remove(members, i)
						changed = true
					end
				end
				if #members == 0 and (host or queueSize) then
					resetQueue()
				elseif changed then
					updateLabels(nil)
				end
			end
		end
	end)

	updateLabels(nil)
end

return Queue
