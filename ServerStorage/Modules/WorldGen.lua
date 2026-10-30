local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local Seed = require(Modules:WaitForChild("Seed"))
local WorldGen = {}
local function place(rng, minDistance, maxDistance)
	local angle = rng:Next() * math.pi * 2
	local distance = rng:NextNumber(minDistance, maxDistance)
	local x = math.cos(angle) * distance
	local z = math.sin(angle) * distance
	local magnitude = math.sqrt(x * x + z * z)
	if magnitude > Config.World.Radius then
		x *= Config.World.Radius / magnitude
		z *= Config.World.Radius / magnitude
	end
	return x, z
end
local function distanceTo(x1, z1, x2, z2)
	local dx = x1 - x2
	local dz = z1 - z2
	return math.sqrt(dx * dx + dz * dz)
end
function WorldGen.Generate(seedString)
	local master = Seed.new(seedString)
	local world = Config.World
	local layout = {}
	layout.SeedString = master.String
	layout.WorldRadius = world.Radius
	layout.Spawn = { X = 0, Z = 0 }
	local rng = master:Fork("mountain")
	local mountainX, mountainZ = place(rng, world.MountainMinDistance, world.MountainMaxDistance)
	layout.Mountain = {
		X = mountainX,
		Z = mountainZ,
		Radius = rng:NextNumber(world.MountainMinRadius, world.MountainMaxRadius),
		Height = rng:NextNumber(world.MountainMinHeight, world.MountainMaxHeight),
	}
	rng = master:Fork("lake")
	local lakeRadius = rng:NextNumber(world.LakeMinRadius, world.LakeMaxRadius)
	local lakeX, lakeZ = place(rng, world.LakeMinDistance, world.LakeMaxDistance)
	for _try = 1, 12 do
		if distanceTo(lakeX, lakeZ, layout.Mountain.X, layout.Mountain.Z)
			> layout.Mountain.Radius * 0.75 + lakeRadius + 30
		then
			break
		end
		lakeX, lakeZ = place(rng, world.LakeMinDistance, world.LakeMaxDistance)
	end
	layout.Lake = {
		X = lakeX,
		Z = lakeZ,
		Radius = lakeRadius,
	}
	rng = master:Fork("hills")
	layout.Hills = {}
	layout.BroadHills = {}
	local function clearOfLandmarks(x, z, margin)
		if distanceTo(x, z, layout.Lake.X, layout.Lake.Z) < layout.Lake.Radius + margin then
			return false
		end
		if distanceTo(x, z, layout.Mountain.X, layout.Mountain.Z) < layout.Mountain.Radius * 0.85 + margin then
			return false
		end
		if distanceTo(x, z, 0, 0) < 85 then
			return false
		end
		return true
	end
	for _ = 1, world.Hills do
		for _try = 1, 10 do
			local x, z = place(rng, 100, world.Radius - 60)
			if clearOfLandmarks(x, z, 55) then
				table.insert(layout.Hills, {
					X = x, Z = z,
					Radius = rng:NextNumber(world.HillMinRadius, world.HillMaxRadius),
					Height = rng:NextNumber(world.HillMinHeight, world.HillMaxHeight),
				})
				break
			end
		end
	end
	for _ = 1, world.BroadHills do
		local x, z = place(rng, 150, world.Radius - 150)
		table.insert(layout.BroadHills, {
			X = x, Z = z,
			Radius = rng:NextNumber(260, 340),
			Height = rng:NextNumber(3, 4.5),
		})
	end
	rng = master:Fork("peaks")
	layout.Peaks = {}
	for _ = 1, world.Peaks do
		for _try = 1, 12 do
			local x, z = place(rng, 220, world.Radius - 70)
			local ok = clearOfLandmarks(x, z, 60) and distanceTo(x, z, 0, 0) > 170
			if ok then
				for _, peak in ipairs(layout.Peaks) do
					if distanceTo(x, z, peak.X, peak.Z) < 190 then
						ok = false
						break
					end
				end
			end
			if ok then
				table.insert(layout.Peaks, {
					X = x, Z = z,
					Radius = rng:NextNumber(world.PeakMinRadius, world.PeakMaxRadius),
					Height = rng:NextNumber(world.PeakMinHeight, world.PeakMaxHeight),
				})
				break
			end
		end
	end
	rng = master:Fork("ponds")
	layout.Ponds = {}
	for _ = 1, 10 do
		for _try = 1, 12 do
			local x, z = place(rng, 90, world.Radius - 80)
			local ok = distanceTo(x, z, 0, 0) > 55
				and distanceTo(x, z, layout.Lake.X, layout.Lake.Z) > layout.Lake.Radius + 40
				and distanceTo(x, z, layout.Mountain.X, layout.Mountain.Z) > layout.Mountain.Radius * 0.8
			if ok then
				for _, pond in ipairs(layout.Ponds) do
					if distanceTo(x, z, pond.X, pond.Z) < 48 then
						ok = false
						break
					end
				end
			end
			if ok then
				table.insert(layout.Ponds, { X = x, Z = z, Radius = rng:NextNumber(7, 13) })
				break
			end
		end
	end
	rng = master:Fork("horizon")
	layout.Horizon = {}
	for i = 1, 14 do
		local angle = (i / 14) * math.pi * 2 + rng:NextNumber(-0.14, 0.14)
		local dist = rng:NextNumber(1030, 1200)
		table.insert(layout.Horizon, {
			X = math.cos(angle) * dist,
			Z = math.sin(angle) * dist,
			Width = rng:NextNumber(150, 280),
			Height = rng:NextNumber(90, 200),
			Rot = rng:Next() * math.pi,
		})
	end
	rng = master:Fork("tufts")
	layout.Tufts = {}
	for _ = 1, world.Tufts do
		local x, z = place(rng, 30, 720)
		local inLake = distanceTo(x, z, layout.Lake.X, layout.Lake.Z) < layout.Lake.Radius + 6
		local inMountain = distanceTo(x, z, layout.Mountain.X, layout.Mountain.Z) < layout.Mountain.Radius * 0.7
		if not inLake and not inMountain then
			table.insert(layout.Tufts, { X = x, Z = z, R = rng:Next() * math.pi })
		end
	end
	rng = master:Fork("forest")
	layout.Trees = {}
	for _ = 1, world.ForestClusters do
		local clusterX, clusterZ = place(rng, 120, world.Radius)
		for _ = 1, world.TreesPerCluster do
			local angle = rng:Next() * math.pi * 2
			local offset = math.sqrt(rng:Next()) * world.ClusterRadius
			local x = clusterX + math.cos(angle) * offset
			local z = clusterZ + math.sin(angle) * offset
			local inLake = distanceTo(x, z, layout.Lake.X, layout.Lake.Z) < layout.Lake.Radius
			local inMountain = distanceTo(x, z, layout.Mountain.X, layout.Mountain.Z) < layout.Mountain.Radius * 0.75
			if not inLake and not inMountain then
				local heightScale = rng:NextNumber(0.7, 1.6)
				local thicknessScale = rng:NextNumber(0.6, 1.8)
				if rng:Next() < 0.1 then
					heightScale = rng:NextNumber(1.7, 2.1)
					thicknessScale = rng:NextNumber(0.4, 0.55)
				end
				table.insert(layout.Trees, { X = x, Z = z, H = heightScale, T = thicknessScale })
			end
		end
	end
	rng = master:Fork("cabins")
	layout.Cabins = {}
	local cabinCount = rng:NextInteger(world.CabinsMin, world.CabinsMax)
	for _ = 1, cabinCount do
		local x, z = place(rng, 150, world.Radius)
		table.insert(layout.Cabins, { X = x, Z = z, Rotation = rng:NextNumber(0, 360) })
	end
	rng = master:Fork("coal")
	local coalX, coalZ = place(rng, 600, world.Radius)
	layout.CoalSpot = { X = coalX, Z = coalZ }
	local mountain = layout.Mountain
	local toSpawnX = -mountain.X
	local toSpawnZ = -mountain.Z
	local toSpawnLength = math.sqrt(toSpawnX * toSpawnX + toSpawnZ * toSpawnZ)
	layout.YetiCave = {
		X = mountain.X + (toSpawnX / toSpawnLength) * mountain.Radius * 0.55,
		Z = mountain.Z + (toSpawnZ / toSpawnLength) * mountain.Radius * 0.55,
	}
	return layout
end
return WorldGen
