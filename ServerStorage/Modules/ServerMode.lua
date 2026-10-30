local RunService = game:GetService("RunService")
local ServerMode = {}
function ServerMode.ModeFromJoinData(joinData)
	if joinData and joinData.TeleportData then
		local data = joinData.TeleportData
		if data.mode == "lobby" or data.mode == "game" then
			return data.mode == "lobby" and "Lobby" or "Game"
		end
	end
	return nil
end
function ServerMode.Detect()
	if RunService:IsStudio() then
		return "Game"
	end
	if game.PrivateServerId ~= "" then
		return "Game"
	end
	return "Lobby"
end
function ServerMode.IsGame()
	return ServerMode.Detect() == "Game"
end
function ServerMode.IsLobby()
	return ServerMode.Detect() == "Lobby"
end
return ServerMode
