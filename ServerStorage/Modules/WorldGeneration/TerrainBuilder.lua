local TerrainBuilder = {}
local function paintHill(terrain, x, z, radius, height)
	local seed = math.abs(x * 31 + z * 17) % 100 / 100
	local angle = seed * math.pi * 2
	local dx, dz = math.cos(angle), math.sin(angle)
	local stops = { { -0.45, 0.7, 0.65 }, { 0, 1.0, 1.0 }, { 0.45, 0.7, 0.65 } }
	for _, stop in ipairs(stops) do
		local r = radius * stop[2]
		local top = height * stop[3]
		terrain:FillBall(Vector3.new(x + dx * stop[1] * radius, top - r, z + dz * stop[1] * radius), r, Enum.Material.Snow)
	end
end
local function paintPeak(terrain, x, z, radius, height)
	local seed = math.abs(x * 31 + z * 17) % 100 / 100
	local angle = seed * math.pi * 2
	local dx, dz = math.cos(angle), math.sin(angle)
	local px, pz = -dz, dx
	local ridge = { { -0.6, 0.55 }, { -0.3, 0.75 }, { 0, 0.95 }, { 0.3, 0.75 }, { 0.6, 0.55 } }
	for _, stop in ipairs(ridge) do
		local r = radius * stop[2]
		terrain:FillBall(Vector3.new(x + dx * stop[1] * radius, -radius * 0.25, z + dz * stop[1] * radius), r, Enum.Material.Rock)
	end
	for _, side in ipairs({ -0.4, 0.4 }) do
		terrain:FillBall(Vector3.new(x + px * side * radius, -radius * 0.25, z + pz * side * radius), radius * 0.6, Enum.Material.Rock)
	end
	terrain:FillBall(Vector3.new(x, height * 0.5, z), radius * 0.35, Enum.Material.Rock)
	terrain:FillBall(Vector3.new(x, height * 0.85, z), radius * 0.18, Enum.Material.Rock)
	terrain:FillBall(Vector3.new(x, height * 0.92, z), radius * 0.12, Enum.Material.Snow)
end
function TerrainBuilder.Build(layout)
	local terrain = workspace:WaitForChild("Terrain")
	terrain:Clear()
	local radius = layout.WorldRadius
	local diameter = radius * 2
	terrain:FillBlock(CFrame.new(0, -12, 0), Vector3.new(diameter, 24, diameter), Enum.Material.Snow)
	for _, hill in ipairs(layout.Hills or {}) do
		paintHill(terrain, hill.X, hill.Z, hill.Radius, hill.Height)
	end
	for _, peak in ipairs(layout.Peaks or {}) do
		paintPeak(terrain, peak.X, peak.Z, peak.Radius, peak.Height)
	end
	local mountain = layout.Mountain
	paintPeak(terrain, mountain.X, mountain.Z, mountain.Radius, mountain.Height)
	for _, pond in ipairs(layout.Ponds or {}) do
		terrain:FillBall(Vector3.new(pond.X, 0.6, pond.Z), pond.Radius, Enum.Material.Air)
		terrain:FillBlock(CFrame.new(pond.X, -4, pond.Z), Vector3.new(pond.Radius * 2, 4.4, pond.Radius * 2), Enum.Material.Snow)
		terrain:FillBlock(CFrame.new(pond.X, -1.15, pond.Z), Vector3.new(pond.Radius * 2, 1.5, pond.Radius * 2), Enum.Material.Glacier)
	end
	local lake = layout.Lake
	terrain:FillBall(Vector3.new(lake.X, -8, lake.Z), lake.Radius, Enum.Material.Air)
	terrain:FillBlock(CFrame.new(lake.X, -13, lake.Z), Vector3.new(lake.Radius * 2, 2, lake.Radius * 2), Enum.Material.Rock)
	terrain:FillBlock(CFrame.new(lake.X, -7.5, lake.Z), Vector3.new(lake.Radius * 2, 9, lake.Radius * 2), Enum.Material.Water)
	terrain:FillBlock(CFrame.new(lake.X, -2.5, lake.Z), Vector3.new(lake.Radius * 2, 1, lake.Radius * 2), Enum.Material.Glacier)
	local river = layout.River or {}
	for i = 1, #river - 1 do
		local a = river[i]
		local b = river[i + 1]
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt(Vector3.new(mid.X, -1, mid.Y), Vector3.new(b.X, -1, b.Y))
		terrain:FillBlock(cf, Vector3.new(34, 5, len + 8), Enum.Material.Ice)
		terrain:FillBlock(cf * CFrame.new(0, -3, 0), Vector3.new(22, 3, len), Enum.Material.Water)
	end
end
return TerrainBuilder
