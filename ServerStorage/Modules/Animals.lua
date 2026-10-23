local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))

-- Animals: the parent system for every creature. Today it drives
-- Ajay's WolfModel -- wild packs with a leader, day/night hunting
-- behavior, axe combat both ways, fish taming, owner commands
-- (Follow / Wander / Alert / Attack) and the sled harness
-- formation. Kids will live under this same module when they land.
--
-- Wolves are stepped kinematically on Heartbeat (like the sled):
-- ground-snapped, yaw-steered, no physics ownership fights. His
-- model's built-in script is retired at clone time -- this module
-- is the only driver.

local Animals = {}
Animals.__index = Animals

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

function Animals.new(gameplay)
	local self = setmetatable({}, Animals)
	self.Gameplay = gameplay
	self.Folder = nil
	self.Template = nil
	self.Wolves = {}
	self._byOwner = {}
	self._commands = {}
	self._packs = {}
	self._nextPackId = 0
	self._dangerSet = {}
	self._dangerTick = 0
	return self
end

function Animals:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Animals"
	folder.Parent = workspace
	self.Folder = folder

	local assets = ReplicatedStorage:WaitForChild("Assets", 5)
	self.Template = assets and assets:FindFirstChild("WolfModel")
	if not self.Template then
		warn("[Arctic] Animals: no Assets/WolfModel - no wolves will spawn")
		return
	end

	for _ = 1, W.PacksToSpawn do
		self:_spawnPack()
	end

	RunService.Heartbeat:Connect(function(dt)
		self:_step(math.min(dt, 0.05))
	end)
end

-- ---------- model normalization ----------

local function findRootPart(model)
	local named = model:FindFirstChild("HumanoidRootPart", true)
		or model:FindFirstChild("Root", true)
		or model:FindFirstChild("Body", true)
	if named and named:IsA("BasePart") then
		return named
	end
	local biggest, biggestVolume = nil, -1
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > biggestVolume then
				biggest, biggestVolume = d, v
			end
		end
	end
	return biggest
end

function Animals:_buildWolf()
	local walkTrack = nil
	local biteSoundFound = nil
	local wolf = self.Template:Clone()
	for _, d in ipairs(wolf:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	local root = findRootPart(wolf)
	if not root then
		wolf:Destroy()
		return nil
	end
	-- Which parts does a joint already hold? (His rig animates via
	-- Motor6Ds -- welding one of those parts would freeze it.
	-- Only truly loose parts get a WeldConstraint to the root.)
	local jointed = {}
	for _, d in ipairs(wolf:GetDescendants()) do
		if d:IsA("Motor6D") or d:IsA("Weld") or d:IsA("WeldConstraint") then
			if d.Part0 then
				jointed[d.Part0] = true
			end
			if d.Part1 then
				jointed[d.Part1] = true
			end
		end
	end
	for _, d in ipairs(wolf:GetDescendants()) do
		if d:IsA("BasePart") then
			if d == root then
				d.Anchored = true
				d.CanCollide = false
			else
				d.Anchored = false
				d.CanCollide = false
				d.Massless = true
				if not jointed[d] and d.Parent ~= root then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = root
					weld.Part1 = d
					weld.Parent = d
				end
			end
		end
	end
	-- His WalkAnim + bite sound live in the model: wire both up.
	local walkAnim = wolf:FindFirstChild("WalkAnim", true)
	if walkAnim and walkAnim:IsA("Animation") then
		local host = wolf:FindFirstChildOfClass("AnimationController")
			or wolf:FindFirstChildOfClass("Humanoid")
		if not host then
			host = Instance.new("AnimationController")
			host.Parent = wolf
		end
		local animator = host:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = host
		end
		local ok, track = pcall(function()
			return animator:LoadAnimation(walkAnim)
		end)
		if ok and track then
			track.Looped = true
			wolf:SetAttribute("WalkTrackReady", true)
			walkTrack = track
		end
	end
	local biteSound = wolf:FindFirstChild("damage", true)
	if biteSound and biteSound:IsA("Sound") then
		wolf:SetAttribute("BiteSoundReady", true)
		biteSoundFound = biteSound
	end
	wolf:SetAttribute("IsWolf", true)

	-- Name / status tag: hidden for a healthy wild wolf, shows HP
	-- once hurt, "Tameable" when weakened, the owner's name once
	-- tamed, ALERT! when a tamed wolf howls a warning.
	local head = wolf:FindFirstChild("Head", true)
	local anchor = (head and head:IsA("BasePart") and head) or root
	local tag = Instance.new("BillboardGui")
	tag.Name = "WolfTag"
	tag.Size = UDim2.fromOffset(150, 34)
	tag.StudsOffset = Vector3.new(0, 2.2, 0)
	tag.AlwaysOnTop = false
	tag.Enabled = false
	tag.Adornee = anchor
	tag.Parent = wolf
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.4
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.Parent = tag

	local record = {
		Model = wolf,
		Root = root,
		WalkTrack = walkTrack,
		BiteSound = biteSoundFound,
		Tag = tag,
		TagLabel = label,
		Yaw = math.random() * math.pi * 2,
		WalkCycle = math.random() * 10,
		Think = math.random() * 0.2,
		BiteCd = 0,
		State = "Roam",
		Health = W.MaxHealth,
		MaxHealth = W.MaxHealth,
		Leader = false,
		Owner = nil,
		PackId = nil,
		Home = Vector3.zero,
		RoamTarget = nil,
		TargetPlayer = nil,
		WeakSince = nil,
		SledService = nil,
		SlotIndex = 0,
		AttackWolf = nil,
		AttackUntil = 0,
		HowlUntil = 0,
		NextHowl = 0,
	}
	-- Ground offset: how far the pivot rides above the ground so
	-- the model's feet touch the snow.
	local pivotY = wolf:GetPivot().Position.Y
	local _, size = wolf:GetBoundingBox()
	local cf = wolf:GetBoundingBox()
	record.GroundOffset = math.max(0.2, pivotY - (cf.Position.Y - size.Y / 2))
	return record
end

function Animals:_placeAt(record, position)
	local groundY = self.Gameplay.World:GroundY(position.X, position.Z)
	local pos = Vector3.new(position.X, groundY + record.GroundOffset, position.Z)
	record.Model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, record.Yaw + W.ModelYawOffset, 0))
	record.Model.Parent = self.Folder
