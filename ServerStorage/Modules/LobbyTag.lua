-- LobbyTag: the days-survived tag above a player's head.
-- Source object (built in Studio, NOT in this repo):
--   ReplicatedStorage.utils.DSLT
-- On join, DSLT is cloned onto the player's head and its
-- TextLabel's Text is set to the days survived (Treasury
-- DaySurvived, or the DaysSurvived attribute in Studio).
-- If DSLT is missing, this prints a warning and does
-- nothing -- it never errors a join.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Treasury = require(script.Parent:WaitForChild("Treasury"))

local LobbyTag = {}
local tags = {}

local function findTextLabel(instance)
	if not instance then
		return nil
	end
	if instance:IsA("TextLabel") then
		return instance
	end
	local direct = instance:FindFirstChild("TextLabel")
	if direct and direct:IsA("TextLabel") then
		return direct
	end
	return instance:FindFirstChildWhichIsA("TextLabel", true)
end

function LobbyTag.TagPlayer(player)
	local template = nil
	local utils = ReplicatedStorage:FindFirstChild("utils")
	if utils then
		template = utils:FindFirstChild("DSLT")
	end
	if not template then
		warn("[LobbyTag] ReplicatedStorage.utils.DSLT not found -- tag skipped for " .. player.Name)
		return nil
	end
	local character = player.Character or player.CharacterAdded:Wait()
	local head = character:WaitForChild("Head", 5)
	if not head then
		return nil
	end
	local old = tags[player]
	if old and old.Parent then
		old:Destroy()
	end
	local clone = template:Clone()
	local label = findTextLabel(clone)
	if label then
		label.Text = tostring(Treasury.DaysFor(player))
	else
		warn("[LobbyTag] DSLT has no TextLabel -- tag cloned but text not set")
	end
	-- DSLT is expected to be a BillboardGui (Adornee = head).
	-- If it is a Model/Folder holding one, attach that instead.
	local gui = clone:IsA("BillboardGui") and clone or clone:FindFirstChildWhichIsA("BillboardGui", true)
	if gui then
		gui.Adornee = head
		gui.Parent = head
		tags[player] = gui
	else
		clone.Parent = head
		tags[player] = clone
	end
	return tags[player]
end

function LobbyTag.Update(player)
	local tag = tags[player]
	if not tag then
		return
	end
	local label = findTextLabel(tag)
	if label then
		label.Text = tostring(Treasury.DaysFor(player))
	end
end

function LobbyTag.Start()
	Players.PlayerAdded:Connect(function(player)
		LobbyTag.TagPlayer(player)
		player.CharacterAdded:Connect(function()
			LobbyTag.TagPlayer(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		tags[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			LobbyTag.TagPlayer(player)
		end)
	end
end

return LobbyTag
