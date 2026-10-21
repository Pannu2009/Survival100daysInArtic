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
	terrain:FillBlock(CFrame.new(lake.X, -3, lake.Z), Vector3.new(lake.Radius * 2, 2, lake.Radius * 2), Enum.Material.Glacier)
end

return TerrainBuilder
