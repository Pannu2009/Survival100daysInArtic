-- Queue (LOBBY ONLY): Workspace.QueueFolder.Queue1.
--   Queue1.Base      = the floor part
--   Queue1.Reserved  = transparent box players stand in
--   Queue1.Reserved.DataGui.PlayerLabel.Label = player count
--   Queue1.Reserved.DataGui.TimeLabel.Label   = countdown
--
-- Behaviour: players standing in Reserved are the party.
-- With at least 1 player in, a countdown runs (default 20s,
-- matching the "Going In: 20" you showed). If the party
-- reaches MaxPlayers (5) it teleports early; if the timer
-- hits 0 it teleports with whoever is in. If everyone
-- leaves, the timer resets. Teleport = ReserveServer of
-- THIS place + TeleportToPrivateServer with TeleportData
-- { mode = "game" } -- that private server runs as Game
-- via ServerMode. In Studio, TeleportService cannot run,
-- so it prints what it WOULD teleport instead of erroring.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Queue = {}

local MAX_PLAYERS = 5
local COUNTDOWN_SECONDS = 20

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

function Queue.Start()
	local folder = Workspace:FindFirstChild("QueueFolder")
	local queue = folder and folder:FindFirstChild("Queue1")
	local reserved = queue and queue:FindFirstChild("Reserved")
	if not reserved then
		warn("[Queue] Workspace.QueueFolder.Queue1.Reserved not found -- queue not started")
		return
	end
	local playerLabel = findLabel(queue, "PlayerLabel")
	local timeLabel = findLabel(queue, "TimeLabel")
	if not playerLabel or not timeLabel then
		warn("[Queue] DataGui PlayerLabel/TimeLabel not found -- labels will not update")
	end

	local function playersInQueue()
		local seen = {}
		-- No overlap filter: count distinct players whose
		-- character parts are inside Reserved.
		local parts = Workspace:GetPartsInPart(reserved)
		for _, part in ipairs(parts) do
			local player = Players:GetPlayerFromCharacter(part.Parent)
			if player then
				seen[player] = true
			end
		end
		local list = {}
		for player in pairs(seen) do
			table.insert(list, player)
		end
		return list
	end

	local timer = COUNTDOWN_SECONDS
	local teleporting = false
	task.spawn(function()
		while true do
			task.wait(1)
			if teleporting then
				continue
			end
			local party = playersInQueue()
			local count = #party
			if playerLabel then
				playerLabel.Text = ("Players: %d/%d"):format(count, MAX_PLAYERS)
			end
			if count == 0 then
				timer = COUNTDOWN_SECONDS
			else
				timer -= 1
				if timer <= 0 or count >= MAX_PLAYERS then
					teleporting = true
					if timeLabel then
						timeLabel.Text = "Going In: 0"
					end
					if RunService:IsStudio() then
						print(("[Queue] Studio: would teleport %d player(s) to a private game server"):format(count))
						teleporting = false
						timer = COUNTDOWN_SECONDS
					else
						local ok, code = pcall(function()
							return TeleportService:ReserveServer(game.PlaceId)
						end)
						if ok and code then
							local teleportOk, teleportErr = pcall(function()
								TeleportService:TeleportToPrivateServer(
									game.PlaceId, code, party, nil,
									{ mode = "game" }
								)
							end)
							if not teleportOk then
								warn("[Queue] Teleport failed:", teleportErr)
								teleporting = false
								timer = COUNTDOWN_SECONDS
							end
						else
							warn("[Queue] ReserveServer failed:", code)
							teleporting = false
							timer = COUNTDOWN_SECONDS
						end
					end
				end
			end
			if timeLabel and not teleporting then
				timeLabel.Text = count == 0 and "Waiting..." or ("Going In: %d"):format(math.max(timer, 0))
			end
		end
	end)
end

return Queue
