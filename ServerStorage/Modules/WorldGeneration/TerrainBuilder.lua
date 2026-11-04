local ArcticLayout = require(script.Parent:WaitForChild("ArcticLayout"))
local TerrainBuilder = {}
local VOXEL = 4
local CHUNK = 128
local BASE_Y = -24
local WATER_Y = 0
local function hashSeed(s)
	local h = 0
	for i = 1, #s do
		h = (h * 31 + string.byte(s, i)) % 1000003
	end
	return h
end
local function smooth(t)
	if t <= 0 then return 0 end
	if t >= 1 then return 1 end
	return t * t * (3 - 2 * t)
end
local function falloff(dist, radius)
	if dist >= radius then return 0 end
	local t = 1 - (dist / radius)
	return t * t
end
local function dist2(x, z, px, pz)
	local dx = x - px
	local dz = z - pz
	return math.sqrt(dx * dx + dz * dz)
end
local function segDist(x, z, ax, az, bx, bz)
	local dx = bx - ax
	local dz = bz - az
	local len2 = dx * dx + dz * dz
	if len2 == 0 then return dist2(x, z, ax, az) end
	local t = ((x - ax) * dx + (z - az) * dz) / len2
	if t < 0 then t = 0 end
	if t > 1 then t = 1 end
	return dist2(x, z, ax + dx * t, az + dz * t)
end
local function riverDist(x, z, river)
	local best = 100000
	for i = 1, #river - 1 do
		local a = river[i]
		local b = river[i + 1]
		local d = segDist(x, z, a.X, a.Y, b.X, b.Y)
		if d < best then best = d end
	end
	return best
end
local function heightAt(x, z, layout, seed)
	local sx = seed % 1000
	local sz = math.floor(seed / 1000) % 1000
	local base = math.noise(x * 0.001 + sx, z * 0.001 + sz) * 9
	local ridge = (1 - math.abs(math.noise(x * 0.004 + sx, z * 0.004 + sz))) * 7
	local h = base + ridge
	for _, hill in ipairs(layout.Hills or {}) do
		h = h + hill.Height * falloff(dist2(x, z, hill.X, hill.Z), hill.Radius)
	end
	for _, peak in ipairs(layout.Peaks or {}) do
		h = h + peak.Height * falloff(dist2(x, z, peak.X, peak.Z), peak.Radius)
	end
	local m = layout.Mountain
	if m then
		h = h + m.Height * falloff(dist2(x, z, m.X, m.Z), m.Radius)
	end
	local r = layout.WorldRadius or 1850
	local d = math.sqrt(x * x + z * z)
	if d > r * 0.85 then
		local t = (d - r * 0.85) / (r * 0.15)
		h = h * (1 - smooth(t)) - t * 14
	end
	return h
end
local function columnInfo(x, z, layout, seed)
	local h = heightAt(x, z, layout, seed)
	local water = false
	local glacier = false
	local lake = layout.Lake
	if lake and dist2(x, z, lake.X, lake.Z) < lake.Radius then
		h = -9
		water = true
	end
	for _, pond in ipairs(layout.Ponds or {}) do
		if dist2(x, z, pond.X, pond.Z) < pond.Radius then
			h = 0
			glacier = true
		end
	end
	local riverPath = layout.RiverPath
	if riverPath and #riverPath > 0 then
		for _, seg in ipairs(riverPath) do
			if segDist(x, z, seg.AX, seg.AZ, seg.BX, seg.BZ) < seg.Width then
				h = -3
				water = true
				break
			end
		end
	else
		local river = layout.River or {}
		if #river > 1 then
			local d = riverDist(x, z, river)
			if d < 17 then
				h = -3
				water = true
			end
		end
	end
	local region = ArcticLayout.RegionAt(x, z)
	local biome = ArcticLayout.Biomes[region] or ArcticLayout.Biomes.StartingWilderness
	local top = biome.Top
	local sub = biome.Sub
	local neighbor = ArcticLayout.RegionAt(x + 80, z)
	if neighbor ~= region then
		local hash = math.abs(x * 31 + z * 17) % 100
		if hash < 30 then
			local nb = ArcticLayout.Biomes[neighbor]
			if nb then top = nb.Top end
		end
	end
	return h, water, glacier, top, sub
end
function TerrainBuilder.Build(layout)
	local terrain = workspace:WaitForChild("Terrain")
	terrain:Clear()
	local radius = layout.WorldRadius or 1850
	local seed = hashSeed(layout.SeedString or "arctic")
	local start = math.floor(-radius / VOXEL) * VOXEL
	local stop = math.ceil(radius / VOXEL) * VOXEL
	local chunkCount = 0
	local totalChunks = 0
	for cx = start, stop, CHUNK do
		for cz = start, stop, CHUNK do
			if math.sqrt(cx * cx + cz * cz) < radius + CHUNK then
				totalChunks = totalChunks + 1
			end
		end
	end
	for cx = start, stop, CHUNK do
		for cz = start, stop, CHUNK do
			if math.sqrt(cx * cx + cz * cz) < radius + CHUNK then
				chunkCount = chunkCount + 1
				local cols = {}
				local maxH = 0
				for vx = 0, (CHUNK / VOXEL) - 1 do
					cols[vx + 1] = {}
					for vz = 0, (CHUNK / VOXEL) - 1 do
						local x = cx + vx * VOXEL + VOXEL / 2
						local z = cz + vz * VOXEL + VOXEL / 2
						local h, water, glacier, top, sub = columnInfo(x, z, layout, seed)
						cols[vx + 1][vz + 1] = { h = h, water = water, glacier = glacier, top = top, sub = sub }
						if h > maxH then maxH = h end
					end
				end
				local topY = math.floor(maxH / VOXEL) * VOXEL
				if topY < 0 then topY = 0 end
				local yCount = math.floor((topY - BASE_Y) / VOXEL) + 1
				local materials = {}
				local occupancy = {}
				for vx = 1, CHUNK / VOXEL do
					materials[vx] = {}
					occupancy[vx] = {}
					for vy = 1, yCount do
						materials[vx][vy] = {}
						occupancy[vx][vy] = {}
						for vz = 1, CHUNK / VOXEL do
							local col = cols[vx][vz]
							local y = BASE_Y + (vy - 1) * VOXEL
							local mat = Enum.Material.Air
							local occ = 0
							if y <= col.h then
								occ = 1
								if col.h >= 60 then
									mat = Enum.Material.Rock
								elseif col.glacier then
									mat = Enum.Material.Glacier
								elseif y > col.h - VOXEL then
									mat = col.top or Enum.Material.Snow
								else
									mat = col.sub or Enum.Material.Snow
								end
							elseif col.water and y <= WATER_Y then
								occ = 1
								mat = Enum.Material.Water
							end
							materials[vx][vy][vz] = mat
							occupancy[vx][vy][vz] = occ
						end
					end
				end
				local region = Region3.new(Vector3.new(cx, BASE_Y, cz), Vector3.new(cx + CHUNK, topY + VOXEL, cz + CHUNK))
				terrain:WriteVoxels(region, VOXEL, materials, occupancy)
				if chunkCount % 20 == 0 then
					print("[Arctic] Terrain noise chunks " .. chunkCount .. "/" .. totalChunks)
				end
				task.wait()
			end
		end
	end
	print("[Arctic] Terrain noise build done, chunks " .. chunkCount)
end
TerrainBuilder.HeightAt = heightAt
return TerrainBuilder
