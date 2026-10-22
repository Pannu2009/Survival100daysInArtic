local Config = {}

Config.DayCycle = {
	DayLength = 180,
	NightLength = 120,
	StartPhase = "Day",
}

Config.Multiplier = {
	Base = 1,
	MaxBaseGame = 10,
	MaxAbsolute = 20,
}

Config.Survival = {
	MaxHealth = 100,
	MaxWarmth = 100,
	MaxHunger = 50,
	HealthRegenPerSecond = 0.05,
	FreezingHealthDrain = 1.5,
	StarvingHealthDrain = 1.0,
	HungerDrainPerSecond = 0.09,
	SprintHungerMultiplier = 2,
	WalkSpeed = 16,
	SprintSpeed = 22,
}

Config.Temperature = {
	DayAmbientC = -12,
	NightAmbientC = -24,
	StormDropC = -8,
	BlizzardDropC = -16,
	WeatherChance = { Storm = 0.18, Blizzard = 0.07 },
	Exposure = {
		Day = { Clear = 0.55, Storm = 1.05, Blizzard = 1.9 },
		Night = { Clear = 1.1, Storm = 1.75, Blizzard = 3.0 },
	},
}

Config.Sickness = {
	ColdWarmthThreshold = 25,
	ExposureSeconds = 90,
	CureWarmth = 60,
	CureSeconds = 20,
}

Config.World = {
	Radius = 950,
	MinSeedLength = 5,
	MaxSeedLength = 8,
	DevSeed = "",
	GenerateTerrain = true,
	MountainMinDistance = 250,
	MountainMaxDistance = 850,
	MountainMinRadius = 200,
	MountainMaxRadius = 380,
	MountainMinHeight = 160,
	MountainMaxHeight = 300,
	LakeMinDistance = 200,
	LakeMaxDistance = 800,
	LakeMinRadius = 80,
	LakeMaxRadius = 180,
	ForestClusters = 7,
	ClusterRadius = 130,
	TreesPerCluster = 45,
	CabinsMin = 3,
	CabinsMax = 6,
}

Config.Campfire = {
	WarmthRadius = 18,
	WarmthRate = 2.4,
	StartFuelSeconds = 240,
	FuelPerWood = 45,
}

Config.Tree = {
	Health = 3,
	ChopRange = 10,
}

Config.Log = {
	PieceTargetLength = 4,
	MaxPieces = 5,
	HitsPerCut = 2,
	WoodPerVolume = 0.2,
	WeightPerVolume = 2,
	DragSlowPerWeight = 0.008,
	MinDragSpeedFactor = 0.35,
	DragDistance = 5,
}

Config.Food = {
	RawMeat = 15,
	CookedMeat = 40,
}

Config.Animations = {
	Chop = "",
	Carry = "",
	Sleep = "",
	Shiver = "",
}

return Config
