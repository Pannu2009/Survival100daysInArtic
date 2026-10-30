local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local Signal = require(Modules:WaitForChild("Signal"))
local Temperature = {}
Temperature.__index = Temperature
local VALID_WEATHER = { Clear = true, Storm = true, Blizzard = true }
function Temperature.new()
	local self = setmetatable({}, Temperature)
	self.Weather = "Clear"
	self.OnWeatherChanged = Signal.new()
	return self
end
function Temperature:GetWeather()
	return self.Weather
end
function Temperature:SetWeather(weather)
	if not VALID_WEATHER[weather] then
		return
	end
	if weather ~= self.Weather then
		self.Weather = weather
		self.OnWeatherChanged:Fire(weather)
	end
end
function Temperature:GetAmbientTempC(phase)
	local base = Config.Temperature.DayAmbientC
	if phase == "Night" then
		base = Config.Temperature.NightAmbientC
	end
	if self.Weather == "Storm" then
		base += Config.Temperature.StormDropC
	elseif self.Weather == "Blizzard" then
		base += Config.Temperature.BlizzardDropC
	end
	return base
end
function Temperature:GetExposureRate(phase)
	local byPhase = Config.Temperature.Exposure[phase]
	if not byPhase then
		return 0
	end
	return byPhase[self.Weather] or 0
end
return Temperature
