local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Treasury = require(script.Parent:WaitForChild("Treasury"))
local FlakesPayout = {}
local paid = {}
local function daysForRun(player, days)
	if typeof(days) == "number" then
		return math.max(0, math.floor(days))
	end
	local attr = player:GetAttribute("DaysSurvived")
	if typeof(attr) == "number" then
		return math.max(0, math.floor(attr))
	end
	return 0
end
function FlakesPayout.Pay(player, days)
	if not player or not player.Parent then
		return 0, false
	end
	if paid[player] then
		return 0, false
	end
	paid[player] = true
	local survived = daysForRun(player, days)
	local flakes = math.floor(survived / 3)
	local profile = Treasury.GetProfile(player)
	if survived > (profile.DaySurvived or 0) then
		profile.DaySurvived = survived
	end
	profile.Flakes = (profile.Flakes or 0) + flakes
	Treasury.Save(player)
	return flakes, true
end
function FlakesPayout.WasPaid(player)
	return paid[player] == true
end
Players.PlayerRemoving:Connect(function(player)
	paid[player] = nil
end)
return FlakesPayout
