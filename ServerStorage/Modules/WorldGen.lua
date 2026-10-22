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
	local lakeX, lakeZ = place(rng, world.LakeMinDistance, world.LakeMaxDistance)
	layout.Lake = {
		X = lakeX,
		Z = lakeZ,
		Radius = rng:NextNumber(world.LakeMinRadius, world.LakeMaxRadius),
	}

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
