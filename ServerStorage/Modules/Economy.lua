-- Economy (SERVER ONLY, ServerStorage only -- never in
-- ReplicatedStorage, so clients can never require it).
--
-- The ONLY way coins move: Economy.Add(player, amount).
-- There is no RemoteEvent for adding coins, and no client
-- code path can grant them -- a client asking for coins
-- has nothing to call. Server systems (shelter loot, merchant
-- sales) call Add / Spend from server code only.
--
-- Coins live on the player's SurvivalPlayer record
-- (survival.Coins); this module is the gate, not a second
-- balance -- so the HUD's published Coins value always
-- matches what Add/Spend did, with no sync step to drift.
local RunService = game:GetService("RunService")

local Economy = {}

local getSurvival = nil

function Economy.Init(resolver)
	assert(RunService:IsServer(), "Economy is server-only")
	getSurvival = resolver
end

function Economy.Get(player)
	local survival = getSurvival and getSurvival(player) or nil
	return survival and (survival.Coins or 0) or 0
end

-- Add coins. Amount must be a finite positive number; a
-- negative amount is a spend -- use Spend for that, so a
-- sign typo cannot silently drain a player.
function Economy.Add(player, amount)
	assert(RunService:IsServer(), "Economy.Add is server-only")
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end
	if typeof(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return false
	end
	local survival = getSurvival and getSurvival(player) or nil
	if not survival then
		return false
	end
	survival.Coins = (survival.Coins or 0) + math.floor(amount)
	return true
end

-- Spend coins. Returns false (and changes nothing) if the
-- player cannot afford it -- callers must check the result.
function Economy.Spend(player, amount)
	assert(RunService:IsServer(), "Economy.Spend is server-only")
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end
	if typeof(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return false
	end
	local survival = getSurvival and getSurvival(player) or nil
	if not survival or (survival.Coins or 0) < amount then
		return false
	end
	survival.Coins = (survival.Coins or 0) - math.floor(amount)
	return true
end

function Economy.CanAfford(player, amount)
	return Economy.Get(player) >= (amount or 0)
end

return Economy
