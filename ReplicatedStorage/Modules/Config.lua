local Config = {}

Config.DayCycle = {
	DayLength = 180,
	NightLength = 120,
	StartPhase = "Day",
	-- Nights are properly dark; brightness follows the sun so dusk
	-- and dawn fade instead of snapping at the phase change.
	DayBrightness = 2,
	NightBrightness = 0.6,
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
	WarmthRadius = 23,
	WarmthRate = 2.4,
	BurningLogRadius = 10,
	BurningLogWarmRate = 1.8,
	BurningLogCookRange = 4,
	BuildFuelSeconds = 45,
	FuelPerBurnUnit = 20,
	-- A log burning loose in the open dies faster than the same
	-- log feeding a campfire: wind and snow eat it.
	OpenBurnSecondsPerUnit = 12,
	-- Fire spread: a burnable log whose surface sits within
	-- SpreadGap of burning wood catches after SpreadSeconds of
	-- exposure. Wood piles chain; sled cargo is not exempt.
	SpreadGap = 1.5,
	SpreadSeconds = 2.5,
	FuelDisplayMax = 600,
	FeedRange = 10,
}

Config.Sled = {
	MaxCargoPieces = 10,
	Weight = 0,
	RopeLength = 7,
	PullSlowPerWeight = 0.004,
	MinPullSpeedFactor = 0.15,
	InteractRange = 13,
	PullRange = 17,
	RopeSpring = 15,
	RopeDamp = 1.4,
	Friction = 2.2,
	LateralGrip = 5.5,
	SlopeGravity = 30,
	StaticHold = 5,
	MaxSpeed = 30,
	YawResponse = 6,
	TowTorque = 0.03,
	YawDamp = 5,
}

Config.Tracks = {
	SledLife = 7,
	FootLife = 8,
	SledStep = 2.2,
	FootStep = 1.9,
}

Config.Blueprint = {
	CampfireCostKg = 40,
	PlaceRange = 25,
	MinSpacing = 6,
}

Config.Lighter = {
	StartFuel = 100,
	LightCost = 5,
	AimRange = 12,
}

Config.Digging = {
	Radius = 2.6,
	Reach = 4,
	AimRange = 9,
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
	-- Burn value derives from weight, so thickness and length both
	-- count: a fat log is more kilos and burns longer everywhere.
	KgPerBurnUnit = 12.5,
	WeightPerVolume = 2.5,
	MaxWeight = 50,
	DragSlowPerWeight = 0.008,
	MinDragSpeedFactor = 0.35,
	DragDistance = 7,
	DragMaxRise = 6,
	DragHover = 1.1,
}

Config.Food = {
	RawMeat = 15,
	CookedMeat = 40,
	PiecesPerFish = 5,
	RawPieceHunger = 2,
	RawPieceHeal = -1,
	CookedPieceHunger = 16,
	CookedPieceHeal = 0.5,
	CookSeconds = 5,
}

Config.Animations = {
	Chop = "",
	Carry = "",
	Sleep = "",
	Shiver = "",
}

return Config
