-- CrossServer: MemoryStoreService, the scratchpad every
-- server in this place can read. Different from the
-- Treasury DataStore: DataStore is permanent (Flakes,
-- best days), MemoryStore is fast and temporary -- it
-- expires, so it is for live handoffs, not saves.
--
-- Wired use: Queue writes a party + seed, the game
-- server reads it back on start. That closes the
-- "lobby cannot generate terrain in another server"
-- gap: the lobby picks the seed, the game server
-- generates from it, instead of rolling its own.
local MemoryStoreService = game:GetService("MemoryStoreService")

local CrossServer = {}

local partyMap = nil
pcall(function()
	partyMap = MemoryStoreService:GetHashMap("ArcticParty")
end)

-- Save a party for a reserved server. Expires in 10
-- minutes, so a stale party can never resurrect.
function CrossServer.SaveParty(partyKey, data)
	if not partyMap then
		return false
	end
	local ok = pcall(function()
		partyMap:SetAsync(partyKey, data, 600)
	end)
	return ok
end

function CrossServer.GetParty(partyKey)
	if not partyMap then
		return nil
	end
	local ok, data = pcall(function()
		return partyMap:GetAsync(partyKey)
	end)
	if ok then
		return data
	end
	return nil
end

return CrossServer
