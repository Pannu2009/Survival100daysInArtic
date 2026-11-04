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
local function blockedByWaterPeakRiver(layout, x, z)
	for _, pond in ipairs(layout.Ponds or {}) do
		if distanceTo(x, z, pond.X, pond.Z) < pond.Radius + 6 then
			return true
		end
	end
	for _, peak in ipairs(layout.Peaks or {}) do
		if distanceTo(x, z, peak.X, peak.Z) < peak.Radius * 0.8 then
			return true
		end
	end
	local river = layout.River or {}
	for i = 1, #river - 1 do
		local a = river[i]
		local b = river[i + 1]
		local dx = b.X - a.X
		local dz = b.Y - a.Y
		local len2 = dx * dx + dz * dz
		local t = 0
		if len2 > 0 then
			t = ((x - a.X) * dx + (z - a.Y) * dz) / len2
			if t < 0 then t = 0 end
			if t > 1 then t = 1 end
		end
		if distanceTo(x, z, a.X + dx * t, a.Y + dz * t) < 25 then
			return true
		end
	end
	return false
end
local function spotClear(layout, x, z)
	if distanceTo(x, z, layout.Lake.X, layout.Lake.Z) < layout.Lake.Radius + 40 then return false end
	if distanceTo(x, z, layout.Mountain.X, layout.Mountain.Z) < layout.Mountain.Radius * 0.8 then return false end
	if blockedByWaterPeakRiver(layout, x, z) then return false end
	for _, landmark in ipairs(layout.Landmarks or {}) do
		if landmark.Position and distanceTo(x, z, landmark.Position.X, landmark.Position.Z) < 80 then return false end
	end
	for _, cabin in ipairs(layout.Cabins or {}) do
		if distanceTo(x, z, cabin.X, cabin.Z) < 100 then return false end
	end
	return true
