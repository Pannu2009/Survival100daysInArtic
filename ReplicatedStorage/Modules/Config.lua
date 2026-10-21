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
	MaxHunger = 100,
	HealthRegenPerSecond = 0.05,
	FreezingHealthDrain = 1.5,
	StarvingHealthDrain = 1.0,
	HungerDrainPerSecond = 0.09,
	SprintHungerMultiplier = 2,
}

Config.Temperature = {
	DayAmbientC = -12,
	NightAmbientC = -24,
	StormDropC = -8,
	BlizzardDropC = -16,
	Exposure = {
		Day = { Clear = 0.07, Storm = 0.13, Blizzard = 0.24 },
		Night = { Clear = 0.14, Storm = 0.22, Blizzard = 0.38 },
	},
}

Config.Sickness = {
	ColdWarmthThreshold = 25,
	ExposureSeconds = 90,
	CureWarmth = 60,
	CureSeconds = 20,
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
