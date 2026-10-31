local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local Companion = {}
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
function Companion:_loyaltyLevel(wolf)
	local since = os.clock() - (wolf.TamedAt or os.clock())
	return math.min(W.LoyaltyMaxLevel or 10, math.floor(since / (W.LoyaltySecondsPerLevel or 120)))
end
function Companion:_stepTamed(wolf, dt, now, isNight)
	local owner = wolf.Owner
	local character = owner and owner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local pos = wolf.Root.Position
	if wolf.AttackWolf then
		local prey = wolf.AttackWolf
		if prey.Health <= 0 or now > wolf.AttackUntil then
			wolf.AttackWolf = nil
		else
			local d = self:_moveToward(wolf, prey.Root.Position, W.ChaseSpeed * (wolf.SpeedMult or 1) + 1, dt)
			if d <= W.BiteRange and wolf.BiteCd <= 0 then
				wolf.BiteCd = 0.9
				if wolf.BiteSound then
					wolf.BiteSound:Play()
				end
				self:DamageWolf(prey, W.AttackDamage * ((wolf.BiteDamage or W.BiteDamage) / W.BiteDamage) * self:_packBonusMult(wolf), owner)
			end
			return
		end
	end
	if wolf.Health < wolf.MaxHealth * (W.TamedRestHealthFrac or 0.4)
		and (root.Position - pos).Magnitude < 20
		and self:NearestWildWolf(root.Position, 25) == nil
	then
		wolf.Health = math.min(wolf.MaxHealth, wolf.Health + (W.TamedRestHealPerSecond or 2) * dt)
		self:_moveToward(wolf, pos, 0, dt)
		return
	end
	if not wolf.AttackWolf and (self._commands[owner] or "Follow") ~= "Stop"
		and self._behaviours[owner] ~= "Passive"
	then
		local loyalty = self:_loyaltyLevel(wolf)
		local threat = self:NearestWildWolf(root.Position, 20 + loyalty)
		if threat then
			wolf.AttackWolf = threat
			wolf.AttackUntil = now + W.AttackSeconds
		end
	end
	local mode = self._commands[owner] or "Follow"
	if mode == "Stop" then
		self:_moveToward(wolf, pos, 0, dt)
	elseif mode == "Wander" then
		local anchor = wolf.Anchor or pos
		if (root.Position - anchor).Magnitude > 110 then
			anchor = root.Position
			wolf.Anchor = anchor
		end
		if not wolf.RoamTarget or (wolf.RoamTarget - pos).Magnitude < 2 then
			local a = math.random() * math.pi * 2
			local r = math.sqrt(math.random()) * 25
			wolf.RoamTarget = anchor + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		end
		if (root.Position - pos).Magnitude > 70 then
			self:_placeAt(wolf, root.Position - horizontalDir(root.CFrame.LookVector) * 8)
			return
		end
		local roamTarget = wolf.RoamTarget
		if self:_shelteredByFire(roamTarget) then
			roamTarget = self:_pushOutOfFire(roamTarget)
		end
		self:_moveToward(wolf, roamTarget, (W.RoamSpeed + 1.5) * (wolf.SpeedMult or 1), dt)
	elseif mode == "Alert" then
		local back = root.Position - horizontalDir(root.CFrame.LookVector) * 5
		if (pos - back).Magnitude > 3 then
			self:_moveToward(wolf, back, W.FollowSpeed * (wolf.SpeedMult or 1), dt)
		end
		local threat = self:NearestWildWolf(pos, 25)
		if threat then
			wolf.Yaw = yawLerp(wolf.Yaw, yawOf(horizontalDir(threat.Root.Position - pos)), dt * 7)
			if now >= wolf.NextHowl then
				wolf.NextHowl = now + 6
				wolf.HowlUntil = now + 1.6
				if self.Gameplay.Net and wolf.Owner then
					self.Gameplay.Net:SendToClient(wolf.Owner, "PlaySound", { Sound = "WolfHowl" })
				end
				self:_refreshTag(wolf)
			end
			if self._behaviours[owner] ~= "Passive" and wolf.AttackWolf ~= threat then
				wolf.AttackWolf = threat
				wolf.AttackUntil = now + W.AttackSeconds
			end
		else
			self:_moveToward(wolf, pos, 0, dt)
		end
	else
		local back = horizontalDir(root.CFrame.LookVector) * -1
		local right = Vector3.new(-back.Z, 0, back.X)
		local row = math.floor((wolf.SlotIndex - 1) / 2)
		local side = (wolf.SlotIndex % 2 == 1) and -1 or 1
		if wolf.SlotIndex == 1 then
			side = 0
		end
		local loyalty = self:_loyaltyLevel(wolf)
		local slotDist = math.max(6, 8 - loyalty * 0.2)
		local slot = root.Position + back * (slotDist + row * 2.2) + right * (side * 1.7)
		if self:_shelteredByFire(slot) then
			slot = self:_pushOutOfFire(slot)
		end
		if (pos - root.Position).Magnitude < 2.5 and (slot - pos).Magnitude > 1 then
			slot = slot + right * 2
		end
		local d = self:_moveSmart(wolf, slot, W.FollowSpeed * (wolf.SpeedMult or 1), dt)
		if d > 70 then
			self:_placeAt(wolf, slot)
		end
	end
end
return Companion
