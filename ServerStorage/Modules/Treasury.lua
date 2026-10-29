-- Treasury (SERVER ONLY): the shared lobby profile store.
-- DataStore "PannuTreasury", one profile per player:
--   { DaySurvived, Badges, Flakes, OwnedClasses, EquippedClass }
-- DaySurvived is the BEST days survived (the lobby tag reads
-- this). Flakes are earned at payout time (1 per 3 days, paid
-- when a run ends or a player leaves mid-run -- that payout
-- code lands later; this module is the read/write gate for it).
-- All reads are pcall-guarded: a DataStore failure returns the
-- default profile, never an error that breaks a join.
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

-- Save the cached profile. Callers (payout code, shop code)
-- update the profile table first, then call Save.
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

-- Studio: DataStore calls are disabled unless Studio access
-- is enabled in Creator Dashboard, so GetProfile just returns
-- the default (DaySurvived 0) in Studio. That is expected,
-- not a bug -- set the attribute below in a Studio test if
-- you want to see a non-zero tag.
function Treasury.DaysFor(player)
	local attr = player:GetAttribute("DaysSurvived")
	if typeof(attr) == "number" then
		return attr
	end
	return Treasury.GetProfile(player).DaySurvived or 0
end

return Treasury
