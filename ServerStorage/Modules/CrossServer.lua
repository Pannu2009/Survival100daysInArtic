local MemoryStoreService = game:GetService("MemoryStoreService")
local CrossServer = {}
local partyMap = nil
pcall(function()
	partyMap = MemoryStoreService:GetHashMap("ArcticParty")
end)
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