end

-- ---------- packs ----------

function Animals:_packSpawnPosition()
	local world = self.Gameplay.World
	local layout = world and world.Layout
	local radius = (layout and layout.WorldRadius) or 500
	local lake = layout and layout.Lake
	for _ = 1, 14 do
		local angle = math.random() * math.pi * 2
		local dist = math.random(110, math.min(380, radius - 50))
		local x = math.cos(angle) * dist
		local z = math.sin(angle) * dist
		if lake then
			local dx = x - lake.X
			local dz = z - lake.Z
			if dx * dx + dz * dz < (lake.Radius + 25) * (lake.Radius + 25) then
				continue
			end
		end
		return Vector3.new(x, 0, z)
	end
	return Vector3.new(150, 0, 150)
end

function Animals:_spawnPack()
	if not self.Template then
		return 0
	end
	-- World population cap (Ajay): never more than MaxAlive
	-- wolves in the world at once, wild or tamed.
	local room = W.MaxAlive - #self.Wolves
	if room <= 0 then
		return 0
	end
	self._nextPackId += 1
	local packId = self._nextPackId
	local home = self:_packSpawnPosition()
	local count = math.min(math.random(W.PackMin, W.PackMax), room)
	local pack = { Id = packId, Home = home, RespawnAt = nil }
	self._packs[packId] = pack
	local spawned = 0
	for i = 1, count do
		local record = self:_buildWolf()
		if not record then
			return spawned
		end
		spawned += 1
		record.PackId = packId
		record.Home = home
		if i == 1 then
			-- The pack leader: bigger pool, harder bite.
			record.Leader = true
			record.MaxHealth = W.LeaderMaxHealth
			record.Health = W.LeaderMaxHealth
		end
		record.Model:SetAttribute("Leader", record.Leader)
		local angle = (i / count) * math.pi * 2
		self:_placeAt(record, home + Vector3.new(math.cos(angle) * 4, 0, math.sin(angle) * 4))
		table.insert(self.Wolves, record)
	end
	return spawned
end

-- ---------- queries used by other systems ----------

function Animals:Count(player)
	local list = self._byOwner[player]
	return list and #list or 0
end

function Animals:TamedWolves(player)
	return self._byOwner[player] or {}
end

