local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local Signal = require(Modules:WaitForChild("Signal"))

local DayNightClock = {}
DayNightClock.__index = DayNightClock

function DayNightClock.new()
	local self = setmetatable({}, DayNightClock)
	self.Day = 1
	self.Phase = Config.DayCycle.StartPhase
	self.PhaseTime = 0
	self.Multiplier = Config.Multiplier.Base
	self.OnPhaseChanged = Signal.new()
	self.OnDayAdvanced = Signal.new()
	return self
end

function DayNightClock:GetPhase()
	return self.Phase
end

function DayNightClock:GetDay()
	return self.Day
end

function DayNightClock:GetPhaseLength()
	if self.Phase == "Day" then
		return Config.DayCycle.DayLength
	end
	return Config.DayCycle.NightLength
end

function DayNightClock:GetPhaseProgress()
	return self.PhaseTime / self:GetPhaseLength()
end

function DayNightClock:GetSecondsLeft()
	return self:GetPhaseLength() - self.PhaseTime
end

function DayNightClock:GetMultiplier()
	return self.Multiplier
end

function DayNightClock:SetMultiplier(value)
	self.Multiplier = math.clamp(math.floor(value), 1, Config.Multiplier.MaxAbsolute)
end

function DayNightClock:Update(dt)
	self.PhaseTime += dt
	local length = self:GetPhaseLength()
	while self.PhaseTime >= length do
		self.PhaseTime -= length
		self:_advancePhase()
		length = self:GetPhaseLength()
	end
end

function DayNightClock:_advancePhase()
	if self.Phase == "Day" then
		self.Phase = "Night"
		self.OnPhaseChanged:Fire("Night", self.Day)
	else
		self.Phase = "Day"
		local added = self.Multiplier
		self.Day += added
		self.OnPhaseChanged:Fire("Day", self.Day)
		self.OnDayAdvanced:Fire(self.Day, added)
	end
end

return DayNightClock
