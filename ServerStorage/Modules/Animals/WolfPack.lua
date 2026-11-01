local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local Pack = {}
local W = Config.Wolves
function Pack:_packSpawnPosition()
	local world = self.Gameplay.World
	local layout = world and world.Layout
	local radius = (layout and layout.WorldRadius) or 500
	local lake = layout and layout.Lake
	local function clearOf(x, z)
		if lake then
			local dx = x - lake.X
			local dz = z - lake.Z
			if dx * dx + dz * dz < (lake.Radius + 25) * (lake.Radius + 25) then
				return false
			end
		end
		for _, pack in pairs(self._packs) do
			if pack.Home then
				local dx = x - pack.Home.X
				local dz = z - pack.Home.Z
				if dx * dx + dz * dz < W.PackSeparation * W.PackSeparation then
					return false
				end
			end
		end
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				local dx = x - root.Position.X
				local dz = z - root.Position.Z
				if dx * dx + dz * dz < 140 * 140 then
					return false
				end
			end
		end
		return true
	end
	for _ = 1, 24 do
		local angle = math.random() * math.pi * 2
		local dist = math.random(120, math.max(140, radius - 40))
		local x = math.cos(angle) * dist
		local z = math.sin(angle) * dist
		if clearOf(x, z) then
			return Vector3.new(x, 0, z)
		end
	end
	local angle = math.random() * math.pi * 2
	return Vector3.new(math.cos(angle) * (radius - 30), 0, math.sin(angle) * (radius - 30))
end
function Pack:_spawnPack()
	if not self.Template then
		return 0
	end
	local room = math.min(W.MaxAlive - #self.Wolves, self:_population().Total - self:_wildCount())
	if room <= 0 then
		return 0
	end
	self._nextPackId += 1
	local packId = self._nextPackId
	local home = self:_packSpawnPosition()
	local pop = self:_population()
	local count = math.min(math.random(pop.PackMin, pop.PackMax), room)
	local pack = { Id = packId, Home = home, RespawnAt = nil }
	self._packs[packId] = pack
	local spawned = 0
	for i = 1, count do
		local record = self:_buildWolf()
		if not record then
			if spawned == 0 then
				self._packs[packId] = nil
			end
			return spawned
		end
		spawned += 1
		record.PackId = packId
		record.Home = home
		record.PackIndex = i
		if i == 1 and count >= 2 then
			record.PackRole = "Leader"
			record.Leader = true
			record.Level = (record.Level or 1) + 1
			record.MaxHealth = math.floor((record.MaxHealth or W.MaxHealth) * 1.6)
			record.Health = record.MaxHealth
			record.BiteDamage = math.floor((record.BiteDamage or W.BiteDamage) * W.LeaderDamageMult)
		end
		if not record.PackRole then
			if count == 1 then
				record.PackRole = "Scout"
			else
				local roles = { "Scout", "Guard", "Chaser", "Flanker" }
				record.PackRole = roles[((i - 2) % 4) + 1]
			end
		end
		record.Model:SetAttribute("Leader", record.Leader)
		record.Model:SetAttribute("PackRole", record.PackRole or "")
		local angle = (i / count) * math.pi * 2
		self:_placeAt(record, home + Vector3.new(math.cos(angle) * 4, 0, math.sin(angle) * 4))
		table.insert(self.Wolves, record)
	end
	return spawned
end
function Pack:_packBonusMult(wolf)
	local mates = 0
	for _, other in ipairs(self.Wolves) do
		if other ~= wolf and other.Health > 0 then
			local same = false
			if wolf.Owner then
				same = other.Owner == wolf.Owner
			elseif other.PackId and wolf.PackId then
				same = other.PackId == wolf.PackId
			end
			if same and (other.Root.Position - wolf.Root.Position).Magnitude <= W.PackBonusRange then
				mates += 1
			end
		end
	end
	return 1 + math.min(W.PackBonusCap, mates * W.PackBonusPerMate)
end
return Pack
