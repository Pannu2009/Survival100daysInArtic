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
	Day2HungerMultiplier = 1.4,
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
	FirstWeatherDay = 5,
	Exposure = {
		Day = { Clear = 0.8, Storm = 1.55, Blizzard = 2.75 },
		Night = { Clear = 1.6, Storm = 2.55, Blizzard = 4.4 },
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
	TeamSpeedBase = 8,
	TeamSpeedPerWolf = 2.2,
	TeamAccelBase = 5,
	TeamAccelPerWolf = 1.1,
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

-- Hotbar / build-menu ViewportFrame icons. The camera auto-frames
-- each model from its bounding box; these are the knobs if a model
-- sits wrong. Per-tool overrides: ViewportIcons.PerTool = {
--   Axe = { Yaw = -0.9, Pitch = 0.2, Zoom = 1.3 } } (angles radians;
--   Zoom > 1 = farther away).
Config.ViewportIcons = {
	Yaw = -0.65,
	Pitch = 0.38,
	Zoom = 1,
	PerTool = {},
}

-- Wolves: wild packs, taming, commands, the sled team.
Config.Wolves = {
	MaxHealth = 100,
	LeaderMaxHealth = 160,
	LeaderDamageMult = 1.5,
	BiteDamage = 8,
	BiteRange = 3.4,
	BiteCooldown = 1.2,
	AxeDamage = 12,
	FireScareRadius = 13,
	FireLogScareRadius = 7,
	AggroRangeDay = 16,
	AggroRangeNight = 38,
	WaryRange = 26,
	RoamRadius = 26,
	RoamSpeed = 4,
	ChaseSpeed = 15,
	FollowSpeed = 15.5,
	HarnessSpeed = 18,
	TameHealth = 50,
	TeamLimit = 6,
	MaxAlive = 24,
	PacksToSpawn = 4,
	PackMin = 2,
	PackMax = 5,
	RespawnSeconds = 300,
	AttackSeconds = 12,
	AttackDamage = 10,
	ModelYawOffset = 0,
}

-- Day 2 ice fishing. The rod arrives at Day 2 start (Weapons list,
-- Deferred). Axe hits crack a lake-ice cell open into a water hole;
-- the rod casts at a hole; a Fisch-style tap-in-the-zone reel game
-- lands the fish.
Config.Fishing = {
	IceWorkNeeded = 21,
	AxeIceWork = 7,
	ShovelIceWork = 3,
	HoleLifeSeconds = 600,
	CastRange = 16,
	BiteWaitMin = 3,
	BiteWaitMax = 8,
	BiteWindow = 1.2,
	ReelSeconds = 25,
	ReelStartProgress = 25,
	ReelBarHalf = 0.14,
	ReelBarMaxSpeed = 2.4,
	ReelRiseSpeed = 1.5,
	ReelFallSpeed = 1.1,
	ReelGainPerSecond = 26,
	ReelLossPerSecond = 16,
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
