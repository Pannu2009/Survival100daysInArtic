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
