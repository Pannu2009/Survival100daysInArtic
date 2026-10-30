-- Leaderboards: OrderedDataStores, the sorted kind.
-- Two stores, one per board, so the sorts never mix:
--   Arctic_MostDays    key = UserId, value = best day reached
--   Arctic_Fastest100  key = UserId, value = seconds to Day 100
--      (stored as a negative number, because Ordered
--      sorts ascending by default and fastest = smallest)
--
-- Records are best-only: a worse run never overwrites
-- a better one. All calls are pcall-wrapped -- a
-- DataStore outage must never break a game server.
local DataStoreService = game:GetService("DataStoreService")

local Leaderboards = {}

local mostDays = nil
local fastest100 = nil
pcall(function()
	mostDays = DataStoreService:GetOrderedDataStore("Arctic_MostDays")
	fastest100 = DataStoreService:GetOrderedDataStore("Arctic_Fastest100")
end)

function Leaderboards.RecordDays(player, days)
	if not mostDays or typeof(days) ~= "number" then
		return
	end
	pcall(function()
		local old = mostDays:GetAsync(tostring(player.UserId))
		if not old or days > old then
			mostDays:SetAsync(tostring(player.UserId), math.floor(days))
		end
	end)
end

function Leaderboards.RecordFastest100(player, seconds)
	if not fastest100 or typeof(seconds) ~= "number" then
		return
	end
	pcall(function()
		local old = fastest100:GetAsync(tostring(player.UserId))
		-- Stored negative, so "better" means more negative.
		local value = -math.floor(seconds)
		if not old or value < old then
			fastest100:SetAsync(tostring(player.UserId), value)
		end
	end)
end

local function top(store, count, ascending)
	if not store then
		return {}
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(ascending, count)
	end)
	if not ok or not pages then
		return {}
	end
	local ok2, items = pcall(function()
		return pages:GetCurrentPage()
	end)
	if not ok2 then
		return {}
	end
	local out = {}
	for _, entry in ipairs(items) do
		table.insert(out, { UserId = tonumber(entry.key), Value = entry.value })
	end
	return out
end

function Leaderboards.TopDays(count)
	return top(mostDays, count or 10, false)
end

function Leaderboards.TopFastest(count)
	-- Fastest stored negative: flip back to seconds.
	local list = top(fastest100, count or 10, true)
	for _, entry in ipairs(list) do
		entry.Value = -entry.Value
	end
	return list
end

return Leaderboards
