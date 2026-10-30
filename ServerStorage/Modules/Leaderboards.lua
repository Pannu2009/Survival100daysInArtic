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
	local list = top(fastest100, count or 10, true)
	for _, entry in ipairs(list) do
		entry.Value = -entry.Value
	end
	return list
end
return Leaderboards
