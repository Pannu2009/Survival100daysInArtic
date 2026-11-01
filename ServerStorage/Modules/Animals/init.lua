local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local AnimationModule = require(Modules:WaitForChild("AnimationModule"))
local SoundModule = require(Modules:WaitForChild("SoundModule"))
local TrackMarks = require(script.Parent:WaitForChild("TrackMarks"))
local WolfPerception = require(script:WaitForChild("WolfPerception"))
local WolfNavigation = require(script:WaitForChild("WolfNavigation"))
local WolfTaming = require(script:WaitForChild("WolfTaming"))
local WolfCompanion = require(script:WaitForChild("WolfCompanion"))
local WolfBuilder = require(script:WaitForChild("WolfBuilder"))
local WolfPack = require(script:WaitForChild("WolfPack"))
local WolfCombat = require(script:WaitForChild("WolfCombat"))
local WolfSurvival = require(script:WaitForChild("WolfSurvival"))
local WolfBrain = require(script:WaitForChild("WolfBrain"))
local PathfindingService = game:GetService("PathfindingService")
local CollectionService = game:GetService("CollectionService")
local Spatial = require(Modules:WaitForChild("Spatial"))
local Animals = {}
Animals.__index = Animals
Animals._nearestPlayer = WolfPerception._nearestPlayer
Animals._aggroRange = WolfPerception._aggroRange
Animals._waryRange = WolfPerception._waryRange
Animals._fleeFrac = WolfPerception._fleeFrac
Animals._waryTimeout = WolfPerception._waryTimeout
Animals._canSee = WolfPerception._canSee
Animals._nearestVisiblePlayer = WolfPerception._nearestVisiblePlayer
Animals._nearestSprintingPlayer = WolfPerception._nearestSprintingPlayer
Animals._remember = WolfPerception._remember
Animals._shareThreat = WolfPerception._shareThreat
Animals._pushOutOfFire = WolfNavigation._pushOutOfFire
Animals._computePath = WolfNavigation._computePath
Animals._safeRetreat = WolfNavigation._safeRetreat
Animals._moveSmart = WolfNavigation._moveSmart
Animals._moveToward = WolfNavigation._moveToward
Animals.Feed = WolfTaming.Feed
Animals._tryTame = WolfTaming._tryTame
Animals._tryHungryEat = WolfTaming._tryHungryEat
Animals._stepGoEat = WolfTaming._stepGoEat
Animals._failTame = WolfTaming._failTame
Animals._consumeFood = WolfTaming._consumeFood
Animals._claimWolf = WolfTaming._claimWolf
Animals._loyaltyLevel = WolfCompanion._loyaltyLevel
Animals._stepTamed = WolfCompanion._stepTamed
Animals._buildWolf = WolfBuilder._buildWolf
Animals._placeAt = WolfBuilder._placeAt
Animals._packSpawnPosition = WolfPack._packSpawnPosition
Animals._spawnPack = WolfPack._spawnPack
Animals._packBonusMult = WolfPack._packBonusMult
Animals.DamageWolf = WolfCombat.DamageWolf
Animals._killWolf = WolfCombat._killWolf
Animals._biteWolf = WolfCombat._biteWolf
Animals._nearestEnemyWolf = WolfCombat._nearestEnemyWolf
Animals._bitePlayer = WolfCombat._bitePlayer
Animals._shelteredByFire = WolfSurvival._shelteredByFire
Animals._burnCheck = WolfSurvival._burnCheck
Animals._enterPlaying = WolfBrain._enterPlaying
Animals._syncMood = WolfBrain._syncMood
Animals._refreshTag = WolfBrain._refreshTag
Animals._step = WolfBrain._step
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
	self._behaviours = {}
	self._packs = {}
	self._nextPackId = 0
	self._dangerSet = {}
	self._dangerTick = 0
	self._enemyByModel = nil
	self._enemyByModelCount = -1
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
	self.VariantTemplates = {}
	if animalsFolder then
		for _, name in ipairs(W.VariantOrder or {}) do
			local v = animalsFolder:FindFirstChild(name)
			if v then
				self.VariantTemplates[name] = v
			end
		end
	end
	if not self.Template then
		warn("[Arctic] Animals: no Assets.Animals.WolfModel - no wolves will spawn")
		return
	end
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
function Animals:NoiseAt(position, player, radius)
	local now = os.clock()
	for _, wolf in ipairs(self.Wolves) do
		if not wolf.Owner and wolf.Health > 0 and not wolf.Removed
			and wolf.State ~= "GoEat" and wolf.State ~= "Aggro"
		then
			local hear = radius
			if wolf.Personality == "Curious" then hear = radius * 1.5 end
			if wolf.Personality == "Cautious" then hear = radius * 0.75 end
			if (wolf.Root.Position - position).Magnitude <= hear then
				wolf.State = "Wary"
				wolf.TargetPlayer = player
				wolf.WarySince = now
				wolf.NoisePos = position
				wolf.NoiseUntil = now + Config.Sickness.CoughInvestigateSeconds
				self:_remember(wolf, position)
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
function Animals:SetBehaviour(player, behaviour)
	if behaviour ~= "Passive" and behaviour ~= "Neutral" and behaviour ~= "Attack" then
		return
	end
	self._behaviours[player] = behaviour
	player:SetAttribute("WolfBehaviour", behaviour)
end
function Animals:SetCommand(player, mode, targetPos)
	if mode == "Attack" and self._behaviours[player] == "Passive" then
		self.Gameplay:Notify(player, "Wolf is Passive -- it will not attack.")
		return
	end
	self._commands[player] = mode
	player:SetAttribute("WolfCommand", mode)
	if mode == "Attack" and typeof(targetPos) == "Vector3" then
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




return Animals
