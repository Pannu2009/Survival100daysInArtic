local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local Survival = {}
local W = Config.Wolves
function Survival:_shelteredByFire(position)
	local gameplay = self.Gameplay
	for _, fire in ipairs(gameplay.World.Fires or {}) do
		if fire.Lit and fire.Fuel > 0 then
			local anchor = fire.CookingPart or fire.Core
			if anchor and (anchor.Position - position).Magnitude <= W.FireScareRadius then
				return true
			end
		end
	end
	for log in pairs(gameplay._burning) do
		if log and log.Parent then
			if (log:GetPivot().Position - position).Magnitude <= W.FireLogScareRadius then
				return true
			end
		end
	end
	return false
end
function Survival:_burnCheck(wolf, dt, now)
	local pos = wolf.Root.Position
	local inFire = false
	for _, fire in ipairs(self.Gameplay.World.Fires or {}) do
		if fire.Lit and fire.Fuel > 0 then
			local anchor = fire.CookingPart or fire.Core
			if anchor then
				local dx = anchor.Position.X - pos.X
				local dz = anchor.Position.Z - pos.Z
				if dx * dx + dz * dz <= Config.Campfire.BurnRadius ^ 2 then
					inFire = true
					break
				end
			end
		end
	end
	if not inFire then
		for log in pairs(self.Gameplay._burning) do
			if log and log.Parent then
				local lp = log:GetPivot().Position
				local dx = lp.X - pos.X
				local dz = lp.Z - pos.Z
				if dx * dx + dz * dz <= 2.2 * 2.2 then
					inFire = true
					break
				end
			end
		end
	end
	if inFire then
		wolf.BurnUntil = now + math.random(Config.Campfire.BurnSecondsMin, Config.Campfire.BurnSecondsMax)
		if not wolf.Root:FindFirstChild("BurnFlames") then
			local flame = Instance.new("Fire")
			flame.Name = "BurnFlames"
			flame.Heat = 8
			flame.Size = 3
			flame.Parent = wolf.Root
		end
	end
	if wolf.BurnUntil then
		if now > wolf.BurnUntil then
			wolf.BurnUntil = nil
			wolf.BurnAcc = 0
			local flame = wolf.Root:FindFirstChild("BurnFlames")
			if flame then
				flame:Destroy()
			end
		else
			wolf.BurnAcc = (wolf.BurnAcc or 0) + dt
			while wolf.BurnAcc >= 1 do
				wolf.BurnAcc -= 1
				self:DamageWolf(wolf, Config.Campfire.BurnDamagePerSecond, nil)
				if wolf.Health <= 0 then
					return
				end
			end
		end
	end
end




return Survival