end
function WorldGen.Generate(seedString)
	local master = Seed.new(seedString)
	local world = Config.World
	local layout = {}
	layout.SeedString = master.String
	layout.WorldRadius = ArcticLayout.Config.WorldRadius
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
		if not inLake and not inMountain and not blockedByWaterPeakRiver(layout, x, z) then
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
			local inLandmark = false
			for _, landmark in ipairs(layout.Landmarks or {}) do
				if landmark.Position and distanceTo(x, z, landmark.Position.X, landmark.Position.Z) < 40 then
					inLandmark = true
					break
				end
			end
			if not inLake and not inMountain and not inLandmark and not blockedByWaterPeakRiver(layout, x, z) then
				local region = ArcticLayout.RegionAt(x, z)
				local biome = ArcticLayout.Biomes[region] or ArcticLayout.Biomes.StartingWilderness
				if rng:Next() <= biome.TreeMult then
					local heightScale = rng:NextNumber(0.7, 1.6)
					local thicknessScale = rng:NextNumber(0.6, 1.8)
					if region == "DeepTaiga" then
						heightScale = heightScale * 1.3
					elseif region == "GlacierFields" then
						heightScale = heightScale * 0.7
					end
					if rng:Next() < 0.1 then
						heightScale = rng:NextNumber(1.7, 2.1)
						thicknessScale = rng:NextNumber(0.4, 0.55)
					end
					table.insert(layout.Trees, { X = x, Z = z, H = heightScale, T = thicknessScale })
				end
			end
		end
	end
	rng = master:Fork("cabins")
	layout.Cabins = {}
	local cabinCount = rng:NextInteger(world.CabinsMin, world.CabinsMax)
	for _ = 1, cabinCount do
		for _try = 1, 20 do
			local angle = rng:Next() * math.pi * 2
			local dist = rng:NextNumber(150, layout.WorldRadius)
			local x = math.cos(angle) * dist
			local z = math.sin(angle) * dist
			if spotClear(layout, x, z) then
				table.insert(layout.Cabins, { X = x, Z = z, Rotation = rng:NextNumber(0, 360) })
				break
			end
		end
	end
	rng = master:Fork("coal")
	layout.CoalSpot = { X = 0, Z = 1200 }
	for _try = 1, 50 do
		local coalAngle = rng:Next() * math.pi * 2
		local coalDist = rng:NextNumber(600, layout.WorldRadius)
		local x = math.cos(coalAngle) * coalDist
		local z = math.sin(coalAngle) * coalDist
		if spotClear(layout, x, z) then
			layout.CoalSpot = { X = x, Z = z }
			break
		end
	end
	local toSpawnX = -layout.Mountain.X
	local toSpawnZ = -layout.Mountain.Z
	local toSpawnLength = math.sqrt(toSpawnX * toSpawnX + toSpawnZ * toSpawnZ)
	layout.YetiCave = {
		X = layout.Mountain.X + (toSpawnX / toSpawnLength) * layout.Mountain.Radius * 0.55,
		Z = layout.Mountain.Z + (toSpawnZ / toSpawnLength) * layout.Mountain.Radius * 0.55,
	}
	local function catmull(p0, p1, p2, p3, t)
		local t2 = t * t
		local t3 = t2 * t
		return Vector2.new(
			0.5 * ((2 * p1.X) + (-p0.X + p2.X) * t + (2 * p0.X - 5 * p1.X + 4 * p2.X - p3.X) * t2 + (-p0.X + 3 * p1.X - 3 * p2.X + p3.X) * t3),
			0.5 * ((2 * p1.Y) + (-p0.Y + p2.Y) * t + (2 * p0.Y - 5 * p1.Y + 4 * p2.Y - p3.Y) * t2 + (-p0.Y + 3 * p1.Y - 3 * p2.Y + p3.Y) * t3)
		)
	end
	layout.RiverPath = {}
	do
		local river = layout.River or {}
		local points = {}
		for i = 1, #river - 1 do
			local p0 = river[math.max(i - 1, 1)]
			local p1 = river[i]
			local p2 = river[i + 1]
			local p3 = river[math.min(i + 2, #river)]
			for _, t in ipairs({ 0, 0.5 }) do
				table.insert(points, catmull(p0, p1, p2, p3, t))
			end
		end
		if #river > 0 then
			table.insert(points, river[#river])
		end
		for i = 1, #points - 1 do
			local a = points[i]
			local b = points[i + 1]
			table.insert(layout.RiverPath, {
				AX = a.X, AZ = a.Y, BX = b.X, BZ = b.Y,
				Width = 17 * (0.85 + 0.3 * math.sin(i * 0.7)),
			})
		end
	end
	rng = master:Fork("decor")
	layout.Decor = {}
	local function decorOk(x, z)
		if distanceTo(x, z, layout.Lake.X, layout.Lake.Z) < layout.Lake.Radius + 10 then return false end
		if distanceTo(x, z, layout.Mountain.X, layout.Mountain.Z) < layout.Mountain.Radius * 0.7 then return false end
		for _, landmark in ipairs(layout.Landmarks or {}) do
			if landmark.Position and distanceTo(x, z, landmark.Position.X, landmark.Position.Z) < 40 then return false end
		end
		for _, cabin in ipairs(layout.Cabins or {}) do
			if distanceTo(x, z, cabin.X, cabin.Z) < 20 then return false end
		end
		for _, pond in ipairs(layout.Ponds or {}) do
			if distanceTo(x, z, pond.X, pond.Z) < pond.Radius + 5 then return false end
		end
		local river = layout.River or {}
		for i = 1, #river - 1 do
			local a = river[i]
			local b = river[i + 1]
			local dx = b.X - a.X
			local dz = b.Y - a.Y
			local len2 = dx * dx + dz * dz
			local t = 0
			if len2 > 0 then
				t = ((x - a.X) * dx + (z - a.Y) * dz) / len2
				if t < 0 then t = 0 end
				if t > 1 then t = 1 end
			end
			local px = a.X + dx * t
			local pz = a.Y + dz * t
			if distanceTo(x, z, px, pz) < 25 then return false end
		end
		return true
	end
	local decorSpecs = {
		{ Kind = "Boulder", Count = 120, Region = nil },
		{ Kind = "SnowMound", Count = 80, Region = nil },
		{ Kind = "IceShard", Count = 40, Region = "GlacierFields" },
		{ Kind = "DeadTree", Count = 50, Region = "DeepTaiga" },
		{ Kind = "FallenLog", Count = 40, Region = "DeepTaiga" },
		{ Kind = "IceFloe", Count = 30, Region = "NorthernCoast" },
	}
	for _, spec in ipairs(decorSpecs) do
		for _ = 1, spec.Count do
			for _try = 1, 12 do
				local angle = rng:Next() * math.pi * 2
				local dist = rng:NextNumber(90, layout.WorldRadius - 80)
				local x = math.cos(angle) * dist
				local z = math.sin(angle) * dist
				local region = ArcticLayout.RegionAt(x, z)
				if (spec.Region == nil or region == spec.Region) and decorOk(x, z) then
					table.insert(layout.Decor, {
						Kind = spec.Kind, X = x, Z = z,
						Scale = rng:NextNumber(0.7, 1.8),
						Rot = rng:NextNumber(0, 360),
					})
					break
				end
			end
		end
	end
	return layout
end
return WorldGen
