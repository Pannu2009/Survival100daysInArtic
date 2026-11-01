local TerrainBuilder = {}
local function paintPeak(terrain, x, z, radius, height)
	terrain:FillBall(Vector3.new(x, 0, z), radius, Enum.Material.Rock)
	local seed = math.abs(x * 31 + z * 17) % 100 / 100
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2 + seed * 0.9
		local dist = radius * (0.55 + seed * 0.2)
		local shoulderRadius = radius * (0.3 + ((i * 13 + seed * 50) % 10) / 100)
		terrain:FillBall(Vector3.new(x + math.cos(angle) * dist, height * 0.28, z + math.sin(angle) * dist), shoulderRadius, Enum.Material.Rock)
	end
	terrain:FillBall(Vector3.new(x, height * 0.45, z), radius * 0.62, Enum.Material.Rock)
	terrain:FillBall(Vector3.new(x, height * 0.92, z), radius * 0.24, Enum.Material.Rock)
	terrain:FillBall(Vector3.new(x, height * 0.98, z), radius * 0.18, Enum.Material.Snow)
end
function TerrainBuilder.Build(layout)
	local terrain = workspace:WaitForChild("Terrain")
	terrain:Clear()
	local radius = layout.WorldRadius
	local diameter = radius * 2
	terrain:FillBlock(CFrame.new(0, -12, 0), Vector3.new(diameter, 24, diameter), Enum.Material.Snow)
	for _, hill in ipairs(layout.BroadHills or {}) do
		terrain:FillBall(Vector3.new(hill.X, -(hill.Radius - hill.Height), hill.Z), hill.Radius, Enum.Material.Snow)
	end
	for _, hill in ipairs(layout.Hills or {}) do
		terrain:FillBall(Vector3.new(hill.X, -(hill.Radius - hill.Height), hill.Z), hill.Radius, Enum.Material.Snow)
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
