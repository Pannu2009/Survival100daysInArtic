local L = {}
L.Config = { WorldRadius = 1850 }
L.Terrain = {
	Hills = {
		{ x = -1050, z = 0, r = 300, h = 38 },
		{ x = 250, z = 1250, r = 320, h = 42 },
		{ x = 1300, z = 650, r = 300, h = 34 },
		{ x = -100, z = -1350, r = 320, h = 40 },
		{ x = -850, z = -650, r = 220, h = 32 },
		{ x = -550, z = 950, r = 210, h = 28 },
		{ x = 1100, z = -500, r = 240, h = 36 },
		{ x = -1350, z = -800, r = 210, h = 30 },
	},
	Peaks = {
		{ x = 1050, z = -1250, r = 120, h = 115 },
		{ x = 1350, z = -850, r = 105, h = 95 },
		{ x = 1500, z = -300, r = 115, h = 105 },
		{ x = -1450, z = 950, r = 110, h = 90 },
		{ x = -1500, z = -700, r = 100, h = 85 },
	},
	Mountain = { x = 650, z = -900, r = 300, h = 270 },
	Lake = { x = -570, z = 120, r = 170 },
	River = {
		Vector2.new(-1450, 520),
		Vector2.new(-1150, 430),
		Vector2.new(-900, 280),
		Vector2.new(-650, 180),
		Vector2.new(-400, 80),
		Vector2.new(-180, -80),
		Vector2.new(80, -230),
		Vector2.new(350, -430),
		Vector2.new(620, -650),
	},
}
L.Forests = {
	{ x = -950, z = -650, r = 210, count = 90 },
	{ x = -1050, z = 350, r = 230, count = 110 },
	{ x = -550, z = 950, r = 210, count = 95 },
	{ x = 150, z = 800, r = 230, count = 105 },
	{ x = 100, z = -1050, r = 220, count = 90 },
	{ x = 1100, z = 650, r = 230, count = 100 },
	{ x = 1250, z = -500, r = 200, count = 85 },
	{ x = -1400, z = -950, r = 190, count = 75 },
	{ x = 650, z = -1350, r = 180, count = 70 },
}
L.Biomes = {
	StartingWilderness = { Top = Enum.Material.Snow, Sub = Enum.Material.Snow, TreeMult = 1.0, Decor = { "Boulder", "SnowMound" } },
	FrozenHighlands = { Top = Enum.Material.Rock, Sub = Enum.Material.Slate, TreeMult = 0.7, Decor = { "Boulder" } },
	GlacierFields = { Top = Enum.Material.Glacier, Sub = Enum.Material.Ice, TreeMult = 0.3, Decor = { "IceShard", "SnowMound" } },
	NorthernCoast = { Top = Enum.Material.Ice, Sub = Enum.Material.Glacier, TreeMult = 0.5, Decor = { "IceFloe", "Boulder" } },
	DeepTaiga = { Top = Enum.Material.Snow, Sub = Enum.Material.Ground, TreeMult = 1.5, Decor = { "DeadTree", "FallenLog", "Boulder" } },
	AbandonedZone = { Top = Enum.Material.Rock, Sub = Enum.Material.Ground, TreeMult = 0.6, Decor = { "Boulder", "SnowMound" } },
}
function L.RegionAt(x, z)
	local dCenter = math.sqrt(x * x + z * z)
	if dCenter > 1500 then
		return "NorthernCoast"
	end
	if math.sqrt((x - 1250) * (x - 1250) + (z - 650) * (z - 650)) < 450 then
		return "AbandonedZone"
	end
	if math.sqrt((x - 1150) * (x - 1150) + (z + 1450) * (z + 1450)) < 500 then
		return "GlacierFields"
	end
	for _, cluster in ipairs(L.Forests) do
		local dx = x - cluster.x
		local dz = z - cluster.z
		if dx * dx + dz * dz < cluster.r * cluster.r then
			return "DeepTaiga"
		end
	end
	if math.sqrt((x - 650) * (x - 650) + (z + 900) * (z + 900)) < 450 then
		return "FrozenHighlands"
	end
	for _, peak in ipairs(L.Terrain.Peaks) do
		local dx = x - peak.x
		local dz = z - peak.z
		if dx * dx + dz * dz < 450 * 450 then
			return "FrozenHighlands"
		end
	end
	return "StartingWilderness"
end
L.Landmarks = {
	{ Id = "ResearchOutpost", Name = "Northern Research Outpost", Region = "AbandonedZone", Position = Vector3.new(1250, 0, 650), Kind = "Outpost" },
	{ Id = "RadioTower", Name = "Highland Radio Tower", Region = "FrozenHighlands", Position = Vector3.new(1050, 0, -250), Kind = "Tower" },
	{ Id = "Shipwreck", Name = "Frozen Shipwreck", Region = "NorthernCoast", Position = Vector3.new(-1450, 0, 900), Kind = "Wreck" },
	{ Id = "MountainLookout", Name = "Mountain Lookout", Region = "FrozenHighlands", Position = Vector3.new(800, 0, -1050), Kind = "Lookout" },
	{ Id = "OldCabin", Name = "Abandoned Ranger Cabin", Region = "DeepTaiga", Position = Vector3.new(-900, 0, 500), Kind = "Cabin" },
	{ Id = "IceCave", Name = "Blue Ice Cave", Region = "GlacierFields", Position = Vector3.new(1150, 0, -1450), Kind = "Cave" },
}
return L
