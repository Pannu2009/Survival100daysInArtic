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
	self.Humanoid = nil
	self._diedConn = nil
	self.Warmth = Config.Survival.MaxWarmth
	self.Hunger = Hunger.new()
	self.Insulation = 1
	self.Coins = 0
	self.CureBoost = 1
	self.IsSick = false
	self.Dead = false
	self.OnDied = Signal.new()
	self.OnSickChanged = Signal.new()
	self.OnHealthChanged = Signal.new()
	self._coldExposure = 0
	self._cureTime = 0
	return self
end
function SurvivalPlayer:BindHumanoid(humanoid)
	if self._diedConn then
		self._diedConn:Disconnect()
		self._diedConn = nil
	end
	self.Humanoid = humanoid
	humanoid.MaxHealth = Config.Survival.MaxHealth
	humanoid.Health = Config.Survival.MaxHealth
	self.Health = humanoid.Health
	self._diedConn = humanoid.Died:Connect(function()
		if not self.Dead then
			self.Health = 0
			self.Dead = true
			self.OnDied:Fire()
		end
	end)
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
	if self.Humanoid and self.Humanoid.Parent then
		self.Humanoid:TakeDamage(amount)
		self:_setHealth(self.Humanoid.Health)
	else
		self:_setHealth(self.Health - amount)
	end
end
function SurvivalPlayer:Update(dt, context)
	if self.Dead then
		return
	end
	context = context or {}
	if self.Humanoid and self.Humanoid.Parent then
		if self.Humanoid.Health ~= self.Health then
			self:_setHealth(self.Humanoid.Health)
			if self.Dead then
				return
			end
		end
	end
	local drainScale = 1
	if self.Clock and self.Clock:GetDay() >= 2 then
		drainScale = Config.Survival.Day2HungerMultiplier
	end
	self.Hunger:Update(dt, context.IsSprinting == true, drainScale)
	local loss = self.Temperature:GetExposureRate(self.Clock:GetPhase()) * (self.Insulation or 1)
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
	if self.Humanoid and self.Humanoid.Parent and self.Humanoid.Health ~= clamped then
		self.Humanoid.Health = clamped
	end
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
			self._cureTime += dt * (self.CureBoost or 1)
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
