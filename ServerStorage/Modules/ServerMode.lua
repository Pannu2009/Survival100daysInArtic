-- ServerMode: ONE place, TWO roles (single-place lobby + game).
--
-- A server is a GAME server if it is a private server, and a
-- LOBBY server if it is a public server:
--   Game  -> game.PrivateServerId ~= ""
--   Lobby -> game.PrivateServerId == ""
--
-- Why this works: a player joining normally lands in a public
-- (lobby) server. The lobby's queue (built separately) reserves
-- a private server of this SAME place and teleports the party
-- there -- that server sees a non-empty PrivateServerId and
-- runs the game. No second PlaceId, no cross-place config.
--
-- Studio override: Studio playtests have no private server
-- ID, so Studio always runs as GAME -- Ajay's Studio tests
-- are game tests. A lobby test in Studio needs an explicit
-- override (see ModeFromJoinData, used by future lobby code).
--
-- The mode is published as ReplicatedStorage attribute
-- "ServerMode" by SurvivalServer, so the client can branch
-- on it too (lobby client skips the survival HUD).
local RunService = game:GetService("RunService")

local ServerMode = {}

-- JoinData override: if a player arrived with TeleportData
-- carrying mode="lobby" or mode="game", that wins. The lobby
-- queue should pass mode="game" in TeleportData when it
-- teleports a party to a private server, as a belt-and-braces
-- check on top of PrivateServerId.
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
