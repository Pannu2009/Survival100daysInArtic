local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Treasury = {}
local STORE_NAME = "PannuTreasury"
local store = nil
local ok, err = pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
end)
if not ok then
	warn("[Treasury] DataStore unavailable:", err)
end
local cache = {}
function Treasury.DefaultProfile()
	return {
		DaySurvived = 0,
		Badges = {},
		Flakes = 0,
		OwnedClasses = {},
		EquippedClass = "",
	}
end
function Treasury.GetProfile(player)
	if cache[player] then
		return cache[player]
	end
	local profile = Treasury.DefaultProfile()
	if store then
		local data
		local success, result = pcall(function()
			return store:GetAsync("player_" .. player.UserId)
		end)
		if success and type(result) == "table" then
			for key, value in pairs(Treasury.DefaultProfile()) do
				if result[key] ~= nil then
					profile[key] = result[key]
				end
			end
		end
	end
	cache[player] = profile
	return profile
end
function Treasury.Save(player)
	local profile = cache[player]
	if not profile or not store then
		return false
	end
	local success = pcall(function()
		store:SetAsync("player_" .. player.UserId, profile)
	end)
	return success
end
Players.PlayerRemoving:Connect(function(player)
	cache[player] = nil
end)
function Treasury.DaysFor(player)
	local attr = player:GetAttribute("DaysSurvived")
	if typeof(attr) == "number" then
		return attr
	end
	return Treasury.GetProfile(player).DaySurvived or 0
end
return Treasury
