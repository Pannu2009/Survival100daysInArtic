local TerrainBuilder = {}

function TerrainBuilder.Build(layout)
	local terrain = workspace:WaitForChild("Terrain")
	terrain:Clear()

	local radius = layout.WorldRadius
	local diameter = radius * 2
	terrain:FillBlock(CFrame.new(0, -12, 0), Vector3.new(diameter, 24, diameter), Enum.Material.Snow)

	-- Rolling ground first: broad swells, then hill domes (a
	-- wide flat ball reads as a smooth hill in voxel terrain).
	for _, hill in ipairs(layout.BroadHills or {}) do
		terrain:FillBall(Vector3.new(hill.X, -(hill.Radius - hill.Height), hill.Z), hill.Radius, Enum.Material.Snow)
	end
	for _, hill in ipairs(layout.Hills or {}) do
		terrain:FillBall(Vector3.new(hill.X, -(hill.Radius - hill.Height), hill.Z), hill.Radius, Enum.Material.Snow)
	end

	-- Small mountains: the big one's recipe, scaled down.
	for _, peak in ipairs(layout.Peaks or {}) do
		terrain:FillBall(Vector3.new(peak.X, 0, peak.Z), peak.Radius, Enum.Material.Rock)
		terrain:FillBall(Vector3.new(peak.X, peak.Height * 0.45, peak.Z), peak.Radius * 0.62, Enum.Material.Rock)
		terrain:FillBall(Vector3.new(peak.X, peak.Height * 0.8, peak.Z), peak.Radius * 0.34, Enum.Material.Snow)
	end

	-- Frozen ponds: a shallow carved bowl, plugged with snow,
	-- iced over with a glacier sheet just below the snow line.
	-- Decoration (and slippery sled ice) -- only the lake
	-- cracks for fishing.
	for _, pond in ipairs(layout.Ponds or {}) do
		terrain:FillBall(Vector3.new(pond.X, 0.6, pond.Z), pond.Radius, Enum.Material.Air)
		terrain:FillBlock(CFrame.new(pond.X, -4, pond.Z), Vector3.new(pond.Radius * 2, 4.4, pond.Radius * 2), Enum.Material.Snow)
		terrain:FillBlock(CFrame.new(pond.X, -1.15, pond.Z), Vector3.new(pond.Radius * 2, 1.5, pond.Radius * 2), Enum.Material.Glacier)
	end

	local mountain = layout.Mountain
	terrain:FillBall(Vector3.new(mountain.X, 0, mountain.Z), mountain.Radius, Enum.Material.Rock)
	terrain:FillBall(Vector3.new(mountain.X, mountain.Height * 0.45, mountain.Z), mountain.Radius * 0.62, Enum.Material.Rock)
	terrain:FillBall(Vector3.new(mountain.X, mountain.Height * 0.8, mountain.Z), mountain.Radius * 0.34, Enum.Material.Snow)

	local lake = layout.Lake
	terrain:FillBall(Vector3.new(lake.X, -8, lake.Z), lake.Radius, Enum.Material.Air)
	-- Three layers: a rock lakebed at the bottom (-10 to -8), a
	-- proper body of water over it (5 thick, surface at -3), and
	-- a thin sheet of glacier ice on top (surface at -2, 1
	-- thick). Breaking the ice carves the sheet and the water
	-- shows in the hole. (Before, under the water was the carved
	-- air bowl -- straight through to the void.)
	terrain:FillBlock(CFrame.new(lake.X, -13, lake.Z), Vector3.new(lake.Radius * 2, 2, lake.Radius * 2), Enum.Material.Rock)
	terrain:FillBlock(CFrame.new(lake.X, -7.5, lake.Z), Vector3.new(lake.Radius * 2, 9, lake.Radius * 2), Enum.Material.Water)
	terrain:FillBlock(CFrame.new(lake.X, -2.5, lake.Z), Vector3.new(lake.Radius * 2, 1, lake.Radius * 2), Enum.Material.Glacier)
end

return TerrainBuilder
