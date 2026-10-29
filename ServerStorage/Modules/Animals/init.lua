local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local AnimationModule = require(Modules:WaitForChild("AnimationModule"))
local SoundModule = require(Modules:WaitForChild("SoundModule"))
local TrackMarks = require(script.Parent:WaitForChild("TrackMarks"))

local PathfindingService = game:GetService("PathfindingService")

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
	self._behaviours = {} -- per-player: Passive / Neutral / Attack
	self._packs = {}
	self._nextPackId = 0
	self._dangerSet = {}
	self._dangerTick = 0
	return self
end

function Animals:_population()
	local day = self.Gameplay.Clock and self.Gameplay.Clock:GetDay() or 1
	return W.Population[math.min(day, #W.Population)]
end

function Animals:_wildCount()
	local n = 0
	for _, wolf in ipairs(self.Wolves) do
		if not wolf.Owner then
			n += 1
		end
	end
	return n
end

function Animals:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Animals"
	folder.Parent = workspace
	self.Folder = folder

	local assets = ReplicatedStorage:WaitForChild("Assets", 5)
	local animalsFolder = assets and assets:FindFirstChild("Animals")
	self.Template = (animalsFolder and animalsFolder:FindFirstChild("WolfModel"))
		or (assets and assets:FindFirstChild("WolfModel", true))
	if not self.Template then
		warn("[Arctic] Animals: no Assets.Animals.WolfModel - no wolves will spawn")
		return
	end

	-- Fill the world to today's population target.
	local target = self:_population().Total
	local guard = 0
	while self:_wildCount() < target and guard < 12 do
		guard += 1
		if self:_spawnPack() == 0 then
			break
		end
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
	local attackTrack = nil
	local idleTrack = nil
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
	-- His animations, all optional and loaded if present:
	-- WalkAnim loops while moving, IdleAnim while standing,
	-- AttackAnim fires on a bite.
	local function loadAnim(name)
		local anim = wolf:FindFirstChild(name, true)
		if not (anim and anim:IsA("Animation")) then
			return nil
		end
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
			return animator:LoadAnimation(anim)
		end)
		return ok and track or nil
	end
	walkTrack = loadAnim(AnimationModule.Wolf.Walk)
	if walkTrack then
		walkTrack.Looped = true
		wolf:SetAttribute("WalkTrackReady", true)
	end
	attackTrack = loadAnim(AnimationModule.Wolf.Attack)
	-- Idle is a ROTATION, not one clip: every Idle* animation in
	-- the model joins the wolf's play set and he cycles them.
	local idleTracks = {}
	local function addIdle(name)
		local track = loadAnim(name)
		if track then
			track.Looped = true
			table.insert(idleTracks, track)
		end
	end
	for _, idleName in ipairs(AnimationModule.Wolf.Idle) do addIdle(idleName) end
	for _, d in ipairs(wolf:GetDescendants()) do
		if d:IsA("Animation") and d.Name:sub(1, 4) == "Idle"
			and d.Name ~= "Idle_1_Anim" and d.Name ~= "Idle_2_Anim"
			and d.Name ~= "Idle_3_Anim" and d.Name ~= "IdleAnim"
		then
			addIdle(d.Name)
		end
	end
	idleTrack = idleTracks[1]
	local biteSound = wolf:FindFirstChild(SoundModule.Wolf.Bite, true)
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
		AttackTrack = attackTrack,
		IdleTrack = idleTrack,
		IdleTracks = idleTracks,
		Mood = "Wandering",
		MoodTarget = "",
		PlayUntil = 0,
		PlayTurn = 0,
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
		FishNeeded = nil,
		FishEaten = 0,
		RefuseUntil = 0,
		EatingUntil = nil,
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
	local function clearOf(x, z)
		-- Not in the lake, not on top of another pack, and never
		-- in sight of a player: packs arrive from far away.
		if lake then
			local dx = x - lake.X
			local dz = z - lake.Z
			if dx * dx + dz * dz < (lake.Radius + 25) * (lake.Radius + 25) then
				return false
			end
		end
		for _, pack in pairs(self._packs) do
			if pack.Home then
				local dx = x - pack.Home.X
				local dz = z - pack.Home.Z
				if dx * dx + dz * dz < W.PackSeparation * W.PackSeparation then
					return false
				end
			end
		end
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				local dx = x - root.Position.X
				local dz = z - root.Position.Z
				if dx * dx + dz * dz < 140 * 140 then
					return false
				end
			end
		end
		return true
	end
	for _ = 1, 24 do
		local angle = math.random() * math.pi * 2
		local dist = math.random(120, math.max(140, radius - 40))
		local x = math.cos(angle) * dist
		local z = math.sin(angle) * dist
		if clearOf(x, z) then
			return Vector3.new(x, 0, z)
		end
	end
	-- Crowded world: accept a farther-out point unchecked.
	local angle = math.random() * math.pi * 2
	return Vector3.new(math.cos(angle) * (radius - 30), 0, math.sin(angle) * (radius - 30))
end

function Animals:_spawnPack()
	if not self.Template then
		return 0
	end
	-- World population cap (Ajay): never more than MaxAlive
	-- wolves in the world at once, wild or tamed.
	local room = math.min(W.MaxAlive - #self.Wolves, self:_population().Total - self:_wildCount())
	if room <= 0 then
		return 0
	end
	self._nextPackId += 1
	local packId = self._nextPackId
	local home = self:_packSpawnPosition()
	local pop = self:_population()
	local count = math.min(math.random(pop.PackMin, pop.PackMax), room)
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
		if i == 1 and count >= 2 then
			-- The pack leader: bigger pool, harder bite. (A lone
			-- wolf is just a wolf -- no leader buff solo.)
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

-- A noise in the open (a sick player's cough): wild wolves in
-- earshot turn toward whoever made it, and if he's too far for
-- their eyes they trot over to look. Attention, not instant
-- aggro -- the ordinary Wary/Aggro rules still decide, and
-- firelight still protects him. Wolves mid-tame (GoEat) and
-- wolves already hunting are not distracted.
function Animals:NoiseAt(position, player, radius)
	local now = os.clock()
	for _, wolf in ipairs(self.Wolves) do
		if not wolf.Owner and wolf.Health > 0 and not wolf.Removed
			and wolf.State ~= "GoEat" and wolf.State ~= "Aggro"
		then
			if (wolf.Root.Position - position).Magnitude <= radius then
				wolf.State = "Wary"
				wolf.TargetPlayer = player
				wolf.WarySince = now
				wolf.NoisePos = position
				wolf.NoiseUntil = now + Config.Sickness.CoughInvestigateSeconds
			end
		end
	end
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
		self:_killWolf(wolf, attacker)
		return
	end
	-- Crossing into tameable range rolls the fish price on ANY
	-- damage source (fire included) -- otherwise a wolf burned
	-- down to tameable range never got a price rolled and the
	-- tame fallback charged him 1 fish, leader or not.
	if not wolf.Owner and wolf.Health <= W.TameHealth and wolf.FishNeeded == nil then
		wolf.FishNeeded = (wolf.Leader or math.random() < W.TwoFishChance) and 2 or 1
		wolf.FishEaten = 0
		wolf.TameableSince = os.clock()
		if attacker then
			self.Gameplay:Notify(attacker, "It's weak -- drop a fish to tame it!")
		end
	end
	if not wolf.Owner and attacker then
		-- The whole pack answers an attack -- except a wolf who
		-- has already noticed a fish: he keeps going for it.
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

function Animals:_killWolf(wolf, attacker)
	-- Phase 3 pelts: a wild kill drops pelts where it fell
	-- (Pelts module, owned by Gameplay). Tamed dogs drop
	-- nothing -- Pelts checks Owner itself, this is just
	-- the hook, and it must not break the kill flush below.
	if self.Gameplay and self.Gameplay.Pelts then
		pcall(function()
			self.Gameplay.Pelts:OnWolfKilled(wolf, attacker)
		end)
	end
	wolf.Health = 0
	if wolf.Owner then
		self:_removeFromOwner(wolf)
	end
	wolf.Model:Destroy()
	-- The record leaves self.Wolves at the next _step flush, not
	-- here: kills land mid-iteration (burn ticks, pack fights),
	-- and removing from the array there silently skips the next
	-- wolf's step.
	wolf.Removed = true
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
	-- A hurt wolf scans for a fish somebody dropped: a loose
	-- fish whose LastDragger is set. Unless he was betrayed
	-- recently -- a snatched fish means no trust for a while.
	if os.clock() < (wolf.RefuseUntil or 0) then
		return false
	end
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

-- Eating is a timed act, and it can be ruined: snatch the fish
-- back mid-tame and the wolf turns on you (and refuses fish for
-- a while). A full fish is eaten whole; some wolves need two.
function Animals:_stepGoEat(wolf, dt, now)
	local fish = wolf.EatTarget
	local primary = fish and fish.Parent and (fish:FindFirstChild("F1") or fish:FindFirstChildWhichIsA("BasePart", true))
	if not primary then
		wolf.EatTarget = nil
		wolf.EatingUntil = nil
		wolf.State = wolf.TargetPlayer and "Aggro" or "Roam"
		return
	end
	local draggedBy = primary:GetAttribute("DraggedBy")
	if draggedBy ~= nil then
		self:_failTame(wolf, draggedBy)
		return
	end
	if wolf.EatingUntil then
		self:_moveToward(wolf, wolf.Root.Position, 0, dt)
		if now >= wolf.EatingUntil then
			wolf.EatingUntil = nil
			wolf.EatTarget = nil
			self:_consumeFish(wolf, fish)
		end
		return
	end
	local d = self:_moveSmart(wolf, primary.Position, 6, dt)
	if d <= 2.2 then
		wolf.EatingUntil = now + W.EatSeconds
		if wolf.BiteSound then
			wolf.BiteSound:Play()
		end
	end
end

function Animals:_failTame(wolf, draggedBy)
	wolf.EatTarget = nil
	wolf.EatingUntil = nil
	wolf.RefuseUntil = os.clock() + W.TameRefuseSeconds
	local grabber = typeof(draggedBy) == "number" and Players:GetPlayerByUserId(draggedBy) or nil
	wolf.State = grabber and "Aggro" or "Roam"
	wolf.TargetPlayer = grabber
	if grabber then
		self.Gameplay:Notify(grabber, "Tame failed -- the wolf turned on you!")
	end
end

function Animals:_consumeFish(wolf, fish)
	local lastDragger = fish:GetAttribute("LastDragger")
	fish:Destroy()
	wolf.FishEaten = (wolf.FishEaten or 0) + 1
	local needed = wolf.FishNeeded or 1
	if wolf.FishEaten < needed then
		local owner = lastDragger and Players:GetPlayerByUserId(lastDragger)
		if owner then
			self.Gameplay:Notify(owner, ("It wants another fish! (%d/%d)"):format(wolf.FishEaten, needed))
		end
		wolf.State = "Roam"
		return
	end
	self:_claimWolf(wolf, lastDragger)
end

function Animals:_claimWolf(wolf, lastDragger)
	local owner = lastDragger and Players:GetPlayerByUserId(lastDragger)
	wolf.FishNeeded = nil
	wolf.FishEaten = 0
	wolf.TameableSince = nil
	if not owner or self:Count(owner) >= W.TeamLimit then
		-- Fed but not claimed (nobody there, or their team is
		-- full): the wolf recovers and stays wild.
		wolf.Health = math.min(wolf.MaxHealth, wolf.Health + 40)
		wolf.State = "Roam"
		self:_refreshTag(wolf)
		return
	end
	wolf.Owner = owner
	wolf.State = "Tamed"
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

function Animals:SetBehaviour(player, behaviour)
	if behaviour ~= "Passive" and behaviour ~= "Neutral" and behaviour ~= "Attack" then
		return
	end
	self._behaviours[player] = behaviour
	player:SetAttribute("WolfBehaviour", behaviour)
end

function Animals:SetCommand(player, mode, targetPos)
	if mode == "Attack" and self._behaviours[player] == "Passive" then
		-- Passive wolves never attack, even on a direct order.
		self.Gameplay:Notify(player, "Wolf is Passive -- it will not attack.")
		return
	end
	self._commands[player] = mode
	player:SetAttribute("WolfCommand", mode)
	if mode == "Attack" and typeof(targetPos) == "Vector3" then
		-- You command from where you stand: the order point must
		-- be near YOU, not anywhere on the map.
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or (targetPos - root.Position).Magnitude > 70 then
			return
		end
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
	self._behaviours[player] = nil
end

-- ---------- tags ----------

-- Play time: the wolf stops wandering, picks a (different)
-- idle animation from his set, and slowly turns while it
-- plays. This is what keeps wild wolves looking alive.
function Animals:_enterPlaying(wolf, now)
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

-- Ajay's mood table, kept on every wolf and mirrored to model
-- attributes so it is visible/manageable in Studio:
--   Wandering / Watching (target) / Attacking (target) /
--   Eating / Playing / Following / Pulling
function Animals:_syncMood(wolf)
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

-- Fire hurts wolves exactly like players: stand in it and you
-- burn (1.5/s for 5-7s, flames included).
function Animals:_burnCheck(wolf, dt, now)
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

-- Push a point out of every fire's scare disc (wolves path
-- AROUND fire, never through it).
function Animals:_pushOutOfFire(position)
	local x, z = position.X, position.Z
	for _, fire in ipairs(self.Gameplay.World.Fires or {}) do
		if fire.Lit and fire.Fuel > 0 then
			local anchor = fire.CookingPart or fire.Core
			if anchor then
				local radius = W.FireScareRadius + 1
				local dx = x - anchor.Position.X
				local dz = z - anchor.Position.Z
				local d2 = dx * dx + dz * dz
				if d2 < radius * radius then
					local d = math.sqrt(d2)
					if d < 0.01 then
						dx, dz, d = 1, 0, 1
					end
					x = anchor.Position.X + dx / d * radius
					z = anchor.Position.Z + dz / d * radius
				end
			end
		end
	end
	return Vector3.new(x, position.Y, z)
end

function Animals:_computePath(from, to)
	local path = PathfindingService:CreatePath({
		AgentRadius = 1.2,
		AgentHeight = 3,
		AgentCanJump = true,
		AgentCanClimb = false,
	})
	local ok = pcall(function()
		path:ComputeAsync(from, to)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return nil
	end
	local points = {}
	for _, waypoint in ipairs(path:GetWaypoints()) do
		table.insert(points, self:_pushOutOfFire(waypoint.Position))
	end
	if #points < 2 then
		return nil
	end
	return points
end

-- Long moves go through real pathfinding (around trees, rocks,
-- and fire); short moves go direct. Returns the true remaining
-- distance to the final target.
function Animals:_moveSmart(wolf, targetPos, speed, dt)
	local pos = wolf.Root.Position
	local targetDist = (Vector3.new(targetPos.X, 0, targetPos.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
	if targetDist < 8 then
		wolf.Path = nil
		self:_moveToward(wolf, targetPos, speed, dt)
		return targetDist
	end
	local now = os.clock()
	-- A failed compute used to retry EVERY frame (pathfinding
	-- is expensive, and a wolf on rough snow would stutter).
	-- Cache the failure briefly and walk direct meanwhile.
	if now < (wolf.PathFailUntil or 0) then
		self:_moveToward(wolf, targetPos, speed, dt)
		return targetDist
	end
	local path = wolf.Path
	if not path or (path.TargetPos - targetPos).Magnitude > 8 or now > path.ExpiresAt then
		local points = self:_computePath(pos, targetPos)
		if points then
			wolf.Path = { Points = points, Index = 2, TargetPos = targetPos, ExpiresAt = now + 5 }
			path = wolf.Path
		else
			wolf.Path = nil
			path = nil
			wolf.PathFailUntil = now + 1.5
		end
	end
	if not path then
		self:_moveToward(wolf, targetPos, speed, dt)
		return targetDist
	end
	while path.Index <= #path.Points do
		local wp = path.Points[path.Index]
		local dx = wp.X - pos.X
		local dz = wp.Z - pos.Z
		if dx * dx + dz * dz < 2.6 then
			path.Index += 1
		else
			break
		end
	end
	if path.Index > #path.Points then
		wolf.Path = nil
		self:_moveToward(wolf, targetPos, speed, dt)
	else
		self:_moveToward(wolf, path.Points[path.Index], speed, dt)
	end
	return targetDist
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
	if wolf.IdleTrack then
		if not moving and not wolf.IdleTrack.IsPlaying then
			wolf.IdleTrack:Play(0.25)
		elseif moving and wolf.IdleTrack.IsPlaying then
			wolf.IdleTrack:Stop(0.15)
		end
	end
	-- Paw prints: a pressed mark every stride while moving.
	if moving then
		wolf.MarkAcc = (wolf.MarkAcc or 0) + speed * dt
		if wolf.MarkAcc >= 2.2 then
			wolf.MarkAcc = 0
			wolf.MarkSide = -(wolf.MarkSide or 1)
			local right = Vector3.new(math.cos(wolf.Yaw), 0, -math.sin(wolf.Yaw))
			local paw = Vector3.new(pos.X, pos.Y, pos.Z) + right * (0.35 * wolf.MarkSide)
			TrackMarks.SpawnPaw(paw, wolf.Yaw, 10)
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
	if wolf.AttackTrack and not wolf.AttackTrack.IsPlaying then
		wolf.AttackTrack:Play(0.05)
	end
	local damage = W.BiteDamage * (wolf.Leader and W.LeaderDamageMult or 1)
	survival:Damage(damage)
	wolf.BiteCd = W.BiteCooldown
end

function Animals:_step(dt)
	local now = os.clock()
	-- Flush deferred wolf removals before iterating, and drop
	-- pack records whose last wolf is gone -- a dead pack's home
	-- otherwise blocks its 130-stud separation disc forever and
	-- spawn placement degrades to the unchecked fallback.
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

	-- Population top-up: the world refills toward the day's
	-- target (checked on a slow tick; spawns land far away, so
	-- nothing pops in next to a player).
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

		-- A hurt wild wolf who notices a dropped fish diverts to
		-- it from ANY state -- even mid-chase. And one left alone
		-- long enough slowly heals back over the tameable line
		-- (the offer expires).
		if not wolf.Owner and wolf.State ~= "GoEat" and wolf.Health <= W.TameHealth then
			if think then
				self:_tryTame(wolf)
			end
			if (wolf.State == "Roam" or wolf.State == "Wary")
				and wolf.TameableSince and now - wolf.TameableSince > 20
			then
				wolf.Health += 7.5 * dt
				if wolf.Health > W.TameHealth then
					wolf.FishNeeded = nil
					wolf.FishEaten = 0
					wolf.TameableSince = nil
					self:_refreshTag(wolf)
				end
			end
		end

		self:_syncMood(wolf)

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
						wolf.WarySince = now
					end
				end
				if not wolf.RoamTarget or (wolf.RoamTarget - pos).Magnitude < 2 then
					-- Arrived: about a third of the time he stops
					-- to PLAY (idle animation, slow turn) before
					-- wandering on -- wolves live, not just patrol.
					if wolf.RoamTarget and math.random() < 0.34 then
						wolf.RoamTarget = nil
						self:_enterPlaying(wolf, now)
					else
						-- Wander the pack's 50x50 home range, spread
						-- evenly over it (sqrt keeps it off-center).
						local a = math.random() * math.pi * 2
						local r = math.sqrt(math.random()) * W.RoamRadius
						wolf.RoamTarget = wolf.Home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
					end
				end
			end
			if wolf.RoamTarget then
				-- Long wanders pathfind (around trees/rocks/fire);
				-- _moveSmart falls back to direct under 8 studs.
				self:_moveSmart(wolf, wolf.RoamTarget, W.RoamSpeed, dt)
			end
		elseif wolf.State == "Playing" then
			-- Still watching for trouble while he plays.
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
				wolf.State = "Roam"
			else
				local d = (root.Position - pos).Magnitude
				wolf.Yaw = yawLerp(wolf.Yaw, yawOf(horizontalDir(root.Position - pos)), dt * 7)
				local aggroRange = isNight and W.AggroRangeNight or W.AggroRangeDay
				local investigating = false
				if d <= aggroRange and not self:_shelteredByFire(root.Position) then
					wolf.State = "Aggro"
					wolf.NoisePos = nil
				elseif d > W.WaryRange + 10 then
					if wolf.NoisePos and now < (wolf.NoiseUntil or 0) then
						-- Heard something (a cough): trot to the
						-- spot for a look; his senses take over
						-- once he's close or the trail goes cold.
						investigating = true
						self:_moveToward(wolf, wolf.NoisePos, W.RoamSpeed * 1.6, dt)
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
					-- The old code held ground here FOREVER while a
					-- player watched from wary range: the wolf just
					-- stood doing his idle animation. Now he paces
					-- around the player after 3s, and after 8s of
					-- no aggro he gives up and wanders off.
					if not wolf.WarySince then
						wolf.WarySince = now
					end
					local waryFor = now - wolf.WarySince
					if waryFor > 8 then
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
						self:_moveSmart(wolf, wolf.WaryPaceTarget, W.RoamSpeed, dt)
					else
						self:_moveToward(wolf, pos, 0, dt) -- hold ground, keep facing
					end
				end
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
				local d = self:_moveSmart(wolf, root.Position, W.ChaseSpeed, dt)
				if d <= W.BiteRange and wolf.BiteCd <= 0 then
					self:_bitePlayer(wolf, target)
				end
				if think and d > 90 then
					wolf.State = "Roam"
					wolf.TargetPlayer = nil
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
					local d = self:_moveSmart(wolf, slotPos, W.HarnessSpeed, dt)
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
	if mode == "Stop" then
		-- Stop: stay exactly where you are, do nothing.
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
		self:_moveToward(wolf, wolf.RoamTarget, W.RoamSpeed + 1.5, dt)
	elseif mode == "Alert" then
		-- Alert (new rule): stay close, and if a wild wolf
		-- comes within 25 studs, howl AND go attack it.
		-- Passive wolves howl only, never attack.
		local back = root.Position - horizontalDir(root.CFrame.LookVector) * 5
		if (pos - back).Magnitude > 3 then
			self:_moveToward(wolf, back, W.FollowSpeed, dt)
		end
		local threat = self:NearestWildWolf(pos, 25)
		if threat then
			wolf.Yaw = yawLerp(wolf.Yaw, yawOf(horizontalDir(threat.Root.Position - pos)), dt * 7)
			if now >= wolf.NextHowl then
				wolf.NextHowl = now + 6
				wolf.HowlUntil = now + 1.6
				self:_refreshTag(wolf)
			end
			if self._behaviours[owner] ~= "Passive" and wolf.AttackWolf ~= threat then
				wolf.AttackWolf = threat
				wolf.AttackUntil = now + W.AttackSeconds
			end
		else
			self:_moveToward(wolf, pos, 0, dt)
		end
	else -- Follow (and Attack with no live order)
		local back = horizontalDir(root.CFrame.LookVector) * -1
		local right = Vector3.new(-back.Z, 0, back.X)
		local row = math.floor((wolf.SlotIndex - 1) / 2)
		local side = (wolf.SlotIndex % 2 == 1) and -1 or 1
		if wolf.SlotIndex == 1 then
			side = 0
		end
		local slot = root.Position + back * (8 + row * 2.2) + right * (side * 1.7)
		local d = self:_moveSmart(wolf, slot, W.FollowSpeed, dt)
		if d > 70 then
			self:_placeAt(wolf, slot)
		end
	end
end

return Animals