function Animals:WolfFromInstance(instance)
	local node = instance
	for _ = 1, 5 do
		if not node then
			return nil
		end
		if node:GetAttribute("IsWolf") then
			for _, wolf in ipairs(self.Wolves) do
				if wolf.Model == node then
					return wolf
				end
			end
			return nil
		end
		node = node.Parent
	end
	return nil
end

function Animals:NearestWildWolf(position, maxDist)
	local best, bestDist = nil, maxDist
	for _, wolf in ipairs(self.Wolves) do
		if not wolf.Owner and wolf.Health > 0 then
			local d = (wolf.Root.Position - position).Magnitude
			if d < bestDist then
				best, bestDist = wolf, d
			end
		end
	end
	return best
end

-- ---------- combat ----------

function Animals:DamageWolf(wolf, amount, attacker)
	if not wolf or wolf.Health <= 0 then
		return
	end
	wolf.Health -= amount
	wolf.Model:SetAttribute("Health", math.max(0, math.floor(wolf.Health)))
	if wolf.Health <= 0 then
		self:_killWolf(wolf)
		return
	end
	if not wolf.Owner then
		if wolf.Health <= W.TameHealth then
			if wolf.State ~= "Weakened" and attacker then
				self.Gameplay:Notify(attacker, "It's weak -- drop a fish to tame it!")
			end
			wolf.State = "Weakened"
			wolf.WeakSince = os.clock()
			wolf.TargetPlayer = nil
		elseif attacker then
			-- The whole pack answers an attack.
			for _, other in ipairs(self.Wolves) do
				if other.PackId == wolf.PackId and not other.Owner and other.Health > W.TameHealth then
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

function Animals:_killWolf(wolf)
	wolf.Health = 0
	if wolf.Owner then
		self:_removeFromOwner(wolf)
	end
	local pack = wolf.PackId and self._packs[wolf.PackId]
	wolf.Model:Destroy()
	for i, w in ipairs(self.Wolves) do
		if w == wolf then
			table.remove(self.Wolves, i)
			break
		end
	end
	if pack then
		local anyLeft = false
		for _, w in ipairs(self.Wolves) do
			if w.PackId == pack.Id and not w.Owner then
				anyLeft = true
				break
			end
		end
		if not anyLeft then
			pack.RespawnAt = os.clock() + W.RespawnSeconds
		end
	end
end

function Animals:_removeFromOwner(wolf)
	local owner = wolf.Owner
	if not owner then
		return
	end
	local list = self._byOwner[owner]
	if list then
		for i, w in ipairs(list) do
			if w == wolf then
				table.remove(list, i)
				break
			end
		end
		for i, w in ipairs(list) do
			w.SlotIndex = i
		end
	end
	wolf.Owner = nil
	wolf.SledService = nil
	self:_publishOwner(owner)
end

function Animals:_releaseWolf(wolf)
	-- Owner gone (left or died): the wolf goes wild where it is.
	self:_removeFromOwner(wolf)
	wolf.State = "Roam"
	wolf.Home = wolf.Root.Position
	wolf.PackId = nil
	wolf.TargetPlayer = nil
	self:_refreshTag(wolf)
end

function Animals:_publishOwner(player)
	player:SetAttribute("WolfCount", self:Count(player))
	player:SetAttribute("WolfCommand", self._commands[player] or "Follow")
end

-- ---------- taming ----------

function Animals:_tryTame(wolf)
	-- A weakened wolf scans for a fish somebody dropped: a loose
	-- fish whose LastDragger is set. The wolf walks to it, eats
	-- it, and belongs to that player (team cap applies).
	local fishFolder = self.Gameplay.Fish and self.Gameplay.Fish.Folder
	if not fishFolder then
		return false
	end
	local pos = wolf.Root.Position
	local best, bestDist = nil, 14
	for _, fish in ipairs(fishFolder:GetChildren()) do
		local lastDragger = fish:GetAttribute("LastDragger")
		if lastDragger then
			local primary = fish:FindFirstChild("F1") or fish:FindFirstChildWhichIsA("BasePart", true)
			if primary and primary:GetAttribute("DraggedBy") == nil then
				local d = (primary.Position - pos).Magnitude
				if d < bestDist then
					best, bestDist = fish, d
				end
			end
		end
	end
	if not best then
		return false
	end
	wolf.EatTarget = best
	wolf.State = "GoEat"
	return true
end

