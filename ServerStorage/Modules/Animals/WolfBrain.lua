local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local Brain = {}
local W = Config.Wolves
local function horizontalDir(v)
	local h = Vector3.new(v.X, 0, v.Z)
	if h.Magnitude < 0.001 then
		return Vector3.new(0, 0, -1)
	end
	return h.Unit
end
local function yawOf(dir)
	return math.atan2(-dir.X, -dir.Z)
end
local function yawLerp(a, b, t)
	local d = (b - a) % (math.pi * 2)
	if d > math.pi then
		d -= math.pi * 2
	end
	return a + d * math.clamp(t, 0, 1)
end
function Brain:_enterPlaying(wolf, now)
	wolf.State = "Playing"
	wolf.PlayUntil = now + 2 + math.random() * 2
	wolf.PlayTurn = (math.random() - 0.5) * 0.9
	if wolf.IdleTracks and #wolf.IdleTracks > 1 then
		if wolf.IdleTrack then
			wolf.IdleTrack:Stop(0.2)
		end
		wolf.IdleTrack = wolf.IdleTracks[math.random(#wolf.IdleTracks)]
	end
end
function Brain:_syncMood(wolf)
	local mood, target = "Wandering", ""
	local state = wolf.State
	if state == "Aggro" then
		mood = "Attacking"
		target = wolf.TargetPlayer and wolf.TargetPlayer.Name or ""
	elseif state == "Wary" then
		mood = "Watching"
		target = wolf.TargetPlayer and wolf.TargetPlayer.Name or ""
	elseif state == "GoEat" then
		mood = "Eating"
	elseif state == "Playing" then
		mood = "Playing"
	elseif state == "Harness" then
		mood = "Pulling"
	elseif wolf.Owner then
		mood = "Following"
	end
	if wolf.AttackWolf and os.clock() < (wolf.AttackUntil or 0) then
		mood = "Attacking"
		target = "wild wolf"
	end
	if wolf.Mood ~= mood then
		wolf.Mood = mood
		wolf.Model:SetAttribute("Mood", mood)
	end
	if wolf.MoodTarget ~= target then
		wolf.MoodTarget = target
		wolf.Model:SetAttribute("MoodTarget", target)
	end
end
function Brain:_refreshTag(wolf)
	local now = os.clock()
	if now < wolf.HowlUntil then
		wolf.TagLabel.Text = "ALERT!"
		wolf.Tag.Enabled = true
		return
	end
	if wolf.Owner then
		local star = wolf.Leader and "\226\152\133 " or ""
		wolf.TagLabel.Text = star .. wolf.Owner.DisplayName .. "'s wolf"
		wolf.Tag.Enabled = true
	elseif wolf.Health <= W.TameHealth then
		wolf.TagLabel.Text = "Tameable -- drop food"
		wolf.Tag.Enabled = true
	elseif wolf.Health < wolf.MaxHealth then
		wolf.TagLabel.Text = ("HP %d"):format(math.ceil(wolf.Health))
		wolf.Tag.Enabled = true
	else
		wolf.Tag.Enabled = false
	end
end


function Brain:_step(dt)
	local now = os.clock()
	do
		local anyRemoved = false
		for i = #self.Wolves, 1, -1 do
			if self.Wolves[i].Removed then
				table.remove(self.Wolves, i)
				anyRemoved = true
			end
		end
		if anyRemoved then
			for packId in pairs(self._packs) do
				local alive = false
				for _, wolf in ipairs(self.Wolves) do
					if wolf.PackId == packId then
						alive = true
						break
					end
				end
				if not alive then
					self._packs[packId] = nil
				end
			end
		end
	end
	self._dangerTick -= dt
	if self._dangerTick <= 0 then
		self._dangerTick = 0.25
		local marked = {}
		for _, wolf in ipairs(self.Wolves) do
			if wolf.State == "Aggro" and wolf.TargetPlayer then
				marked[wolf.TargetPlayer] = true
			end
		end
		for player in pairs(self._dangerSet) do
			if not marked[player] then
				player:SetAttribute("InDanger", false)
				self._dangerSet[player] = nil
			end
		end
		for player in pairs(marked) do
			if not self._dangerSet[player] then
				player:SetAttribute("InDanger", true)
				self._dangerSet[player] = true
			end
		end
	end
	local clock = self.Gameplay.Clock
	local isNight = clock and clock:GetPhase() == "Night"
	if isNight then
		self._nightHowlTick = (self._nightHowlTick or 20) - dt
		if self._nightHowlTick <= 0 then
			self._nightHowlTick = 35 + math.random() * 40
			if self.Gameplay.Net then
				self.Gameplay.Net:SendToAll("PlaySound", { Sound = "WolfHowl" })
			end
			local howled = 0
			for _, wolf in ipairs(self.Wolves) do
				if not wolf.Owner and wolf.Health > 0 then
					wolf.HowlUntil = now + 1.6
					howled += 1
					if howled >= 3 then
						break
					end
				end
			end
		end
	end
	self._topUpTick = (self._topUpTick or 0) - dt
	if self._topUpTick <= 0 then
		self._topUpTick = W.TopUpSeconds
		local target = self:_population().Total
		if self:_wildCount() < target then
			self:_spawnPack()
		end
	end
	for _, wolf in ipairs(self.Wolves) do
		if wolf.BiteCd > 0 then
			wolf.BiteCd -= dt
		end
		wolf.Think -= dt
		local think = wolf.Think <= 0
		if think then
			wolf.Think = 0.2
		end
		local pos = wolf.Root.Position
		self:_burnCheck(wolf, dt, now)
		if wolf.Health <= 0 then
			continue
		end
		if wolf.Owner then
			local survival = self.Gameplay._survivals[wolf.Owner]
			if not wolf.Owner.Parent or (survival and survival.Dead) then
				self:_releaseWolf(wolf)
				continue
			end
		end
		if not wolf.Owner then
			wolf.Hunger = math.max(0, (wolf.Hunger or 50) - (W.HungerDrainPerSecond or 0.05) * dt)
			if now < (wolf.RestUntil or 0) and wolf.State == "Roam" then
				wolf.Health = math.min(wolf.MaxHealth, wolf.Health + (W.RestHealPerSecond or 3) * dt)
				self:_moveToward(wolf, wolf.Root.Position, 0, dt)
				continue
			end
			if think and wolf.State == "Roam" and wolf.Health < wolf.MaxHealth * 0.5
				and self:_nearestVisiblePlayer(wolf, self:_waryRange(wolf)) == nil
			then
				wolf.RestUntil = now + (W.RestSeconds or 8)
			end
			if think and (wolf.State == "Roam" or wolf.State == "Wary")
				and (wolf.Hunger or 50) < (W.HungryThreshold or 30)
				and now >= (wolf.NextFoodSearch or 0)
			then
				wolf.NextFoodSearch = now + 1
				self:_tryHungryEat(wolf)
			end
		end
		if not wolf.Owner and wolf.State ~= "GoEat" and wolf.Health <= W.TameHealth then
			if think and now >= (wolf.NextFoodSearch or 0) then
				wolf.NextFoodSearch = now + 1
				self:_tryTame(wolf)
			end
			if (wolf.State == "Roam" or wolf.State == "Wary")
				and (wolf.TamePoints or 0) == 0
				and wolf.TameableSince and now - wolf.TameableSince > 60
				and self:_nearestPlayer(wolf.Root.Position, 25) == nil
			then
				wolf.Health += 7.5 * dt
				if wolf.Health > W.TameHealth then
					wolf.TameTarget = nil
					wolf.TamePoints = 0
					wolf.TameableSince = nil
					self:_refreshTag(wolf)
				end
			end
		end
		if not wolf.Owner and wolf.Health > 0 and wolf.Health < (wolf.MaxHealth * self:_fleeFrac(wolf))
			and not wolf.Leader and (wolf.State == "Aggro" or wolf.State == "WolfFight")
			and not (wolf.FleeUntil and now < wolf.FleeUntil)
		then
			local threatPos = nil
			if wolf.TargetPlayer and wolf.TargetPlayer.Character then
				local tr = wolf.TargetPlayer.Character:FindFirstChild("HumanoidRootPart")
				threatPos = tr and tr.Position
			end
			if not threatPos and wolf.TargetWolf and wolf.TargetWolf.Root then
				threatPos = wolf.TargetWolf.Root.Position
			end
			wolf.State = "Roam"
			wolf.TargetPlayer = nil
			wolf.TargetWolf = nil
			wolf.RoamTarget = threatPos and self:_safeRetreat(wolf, threatPos) or wolf.Home
			wolf.FleeUntil = now + 5
		end
		if not wolf.Owner and think and (wolf.State == "Roam" or wolf.State == "Wary")
			and not (wolf.FleeUntil and now < wolf.FleeUntil)
		then
			local fightRange = (wolf.Root.Position - wolf.Home).Magnitude <= (W.TerritoryRadius or 40) and W.WolfFightRange or (W.OutsideTerritoryFightRange or 12)
			local enemy = self:_nearestEnemyWolf(wolf, fightRange)
			if enemy then
				wolf.State = "WolfFight"
				wolf.TargetWolf = enemy
			end
		end
		self:_syncMood(wolf)
		if wolf.State == "Roam" then
			if think then
				local near, dist = self:_nearestVisiblePlayer(wolf, self:_waryRange(wolf))
				if near then
					local aggroRange = self:_aggroRange(wolf, isNight)
					local nearRoot = near.Character and near.Character:FindFirstChild("HumanoidRootPart")
					local sheltered = nearRoot and self:_shelteredByFire(nearRoot.Position)
					if dist <= aggroRange and not sheltered then
						wolf.State = "Aggro"
						wolf.TargetPlayer = near
						self:_shareThreat(wolf, near)
					else
						wolf.State = "Wary"
						wolf.TargetPlayer = near
						wolf.WarySince = now
					end
				else
					local sprinter = self:_nearestSprintingPlayer(wolf, W.SprintHearRadius or 35)
					if sprinter then
						local sRoot = sprinter.Character and sprinter.Character:FindFirstChild("HumanoidRootPart")
						if sRoot then
							wolf.State = "Wary"
							wolf.TargetPlayer = sprinter
							wolf.WarySince = now
							wolf.NoisePos = sRoot.Position
							wolf.NoiseUntil = now + (W.MemorySeconds or 8)
							self:_remember(wolf, sRoot.Position)
						end
					end
				end
				if not wolf.RoamTarget or (wolf.RoamTarget - pos).Magnitude < 2 then
					if wolf.RoamTarget and math.random() < 0.34 then
						wolf.RoamTarget = nil
						self:_enterPlaying(wolf, now)
					else
						local a = math.random() * math.pi * 2
						local radius = W.RoamRadius
						if wolf.PackRole == "Scout" then radius = radius * 1.5 end
						if wolf.PackRole == "Guard" then radius = radius * 0.5 end
						local r = math.sqrt(math.random()) * radius
						wolf.RoamTarget = wolf.Home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
					end
				end
			end
			if wolf.RoamTarget then
				self:_moveSmart(wolf, wolf.RoamTarget, W.RoamSpeed * (wolf.SpeedMult or 1), dt)
			end
		elseif wolf.State == "Playing" then
			if think then
				local near, dist = self:_nearestVisiblePlayer(wolf, self:_waryRange(wolf))
				if near then
					local aggroRange = self:_aggroRange(wolf, isNight)
					local nearRoot = near.Character and near.Character:FindFirstChild("HumanoidRootPart")
					local sheltered = nearRoot and self:_shelteredByFire(nearRoot.Position)
					if dist <= aggroRange and not sheltered then
						wolf.State = "Aggro"
						wolf.TargetPlayer = near
						self:_shareThreat(wolf, near)
					else
						wolf.State = "Wary"
						wolf.TargetPlayer = near
					end
				end
			end
			if wolf.State == "Playing" then
				if now >= (wolf.PlayUntil or 0) then
					wolf.State = "Roam"
					wolf.RoamTarget = nil
				else
					wolf.Yaw += (wolf.PlayTurn or 0) * dt
					self:_moveToward(wolf, pos, 0, dt)
				end
			end
		elseif wolf.State == "Wary" then
			local target = wolf.TargetPlayer
			local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
			if not root then
				if wolf.LastSeenPos and now < (wolf.LastSeenUntil or 0) then
					self:_moveToward(wolf, wolf.LastSeenPos, W.RoamSpeed * 1.6 * (wolf.SpeedMult or 1), dt)
					if (wolf.LastSeenPos - pos).Magnitude < 5 then
						wolf.LastSeenPos = nil
						wolf.State = "Roam"
						wolf.TargetPlayer = nil
					end
				else
					wolf.LastSeenPos = nil
					wolf.State = "Roam"
					wolf.TargetPlayer = nil
				end
			else
				self:_remember(wolf, root.Position)
				local d = (root.Position - pos).Magnitude
				wolf.Yaw = yawLerp(wolf.Yaw, yawOf(horizontalDir(root.Position - pos)), dt * 7)
				local aggroRange = self:_aggroRange(wolf, isNight)
				local investigating = false
				if d <= aggroRange and not self:_shelteredByFire(root.Position) then
					wolf.State = "Aggro"
					wolf.NoisePos = nil
					self:_shareThreat(wolf, target)
				elseif d > self:_waryRange(wolf) + 10 then
					if wolf.NoisePos and now < (wolf.NoiseUntil or 0) then
						investigating = true
						self:_moveToward(wolf, wolf.NoisePos, W.RoamSpeed * 1.6 * (wolf.SpeedMult or 1), dt)
						if (wolf.NoisePos - pos).Magnitude < 5 then
							wolf.NoisePos = nil
						end
					else
						wolf.NoisePos = nil
						wolf.State = "Roam"
						wolf.TargetPlayer = nil
					end
				end
				if not investigating then
					if not wolf.WarySince then
						wolf.WarySince = now
					end
					local waryFor = now - wolf.WarySince
					if waryFor > self:_waryTimeout(wolf) then
						wolf.State = "Roam"
						wolf.TargetPlayer = nil
						wolf.WarySince = nil
						wolf.RoamTarget = nil
					elseif waryFor > 3 then
						if not wolf.WaryPaceTarget or now > (wolf.WaryPaceUntil or 0)
							or (wolf.WaryPaceTarget - pos).Magnitude < 3 then
							local a = math.random() * math.pi * 2
							wolf.WaryPaceTarget = root.Position
								+ Vector3.new(math.cos(a) * 18, 0, math.sin(a) * 18)
							wolf.WaryPaceUntil = now + 3
						end
						self:_moveSmart(wolf, wolf.WaryPaceTarget, W.RoamSpeed * (wolf.SpeedMult or 1), dt)
					else
						self:_moveToward(wolf, pos, 0, dt)
					end
				end
			end
		elseif wolf.State == "Aggro" then
			local target = wolf.TargetPlayer
			local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
			if not root then
				if wolf.LastSeenPos and now < (wolf.LastSeenUntil or 0) then
					wolf.State = "Wary"
					wolf.NoisePos = wolf.LastSeenPos
					wolf.NoiseUntil = wolf.LastSeenUntil
					wolf.WarySince = now
				else
					wolf.State = "Roam"
					wolf.TargetPlayer = nil
				end
			elseif think and self:_shelteredByFire(root.Position) then
				wolf.State = "Wary"
			else
				self:_remember(wolf, root.Position)
				local chaseTarget = root.Position
				if wolf.PackRole == "Flanker" then
					local toPrey = Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z)
					if toPrey.Magnitude > 0.1 then
						local perp = Vector3.new(-toPrey.Z, 0, toPrey.X).Unit * ((wolf.PackIndex or 0) % 2 == 0 and 4 or -4)
						chaseTarget = root.Position + perp
					end
				end
				local chaseSpeed = W.ChaseSpeed * (wolf.SpeedMult or 1)
				if wolf.PackRole == "Chaser" then chaseSpeed = chaseSpeed * 1.1 end
				local d = self:_moveSmart(wolf, chaseTarget, chaseSpeed, dt)
				local biteDist = (root.Position - wolf.Root.Position).Magnitude
				if biteDist <= W.BiteRange and wolf.BiteCd <= 0 then
					self:_bitePlayer(wolf, target)
				end
				local giveUp = wolf.PackRole == "Guard" and 50 or 90
				if think and d > giveUp then
					if wolf.LastSeenPos and now < (wolf.LastSeenUntil or 0) then
						wolf.State = "Wary"
						wolf.NoisePos = wolf.LastSeenPos
						wolf.NoiseUntil = wolf.LastSeenUntil
						wolf.WarySince = now
					else
						wolf.State = "Roam"
						wolf.TargetPlayer = nil
					end
				end
			end
		elseif wolf.State == "WolfFight" then
			local prey = wolf.TargetWolf
			if not prey or prey.Health <= 0 or prey.Removed then
				wolf.State = "Roam"
				wolf.TargetWolf = nil
			else
				local flank = Vector3.new(0, 0, 0)
				if (wolf.PackIndex or 0) % 3 == 2 then
					flank = Vector3.new(3, 0, 0)
				elseif (wolf.PackIndex or 0) % 3 == 0 then
					flank = Vector3.new(-3, 0, 0)
				end
				local d = self:_moveSmart(wolf, prey.Root.Position + flank, W.ChaseSpeed * (wolf.SpeedMult or 1), dt)
				if d <= W.BiteRange and wolf.BiteCd <= 0 then
					self:_biteWolf(wolf, prey)
				end
				if think and d > 90 then
					wolf.State = "Roam"
					wolf.TargetWolf = nil
				end
			end
		elseif wolf.State == "GoEat" then
			self:_stepGoEat(wolf, dt, now)
		elseif wolf.State == "Tamed" then
			self:_stepTamed(wolf, dt, now, isNight)
		elseif wolf.State == "Harness" then
			local sledService = wolf.SledService
			if not sledService or not sledService.Sled then
				wolf.State = "Tamed"
				wolf.SledService = nil
			else
				local slotPos = sledService:GetHarnessSlot(wolf.SlotIndex, self:Count(wolf.Owner))
				if slotPos then
					local d = self:_moveSmart(wolf, slotPos, W.HarnessSpeed * (wolf.SpeedMult or 1), dt)
					if d > 26 then
						self:_placeAt(wolf, slotPos)
					end
				end
			end
		end
		if now < wolf.HowlUntil or wolf.Tag.Enabled then
			self:_refreshTag(wolf)
		end
	end
end
return Brain
