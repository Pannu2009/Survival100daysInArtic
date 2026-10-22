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
	HungerDrainPerSecond = 0.11,
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
	RadiusByLevel = { 18, 23, 28, 33, 38, 44, 50 },
	LevelBurnUnits = { 0, 4, 10, 18, 28, 40, 55 },
	WarmthRate = 2.4,
	BuildFuelSeconds = 45,
	FuelPerBurnUnit = 45,
	FuelDisplayMax = 600,
	FeedRange = 10,
}

Config.Sled = {
	MaxCargoWeight = 100,
	Weight = 25,
	RopeLength = 7,
	PullSlowPerWeight = 0.004,
	MinPullSpeedFactor = 0.35,
	InteractRange = 13,
	PullRange = 17,
	RopeSpring = 15,
	RopeDamp = 1.4,
	Friction = 2.2,
	SlopeGravity = 30,
	StaticHold = 5,
	MaxSpeed = 30,
	YawResponse = 6,
	YawDamp = 5,
}

Config.Blueprint = {
	CampfireCostKg = 40,
	PlaceRange = 25,
	MinSpacing = 6,
}

Config.Lighter = {
	StartFuel = 100,
	LightCost = 5,
}

Config.Digging = {
	Radius = 2.6,
	Reach = 4,
	Cooldown = 0.35,
	SafeRadius = 5,
}

Config.Tree = {
	Health = 3,
	ChopRange = 10,
	ChopCooldown = 0.35,
}

Config.Log = {
	PieceTargetLength = 7.5,
	MaxPieces = 3,
	BigTreeLength = 14,
	BigPieceTargetLength = 5,
	BigTreeMaxPieces = 5,
	BurnUnitsPerVolume = 0.2,
	WeightPerVolume = 2.5,
	DragSlowPerWeight = 0.008,
	MinDragSpeedFactor = 0.35,
	DragDistance = 7,
	DragMaxRise = 6,
	DragHover = 1.1,
}

Config.Food = {
	RawMeat = 15,
	CookedMeat = 40,
	RawFishHunger = 10,
	RawFishHeal = -5,
	CookedFishHunger = 16,
	CookedFishHeal = 2.5,
	CookSeconds = 5,
}

Config.Animations = {
	Chop = "",
	Carry = "",
	Sleep = "",
	Shiver = "",
}

return Config