function Animals:_finishTame(wolf, fish)
	local lastDragger = fish:GetAttribute("LastDragger")
	fish:Destroy()
	local owner = lastDragger and Players:GetPlayerByUserId(lastDragger)
	if not owner or self:Count(owner) >= W.TeamLimit then
		-- Fed but not claimed (nobody there, or their team is
		-- full): the wolf recovers and stays wild.
		wolf.Health = math.min(wolf.MaxHealth, wolf.Health + 40)
		wolf.State = "Roam"
		wolf.WeakSince = nil
		self:_refreshTag(wolf)
		return
	end
	wolf.Owner = owner
	wolf.State = "Tamed"
	wolf.WeakSince = nil
	wolf.TargetPlayer = nil
	local list = self._byOwner[owner]
	if not list then
		list = {}
		self._byOwner[owner] = list
	end
	table.insert(list, wolf)
	wolf.SlotIndex = #list
	self.Gameplay:Notify(owner, ("Wolf tamed! (%d/%d)"):format(#list, W.TeamLimit))
	wolf.Model:SetAttribute("Owner", owner.UserId)
	self:_publishOwner(owner)
	self:_refreshTag(wolf)
	print(("[Arctic] %s tamed a wolf (%d/%d)"):format(owner.Name, #list, W.TeamLimit))
end

-- ---------- commands ----------

function Animals:SetCommand(player, mode, targetPos)
	self._commands[player] = mode
	player:SetAttribute("WolfCommand", mode)
	if mode == "Attack" and typeof(targetPos) == "Vector3" then
		local target = self:NearestWildWolf(targetPos, 50)
		if target then
			for _, wolf in ipairs(self:TamedWolves(player)) do
				if wolf.State == "Tamed" then
					wolf.AttackWolf = target
					wolf.AttackUntil = os.clock() + W.AttackSeconds
				end
			end
		end
	end
	if mode == "Wander" then
		for _, wolf in ipairs(self:TamedWolves(player)) do
			wolf.Anchor = wolf.Root.Position
		end
	end
end

function Animals:SetHarnessed(player, on, sledService)
	for _, wolf in ipairs(self:TamedWolves(player)) do
		if on then
			wolf.State = "Harness"
			wolf.SledService = sledService
		else
			wolf.State = "Tamed"
			wolf.SledService = nil
		end
	end
end

function Animals:CleanupPlayer(player)
	for _, wolf in ipairs(self.Wolves) do
		if wolf.TargetPlayer == player then
			wolf.TargetPlayer = nil
			if wolf.State == "Aggro" then
				wolf.State = "Roam"
			end
		end
	end
	local list = self._byOwner[player]
	if list then
		local copy = {}
		for i, w in ipairs(list) do
			copy[i] = w
		end
		for _, wolf in ipairs(copy) do
			self:_releaseWolf(wolf)
		end
	end
	self._byOwner[player] = nil
	self._commands[player] = nil
end

-- ---------- tags ----------

function Animals:_refreshTag(wolf)
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
		wolf.TagLabel.Text = "Tameable -- drop a fish"
		wolf.Tag.Enabled = true
	elseif wolf.Health < wolf.MaxHealth then
		wolf.TagLabel.Text = ("HP %d"):format(math.ceil(wolf.Health))
		wolf.Tag.Enabled = true
	else
		wolf.Tag.Enabled = false
	end
end

-- ---------- the step ----------

-- Wolves fear fire. A player sheltered by a lit campfire (or a
-- burning log) is not a target: the pack will circle the light
-- and stare, but it will not come in.
function Animals:_shelteredByFire(position)
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

function Animals:_nearestPlayer(position, maxDist)
	local best, bestDist = nil, maxDist
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local survival = self.Gameplay._survivals[player]
			if not (survival and survival.Dead) then
				local d = (root.Position - position).Magnitude
				if d < bestDist then
					best, bestDist = player, d
				end
			end
		end
	end
	return best, bestDist
end

function Animals:_moveToward(wolf, targetPos, speed, dt)
	local pos = wolf.Root.Position
	local to = Vector3.new(targetPos.X - pos.X, 0, targetPos.Z - pos.Z)
	local dist = to.Magnitude
	local moving = false
	if dist > 0.35 then
		local dir = to / dist
		wolf.Yaw = yawLerp(wolf.Yaw, yawOf(dir), dt * 7)
		local step = math.min(speed * dt, dist)
		pos = Vector3.new(pos.X + dir.X * step, pos.Y, pos.Z + dir.Z * step)
		moving = true
		wolf.WalkCycle += dt * speed * 0.9
	end
	if wolf.WalkTrack then
		if moving and not wolf.WalkTrack.IsPlaying then
			wolf.WalkTrack:Play(0.15)
		elseif not moving and wolf.WalkTrack.IsPlaying then
			wolf.WalkTrack:Stop(0.2)
		end
	end
	local groundY = self.Gameplay.World:GroundY(pos.X, pos.Z)
	local bob = moving and math.sin(wolf.WalkCycle * 2) * 0.07 or 0
	local y = groundY + wolf.GroundOffset + bob
	wolf.Model:PivotTo(CFrame.new(Vector3.new(pos.X, y, pos.Z)) * CFrame.Angles(0, wolf.Yaw + W.ModelYawOffset, 0))
	return dist
end

function Animals:_bitePlayer(wolf, player)
	local survival = self.Gameplay._survivals[player]
	if not survival then
		return
	end
	if wolf.BiteSound then
		wolf.BiteSound:Play()
	end
	local damage = W.BiteDamage * (wolf.Leader and W.LeaderDamageMult or 1)
	survival:Damage(damage)
	wolf.BiteCd = W.BiteCooldown
end

function Animals:_step(dt)
	local now = os.clock()
	-- Danger flag for the HUD: who is a wolf hunting right now?
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

	-- Pack respawns.
	for _, pack in pairs(self._packs) do
		if pack.RespawnAt and now >= pack.RespawnAt then
			pack.RespawnAt = nil
			if self:_spawnPack() == 0 then
				-- The 24-wolf cap (or a missing template) blocked
				-- it: stay pending and retry shortly instead of
				-- vanishing forever.
				pack.RespawnAt = now + 30
			end
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

		if wolf.Owner then
			local survival = self.Gameplay._survivals[wolf.Owner]
			if not wolf.Owner.Parent or (survival and survival.Dead) then
				self:_releaseWolf(wolf)
				continue
			end
		end

		if wolf.State == "Roam" then
			if think then
				local near, dist = self:_nearestPlayer(pos, W.WaryRange)
				if near then
					local aggroRange = isNight and W.AggroRangeNight or W.AggroRangeDay
					local nearRoot = near.Character and near.Character:FindFirstChild("HumanoidRootPart")
					local sheltered = nearRoot and self:_shelteredByFire(nearRoot.Position)
					if dist <= aggroRange and not sheltered then
						wolf.State = "Aggro"
						wolf.TargetPlayer = near
					else
						wolf.State = "Wary"
						wolf.TargetPlayer = near
					end
				end
				if not wolf.RoamTarget or (wolf.RoamTarget - pos).Magnitude < 2 then
					local a = math.random() * math.pi * 2
					local r = math.random() * W.RoamRadius
					wolf.RoamTarget = wolf.Home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
				end
			end
			if wolf.RoamTarget then
				self:_moveToward(wolf, wolf.RoamTarget, W.RoamSpeed, dt)
			end
		elseif wolf.State == "Wary" then
			local target = wolf.TargetPlayer
			local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
			if not root then
				wolf.State = "Roam"
			else
				local d = (root.Position - pos).Magnitude
				wolf.Yaw = yawLerp(wolf.Yaw, yawOf(horizontalDir(root.Position - pos)), dt * 7)
				local aggroRange = isNight and W.AggroRangeNight or W.AggroRangeDay
				if d <= aggroRange and not self:_shelteredByFire(root.Position) then
					wolf.State = "Aggro"
				elseif d > W.WaryRange + 10 then
					wolf.State = "Roam"
					wolf.TargetPlayer = nil
				end
				self:_moveToward(wolf, pos, 0, dt) -- hold ground, keep facing
			end
		elseif wolf.State == "Aggro" then
			local target = wolf.TargetPlayer
			local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
			if not root then
				wolf.State = "Roam"
				wolf.TargetPlayer = nil
			elseif think and self:_shelteredByFire(root.Position) then
				-- The prey reached the firelight: break off and
				-- circle instead. The pack waits you out.
				wolf.State = "Wary"
			else
				local d = self:_moveToward(wolf, root.Position, W.ChaseSpeed, dt)
				if d <= W.BiteRange and wolf.BiteCd <= 0 then
					self:_bitePlayer(wolf, target)
				end
				if think and d > 90 then
					wolf.State = "Roam"
					wolf.TargetPlayer = nil
				end
			end
		elseif wolf.State == "Weakened" then
			-- Hurt and hungry: no fight left. A dropped fish with
			-- an owner is a second chance (see _tryTame).
			if think then
				if not self:_tryTame(wolf) then
					if wolf.WeakSince and now - wolf.WeakSince > 30 then
						wolf.Health = math.min(60, wolf.Health + 5)
						if wolf.Health > W.TameHealth then
							wolf.State = "Roam"
							wolf.WeakSince = nil
							self:_refreshTag(wolf)
						end
					end
				end
			end
			self:_moveToward(wolf, pos, 0, dt)
		elseif wolf.State == "GoEat" then
			local fish = wolf.EatTarget
			if not fish or not fish.Parent then
				wolf.State = "Weakened"
				wolf.EatTarget = nil
			else
				local primary = fish:FindFirstChild("F1") or fish:FindFirstChildWhichIsA("BasePart", true)
				if not primary then
					wolf.State = "Weakened"
					wolf.EatTarget = nil
				else
					local d = self:_moveToward(wolf, primary.Position, 6, dt)
					if d <= 2.2 then
						wolf.EatTarget = nil
						self:_finishTame(wolf, fish)
					end
				end
			end
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
					local d = self:_moveToward(wolf, slotPos, W.HarnessSpeed, dt)
					if d > 26 then
						-- Fell too far behind the moving sled:
						-- snap back into formation.
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

function Animals:_stepTamed(wolf, dt, now, isNight)
	local owner = wolf.Owner
	local character = owner and owner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local pos = wolf.Root.Position

	-- An attack order outranks the standing mode until it ends.
	if wolf.AttackWolf then
		local prey = wolf.AttackWolf
		if prey.Health <= 0 or now > wolf.AttackUntil then
			wolf.AttackWolf = nil
		else
			local d = self:_moveToward(wolf, prey.Root.Position, W.ChaseSpeed + 1, dt)
			if d <= W.BiteRange and wolf.BiteCd <= 0 then
				wolf.BiteCd = 0.9
				if wolf.BiteSound then
					wolf.BiteSound:Play()
				end
				self:DamageWolf(prey, W.AttackDamage, owner)
			end
			return
		end
	end

	local mode = self._commands[owner] or "Follow"
	if mode == "Wander" then
		local anchor = wolf.Anchor or pos
		if (root.Position - anchor).Magnitude > 110 then
			anchor = root.Position
			wolf.Anchor = anchor
		end
		if not wolf.RoamTarget or (wolf.RoamTarget - pos).Magnitude < 2 then
			local a = math.random() * math.pi * 2
			local r = math.random() * 45
			wolf.RoamTarget = anchor + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		end
		self:_moveToward(wolf, wolf.RoamTarget, W.RoamSpeed + 1.5, dt)
	elseif mode == "Alert" then
		-- Stay close, watch, and howl toward trouble.
		local back = root.Position - horizontalDir(root.CFrame.LookVector) * 5
		if (pos - back).Magnitude > 3 then
			self:_moveToward(wolf, back, W.FollowSpeed, dt)
		end
		local threat = self:NearestWildWolf(pos, 60)
		if threat then
			wolf.Yaw = yawLerp(wolf.Yaw, yawOf(horizontalDir(threat.Root.Position - pos)), dt * 7)
			self:_moveToward(wolf, pos, 0, dt)
			if now >= wolf.NextHowl then
				wolf.NextHowl = now + 6
				wolf.HowlUntil = now + 1.6
				self:_refreshTag(wolf)
			end
		end
	else -- Follow (and Attack with no live order)
		local back = horizontalDir(root.CFrame.LookVector) * -1
		local right = Vector3.new(-back.Z, 0, back.X)
		local row = math.floor((wolf.SlotIndex - 1) / 2)
		local side = (wolf.SlotIndex % 2 == 1) and -1 or 1
		if wolf.SlotIndex == 1 then
			side = 0
		end
		local slot = root.Position + back * (3.5 + row * 2.2) + right * (side * 1.7)
		local d = self:_moveToward(wolf, slot, W.FollowSpeed, dt)
		if d > 70 then
			self:_placeAt(wolf, slot)
		end
	end
end

return Animals
