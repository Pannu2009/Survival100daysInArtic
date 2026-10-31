local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local Perception = {}
local W = Config.Wolves
function Perception:_nearestPlayer(position, maxDist)
	local best, bestDist = nil, maxDist
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local survival = self.Gameplay._survivals[player]
			if not (survival and survival.Dead) then
				local d = (root.Position - position).Magnitude
				if d < bestDist then
					best, bestDist = player, d
				end
			end
		end
	end
	return best, bestDist
end
function Perception:_aggroRange(wolf, isNight)
	local base = isNight and W.AggroRangeNight or W.AggroRangeDay
	local weather = self.Gameplay.Temperature and self.Gameplay.Temperature:GetWeather()
	if weather == "Blizzard" then base = base * 0.8 end
	if wolf.Personality == "Aggressive" then return base * 1.25 end
	if wolf.Personality == "Cautious" then return base * 0.75 end
	return base
end
function Perception:_waryRange(wolf)
	local range = W.WaryRange
	if wolf.Personality == "Cautious" then range = range * 1.25 end
	if wolf.Personality == "Aggressive" then range = range * 0.85 end
	local weather = self.Gameplay.Temperature and self.Gameplay.Temperature:GetWeather()
	if weather == "Blizzard" then range = range * 0.8 end
	return range
end
function Perception:_fleeFrac(wolf)
	if wolf.Personality == "Cautious" then return W.FleeHealthFrac * 1.5 end
	if wolf.Personality == "Aggressive" then return W.FleeHealthFrac * 0.6 end
	return W.FleeHealthFrac
end
function Perception:_waryTimeout(wolf)
	if wolf.Personality == "Cautious" then return 12 end
	if wolf.Personality == "Aggressive" then return 5 end
	return 8
end
function Perception:_canSee(wolf, targetPos, maxDist)
	local pos = wolf.Root.Position
	local toTarget = targetPos - pos
	local dist = toTarget.Magnitude
	if dist > maxDist then return false end
	if dist <= (W.CloseSenseRange or 8) then return true end
	local flat = Vector3.new(toTarget.X, 0, toTarget.Z)
	if flat.Magnitude < 0.1 then return true end
	local facing = Vector3.new(-math.sin(wolf.Yaw), 0, -math.cos(wolf.Yaw))
	local cosHalf = math.cos(math.rad((W.VisionFovDegrees or 120) / 2))
	if facing:Dot(flat.Unit) < cosHalf then return false end
	local origin = pos + Vector3.new(0, 1.5, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { wolf.Model }
	params.IgnoreWater = true
	local hit = workspace:Raycast(origin, toTarget, params)
	if hit and hit.Distance < dist - 2.5 then return false end
	return true
end
function Perception:_nearestVisiblePlayer(wolf, maxDist)
	local pos = wolf.Root.Position
	local best, bestDist = nil, maxDist
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local survival = self.Gameplay._survivals[player]
			if not (survival and survival.Dead) then
				local d = (root.Position - pos).Magnitude
				if d < bestDist and self:_canSee(wolf, root.Position, maxDist) then
					best, bestDist = player, d
				end
			end
		end
	end
	return best, bestDist
end
function Perception:_nearestSprintingPlayer(wolf, maxDist)
	local pos = wolf.Root.Position
	local best, bestDist = nil, maxDist
	local sprinting = self.Gameplay._sprinting or {}
	for _, player in ipairs(Players:GetPlayers()) do
		if sprinting[player] then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				local survival = self.Gameplay._survivals[player]
				if not (survival and survival.Dead) then
					local d = (root.Position - pos).Magnitude
					if d < bestDist then best, bestDist = player, d end
				end
			end
		end
	end
	return best, bestDist
end
function Perception:_remember(wolf, pos)
	wolf.LastSeenPos = pos
	wolf.LastSeenUntil = os.clock() + (W.MemorySeconds or 8)
end
function Perception:_shareThreat(wolf, player)
	if not wolf.PackId or not player then return end
	local now = os.clock()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	for _, other in ipairs(self.Wolves) do
		if other ~= wolf and other.PackId == wolf.PackId and not other.Owner and other.Health > 0
			and (other.State == "Roam" or other.State == "Wary")
			and (other.Root.Position - wolf.Root.Position).Magnitude <= (W.SharedThreatRange or 40)
		then
			other.State = "Wary"
			other.TargetPlayer = player
			other.WarySince = now
			other.NoisePos = root.Position
			other.NoiseUntil = now + (W.MemorySeconds or 8)
			self:_remember(other, root.Position)
		end
	end
end
return Perception
