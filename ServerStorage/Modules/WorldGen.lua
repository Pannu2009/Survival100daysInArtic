local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local Seed = require(Modules:WaitForChild("Seed"))
local ArcticLayout = require(script.Parent:WaitForChild("ArcticLayout"))
local WorldGen = {}
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
	layout.WorldRadius = ArcticLayout.Config.WorldRadius
	layout.Spawn = { X = 0, Z = 0 }
	layout.Regions = ArcticLayout.Regions
	layout.Landmarks = ArcticLayout.Landmarks
	layout.River = ArcticLayout.Terrain.River
	local mountain = ArcticLayout.Terrain.Mountain
	layout.Mountain = {
		X = mountain.x,
		Z = mountain.z,
		Radius = mountain.r,
		Height = mountain.h,
	}
	local lake = ArcticLayout.Terrain.Lake
	layout.Lake = {
		X = lake.x,
		Z = lake.z,
		Radius = lake.r,
	}
	layout.Hills = {}
	for _, hill in ipairs(ArcticLayout.Terrain.Hills) do
		table.insert(layout.Hills, {
			X = hill.x, Z = hill.z,
			Radius = hill.r,
			Height = hill.h,
		})
	end
	layout.Peaks = {}
	for _, peak in ipairs(ArcticLayout.Terrain.Peaks) do
		table.insert(layout.Peaks, {
			X = peak.x, Z = peak.z,
			Radius = peak.r,
			Height = peak.h,
		})
	end
	local rng = master:Fork("ponds")
	layout.Ponds = {}
	for _ = 1, 10 do
		for _try = 1, 12 do
			local angle = rng:Next() * math.pi * 2
			local dist = rng:NextNumber(90, layout.WorldRadius - 80)
			local x = math.cos(angle) * dist
			local z = math.sin(angle) * dist
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
		local dist = rng:NextNumber(layout.WorldRadius + 130, layout.WorldRadius + 400)
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
		local angle = rng:Next() * math.pi * 2
		local dist = rng:NextNumber(30, 1600)
		local x = math.cos(angle) * dist
		local z = math.sin(angle) * dist
		local inLake = distanceTo(x, z, layout.Lake.X, layout.Lake.Z) < layout.Lake.Radius + 6
		local inMountain = distanceTo(x, z, layout.Mountain.X, layout.Mountain.Z) < layout.Mountain.Radius * 0.7
		if not inLake and not inMountain then
			table.insert(layout.Tufts, { X = x, Z = z, R = rng:Next() * math.pi })
		end
	end
	rng = master:Fork("forest")
	layout.Trees = {}
	for _, cluster in ipairs(ArcticLayout.Forests) do
		for _ = 1, cluster.count do
			local angle = rng:Next() * math.pi * 2
			local offset = math.sqrt(rng:Next()) * cluster.r
			local x = cluster.x + math.cos(angle) * offset
			local z = cluster.z + math.sin(angle) * offset
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
		local angle = rng:Next() * math.pi * 2
		local dist = rng:NextNumber(150, layout.WorldRadius)
		local x = math.cos(angle) * dist
		local z = math.sin(angle) * dist
		table.insert(layout.Cabins, { X = x, Z = z, Rotation = rng:NextNumber(0, 360) })
	end
	rng = master:Fork("coal")
	local coalAngle = rng:Next() * math.pi * 2
	local coalDist = rng:NextNumber(600, layout.WorldRadius)
	layout.CoalSpot = { X = math.cos(coalAngle) * coalDist, Z = math.sin(coalAngle) * coalDist }
	local toSpawnX = -layout.Mountain.X
	local toSpawnZ = -layout.Mountain.Z
	local toSpawnLength = math.sqrt(toSpawnX * toSpawnX + toSpawnZ * toSpawnZ)
	layout.YetiCave = {
		X = layout.Mountain.X + (toSpawnX / toSpawnLength) * layout.Mountain.Radius * 0.55,
		Z = layout.Mountain.Z + (toSpawnZ / toSpawnLength) * layout.Mountain.Radius * 0.55,
	}
	return layout
end
return WorldGen
