local TerrainBuilder = {}
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
		terrain:FillBall(Vector3.new(peak.X, 0, peak.Z), peak.Radius, Enum.Material.Rock)
		terrain:FillBall(Vector3.new(peak.X, peak.Height * 0.45, peak.Z), peak.Radius * 0.62, Enum.Material.Rock)
		terrain:FillBall(Vector3.new(peak.X, peak.Height * 0.8, peak.Z), peak.Radius * 0.34, Enum.Material.Snow)
	end
	local mountain = layout.Mountain
	terrain:FillBall(Vector3.new(mountain.X, 0, mountain.Z), mountain.Radius, Enum.Material.Rock)
	terrain:FillBall(Vector3.new(mountain.X, mountain.Height * 0.45, mountain.Z), mountain.Radius * 0.62, Enum.Material.Rock)
	terrain:FillBall(Vector3.new(mountain.X, mountain.Height * 0.8, mountain.Z), mountain.Radius * 0.34, Enum.Material.Snow)
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
