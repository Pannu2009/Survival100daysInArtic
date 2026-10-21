local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local Signal = require(Modules:WaitForChild("Signal"))

local Hunger = {}
Hunger.__index = Hunger

function Hunger.new()
	local self = setmetatable({}, Hunger)
	self.Value = Config.Survival.MaxHunger
	self.OnStarvingChanged = Signal.new()
	self._starving = false
	return self
end

function Hunger:Get()
	return self.Value
end

function Hunger:Set(value)
	self.Value = math.clamp(value, 0, Config.Survival.MaxHunger)
	local starving = self.Value <= 0
	if starving ~= self._starving then
		self._starving = starving
		self.OnStarvingChanged:Fire(starving)
	end
end

function Hunger:Eat(amount)
	self:Set(self.Value + amount)
end

function Hunger:IsStarving()
	return self._starving
end

function Hunger:Update(dt, isSprinting)
	local drain = Config.Survival.HungerDrainPerSecond
	if isSprinting then
		drain *= Config.Survival.SprintHungerMultiplier
	end
	self:Set(self.Value - drain * dt)
end

return Hunger
