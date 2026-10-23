local TerrainBuilder = {}

function TerrainBuilder.Build(layout)
	local terrain = workspace:WaitForChild("Terrain")
	terrain:Clear()

	local radius = layout.WorldRadius
	local diameter = radius * 2
	terrain:FillBlock(CFrame.new(0, -12, 0), Vector3.new(diameter, 24, diameter), Enum.Material.Snow)

	local mountain = layout.Mountain
	terrain:FillBall(Vector3.new(mountain.X, 0, mountain.Z), mountain.Radius, Enum.Material.Rock)
	terrain:FillBall(Vector3.new(mountain.X, mountain.Height * 0.45, mountain.Z), mountain.Radius * 0.62, Enum.Material.Rock)
	terrain:FillBall(Vector3.new(mountain.X, mountain.Height * 0.8, mountain.Z), mountain.Radius * 0.34, Enum.Material.Snow)

	local lake = layout.Lake
	terrain:FillBall(Vector3.new(lake.X, -8, lake.Z), lake.Radius, Enum.Material.Air)
	-- Two layers: water below (surface at -3), a thin sheet of
	-- glacier ice on top (surface at -2, 1 thick). Breaking the
	-- ice carves the sheet and the water shows in the hole.
	terrain:FillBlock(CFrame.new(lake.X, -4.5, lake.Z), Vector3.new(lake.Radius * 2, 3, lake.Radius * 2), Enum.Material.Water)
	terrain:FillBlock(CFrame.new(lake.X, -2.5, lake.Z), Vector3.new(lake.Radius * 2, 1, lake.Radius * 2), Enum.Material.Glacier)
end

return TerrainBuilder
