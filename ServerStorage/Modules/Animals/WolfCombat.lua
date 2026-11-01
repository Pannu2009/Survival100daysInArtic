local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local Spatial = require(Modules:WaitForChild("Spatial"))
local Combat = {}
local W = Config.Wolves
function Combat:DamageWolf(wolf, amount, attacker)
	if not wolf or wolf.Health <= 0 then
		return
	end
	wolf.Health -= amount
	wolf.Model:SetAttribute("Health", math.max(0, math.floor(wolf.Health)))
	if wolf.Health <= 0 then
		self:_killWolf(wolf, attacker)
		return
	end
	if not wolf.Owner and wolf.Health <= W.TameHealth and wolf.TameTarget == nil then
		wolf.TameTarget = wolf.Leader and (W.TamePoints * W.LeaderTameMult) or W.TamePoints
		wolf.TamePoints = 0
		wolf.TameableSince = os.clock()
		if attacker then
			self.Gameplay:Notify(attacker, "It's weak -- drop food to tame it!")
		end
	end
	if not wolf.Owner and attacker then
		if wolf.State ~= "GoEat" then
			for _, other in ipairs(self.Wolves) do
				if other.PackId == wolf.PackId and not other.Owner and other.State ~= "GoEat" then
					other.State = "Aggro"
					other.TargetPlayer = attacker
				end
			end
			wolf.State = "Aggro"
			wolf.TargetPlayer = attacker
		end
	end
	self:_refreshTag(wolf)
end
function Combat:_killWolf(wolf, attacker)
	if self.Gameplay and self.Gameplay.Pelts then
		pcall(function()
			self.Gameplay.Pelts:OnWolfKilled(wolf, attacker)
		end)
	end
	if self.Gameplay and self.Gameplay.Meat then
		pcall(function()
			self.Gameplay.Meat:OnWolfKilled(wolf, attacker)
		end)
	end
	if wolf.EatTarget and wolf.EatTarget.Parent then
		wolf.EatTarget:SetAttribute("WolfEating", nil)
	end
	wolf.Health = 0
	if wolf.Owner then
		self:_removeFromOwner(wolf)
	end
	wolf.Model:Destroy()
	wolf.Removed = true
end
function Combat:_biteWolf(attackerWolf, prey)
	if attackerWolf.BiteSound then
		attackerWolf.BiteSound:Play()
	end
	if attackerWolf.AttackTrack and not attackerWolf.AttackTrack.IsPlaying then
		attackerWolf.AttackTrack:Play(0.05)
	end
	attackerWolf.BiteCd = W.BiteCooldown
	self:DamageWolf(prey, (attackerWolf.BiteDamage or W.BiteDamage) * self:_packBonusMult(attackerWolf), nil)
end
function Combat:_nearestEnemyWolf(wolf, maxDist)
	if not self._enemyByModel or self._enemyByModelCount ~= #self.Wolves then
		self._enemyByModel = {}
		for _, other in ipairs(self.Wolves) do
			self._enemyByModel[other.Model] = other
		end
		self._enemyByModelCount = #self.Wolves
	end
	local byModel = self._enemyByModel
	local best, bestDist = nil, maxDist
	for _, model in ipairs(Spatial.TaggedNear("ArcticWolf", wolf.Root.Position, maxDist)) do
		local other = byModel[model]
		if other and other ~= wolf and not other.Owner and other.Health > 0
			and other.PackId ~= wolf.PackId and not other.Removed
		then
			local d = (other.Root.Position - wolf.Root.Position).Magnitude
			if d < bestDist then
				best, bestDist = other, d
			end
		end
	end
	return best
end
function Combat:_bitePlayer(wolf, player)
	local survival = self.Gameplay._survivals[player]
	if not survival then
		return
	end
	if wolf.BiteSound then
		wolf.BiteSound:Play()
	end
	if wolf.AttackTrack and not wolf.AttackTrack.IsPlaying then
		wolf.AttackTrack:Play(0.05)
	end
	local damage = (wolf.BiteDamage or W.BiteDamage) * self:_packBonusMult(wolf)
	survival:Damage(damage)
	wolf.BiteCd = W.BiteCooldown
end
return Combat
