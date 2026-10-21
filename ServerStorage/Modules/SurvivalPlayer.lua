local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local Signal = require(Modules:WaitForChild("Signal"))
local Hunger = require(script.Parent:WaitForChild("Hunger"))

local SurvivalPlayer = {}
SurvivalPlayer.__index = SurvivalPlayer

function SurvivalPlayer.new(clock, temperature)
	local self = setmetatable({}, SurvivalPlayer)
	self.Clock = clock
	self.Temperature = temperature
	self.Health = Config.Survival.MaxHealth
	self.Warmth = Config.Survival.MaxWarmth
	self.Hunger = Hunger.new()
	self.IsSick = false
	self.Dead = false
	self.OnDied = Signal.new()
	self.OnSickChanged = Signal.new()
	self.OnHealthChanged = Signal.new()
	self._coldExposure = 0
	self._cureTime = 0
	return self
end

function SurvivalPlayer:Heal(amount)
	if self.Dead then
		return
	end
	self:_setHealth(self.Health + amount)
end

function SurvivalPlayer:Damage(amount)
	if self.Dead then
		return
	end
	self:_setHealth(self.Health - amount)
end

function SurvivalPlayer:Update(dt, context)
	if self.Dead then
		return
	end
	context = context or {}

	self.Hunger:Update(dt, context.IsSprinting == true)

	local loss = self.Temperature:GetExposureRate(self.Clock:GetPhase())
	local gain = (context.FireRate or 0) + (context.WarmthBonus or 0)
	self.Warmth = math.clamp(self.Warmth + (gain - loss) * dt, 0, Config.Survival.MaxWarmth)

	self:_updateSickness(dt)

	local change = 0
	if self.Warmth <= 0 then
		change -= Config.Survival.FreezingHealthDrain
	end
	if self.Hunger:IsStarving() then
		change -= Config.Survival.StarvingHealthDrain
	end
	if change == 0 and self.Hunger:Get() > 0 and self.Warmth > 0 then
		change += Config.Survival.HealthRegenPerSecond
	end
	if change ~= 0 then
		self:_setHealth(self.Health + change * dt)
	end
end

function SurvivalPlayer:_setHealth(value)
	local clamped = math.clamp(value, 0, Config.Survival.MaxHealth)
	if clamped ~= self.Health then
		self.Health = clamped
		self.OnHealthChanged:Fire(clamped)
	end
	if clamped <= 0 and not self.Dead then
		self.Dead = true
		self.OnDied:Fire()
	end
end

function SurvivalPlayer:_updateSickness(dt)
	if self.IsSick then
		if self.Warmth >= Config.Sickness.CureWarmth then
			self._cureTime += dt
			if self._cureTime >= Config.Sickness.CureSeconds then
				self.IsSick = false
				self._cureTime = 0
				self._coldExposure = 0
				self.OnSickChanged:Fire(false)
			end
		else
			self._cureTime = 0
		end
	elseif self.Warmth < Config.Sickness.ColdWarmthThreshold then
		self._coldExposure += dt
		if self._coldExposure >= Config.Sickness.ExposureSeconds then
			self.IsSick = true
			self.OnSickChanged:Fire(true)
		end
	else
		self._coldExposure = math.max(0, self._coldExposure - dt * 0.5)
	end
end

return SurvivalPlayer
