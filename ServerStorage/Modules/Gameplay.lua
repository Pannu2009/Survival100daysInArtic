local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local FireEffect = require(Modules:WaitForChild("FireEffect"))
local DragSystem = require(Modules:WaitForChild("DragSystem"))
local SurvivalPlayer = require(script.Parent:WaitForChild("SurvivalPlayer"))
local FishSystem = require(script.Parent:WaitForChild("FishSystem"))
local Animals = require(script.Parent:WaitForChild("Animals"))
local Kids = require(script.Parent:WaitForChild("Animals"):WaitForChild("Kids"))
local Sleep = require(script.Parent:WaitForChild("Sleep"))
local Shelters = require(script.Parent:WaitForChild("Shelters"))
local Pelts = require(script.Parent:WaitForChild("Pelts"))
local Meat = require(script.Parent:WaitForChild("Meat"))
local Sack = require(script.Parent:WaitForChild("Sack"))
local Merchant = require(script.Parent:WaitForChild("Merchant"))
local Coal = require(script.Parent:WaitForChild("Coal"))
local Weapons = require(script.Parent:WaitForChild("Weapons"))
local TrackMarks = require(script.Parent:WaitForChild("TrackMarks"))
local Economy = require(script.Parent:WaitForChild("Economy"))
local Aegis = require(script.Parent:WaitForChild("Aegis"))
local Network = require(Modules:WaitForChild("Network"))
local Leaderboards = require(script.Parent:WaitForChild("Leaderboards"))
local Gameplay = {}
local GameplayFire = require(script.Parent:WaitForChild("GameplayFire"))
local function finiteVector(v)
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z
		and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6
end
Gameplay.__index = Gameplay
Gameplay._takeLogNear = GameplayFire._takeLogNear
Gameplay._addLogToBlueprint = GameplayFire._addLogToBlueprint
Gameplay._lightFire = GameplayFire._lightFire
Gameplay._igniteLog = GameplayFire._igniteLog
Gameplay._setBurning = GameplayFire._setBurning
Gameplay._tickBurning = GameplayFire._tickBurning
Gameplay._spreadFire = GameplayFire._spreadFire
Gameplay._feedFires = GameplayFire._feedFires
local function getLogPart(log)
	return log:FindFirstChild("Log", true) or log:FindFirstChildWhichIsA("BasePart", true)
end
local function logWeight(logPart)
	local size = logPart.Size
	local weight = math.floor(size.X * size.Y * size.Z * Config.Log.WeightPerVolume + 0.5)
	return math.min(weight, Config.Log.MaxWeight)
end
local function logBurnUnits(logPart)
	return math.max(1, math.floor(logWeight(logPart) / Config.Log.KgPerBurnUnit + 0.5))
end
function Gameplay.new(world, clock, temperature)
	local self = setmetatable({}, Gameplay)
	self.World = world
	self.Economy = Economy
	Economy.Init(function(player) return self._survivals[player] end)
	self.Clock = clock
	self.Temperature = temperature
	self._survivals = {}
	self._sprinting = {}
	self._tutorial = {}
	self._burning = {}
	self._burn = {}
	self._cough = {}
	self._spread = {}
	self.Fish = FishSystem.new(self)
	self.Animals = Animals.new(self)
	self.Kids = Kids.new(self)
	self.Sleep = Sleep.new(self)
	self.Shelters = Shelters.new(self)
	self.Pelts = Pelts.new(self)
	self.Meat = Meat.new(self)
	self.Sack = Sack.new(self)
	self.Net = Network
	self.Merchant = Merchant.new(self)
	self.Coal = Coal.new(self)
	self._kidMultiplierGranted = {}
	self.Weapons = Weapons.new(self)
	self._foot = {}
	self._published = {}
	self._reviving = {}
	self._rodGranted = {}
	self.LogsFolder = nil
	self._setSprinting = nil
	return self
end
function Gameplay:Start()
	Players.CharacterAutoLoads = false
	local logsFolder = Instance.new("Folder")
	logsFolder.Name = "Logs"
	logsFolder.Parent = workspace
	self.LogsFolder = logsFolder
	TrackMarks.Init(self.World)
	self.Fish:Start()
	self.Animals:Start()
	self.Sleep:Start()
	self.Shelters:Start()
	self.Pelts:Start()
	self.Meat:Start()
	self.Merchant:Start()
	self.Coal:Start()
	self.Kids:Start()
	DragSystem.OnStopped = function(item)
		local model = item.Parent
		if model and model:IsA("Model") then
			self.World:SnapPartToGround(model, item, item.Position.X, item.Position.Z)
		end
		local prompt = item:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.ActionText = "Drag"
		end
	end
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	Network:InitServer()
	self.Net = Network
	self._runStart = os.clock()
	local setSprinting = Instance.new("RemoteEvent")
	setSprinting.Name = "SetSprinting"
	setSprinting.Parent = remotes
	self._setSprinting = setSprinting
	local openBuildMenu = Instance.new("RemoteEvent")
	openBuildMenu.Name = "OpenBuildMenu"
	openBuildMenu.Parent = remotes
	self._openBuildMenu = openBuildMenu
	local placeBlueprint = Instance.new("RemoteEvent")
	placeBlueprint.Name = "PlaceBlueprint"
	placeBlueprint.Parent = remotes
	Aegis.secure(placeBlueprint, { args = { "Vector3", "string?" } }, function(player, position, structureName)
		if typeof(position) ~= "Vector3" or not finiteVector(position) then
			return
		end
		local survival0 = self._survivals[player]
		if not survival0 or survival0.Dead then
			return
		end
		local structureId = "Campfire"
		if typeof(structureName) == "string" and Config.Structures[structureName] then
			structureId = structureName
		end
		if structureId == "Campfire" then
			local hasFire = self.World and #self.World.Fires >= 1
			if not hasFire and self.World then
				for _, bp in ipairs(self.World.Blueprints) do
					if bp.StructureId == "Campfire" then hasFire = true break end
				end
			end
			if hasFire then
				self:Notify(player, "Only 1 campfire can be built per session.")
				return
			end
		elseif structureId == "SleepingBag" then
			local hasBag = false
			if self.Sleep then
				for _, bag in pairs(self.Sleep.Bags) do
					if bag.Owner == player then hasBag = true break end
				end
			end
			if not hasBag and self.World then
				for _, bp in ipairs(self.World.Blueprints) do
					if bp.StructureId == "SleepingBag" and bp.PlacedBy == player then hasBag = true break end
				end
			end
			if hasBag then
				self:Notify(player, "You already have a sleeping bag (1 per player). Carry it instead.")
				return
			end
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		if (position - root.Position).Magnitude > Config.Blueprint.PlaceRange then
			return
		end
		local mine = 0
		for _, bp in ipairs(self.World.Blueprints) do
			if bp.PlacedBy == player then
				mine += 1
			end
		end
		if mine >= 3 then
			self:Notify(player, "Finish building first (3 blueprints max)")
			return
		end
		local bp = self.World:PlaceBlueprint(position.X, position.Z, structureId)
		if bp then
			bp.PlacedBy = player
		end
	end)
	self.Weapons:BuildTools()
	self.World.OnBlueprintAdd = function(player, bp)
		return self:_addLogToBlueprint(player, bp)
	end
	self.World.OnBlueprintBuilt = function(bp)
		if bp.StructureId == nil or bp.StructureId == "Campfire" then
			for player in pairs(bp.Contributors) do
				self:_markTutorial(player, "Built")
			end
		elseif bp.StructureId == "SleepingBag" then
			local model, anchor = self.World:CreateStructure("SleepingBag", bp.Position.X, bp.Position.Z, false)
			if model and anchor then
				local owner = bp.PlacedBy
				if not owner then
					for pl in pairs(bp.Contributors) do owner = pl break end
				end
				self.Sleep:RegisterBag(model, anchor, owner)
			end
			for _, player in ipairs(Players:GetPlayers()) do
				self:Notify(player, "Sleeping bag built!")
			end
		elseif bp.StructureId == "Shed" then
			local model, _anchor = self.World:CreateStructure("Shed", bp.Position.X, bp.Position.Z, false)
			if model then
				self.Shelters:RegisterBuiltShed(model, bp.Position.X, bp.Position.Z)
			end
		end
	end
	self.World.OnLightAttempt = function(player, fire)
		return self:_lightFire(player, fire)
	end
	local eatFish = Instance.new("RemoteEvent")
	eatFish.Name = "EatFish"
	eatFish.Parent = remotes
	Aegis.secure(eatFish, { args = { "Instance" } }, function(player, fish)
		self.Fish:Eat(player, fish)
	end)
	local eatMeat = Instance.new("RemoteEvent")
	eatMeat.Name = "EatMeat"
	eatMeat.Parent = remotes
	Aegis.secure(eatMeat, { args = { "Instance" } }, function(player, meat)
		self.Meat:Eat(player, meat)
	end)
	Network:ListenToClient("FeedWolf", function(player, data)
		self.Animals:Feed(player)
	end, { RateLimit = 5 })
	Network:ListenToClient("SleepBag", function(player, data)
		if not self.Sleep then
			return
		end
		if self.Sleep:IsSleeping(player) then
			self.Sleep:Wake(player, "You wake up.")
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local best = nil
		local bestDist = nil
		for _, bag in pairs(self.Sleep.Bags) do
			if bag.Anchor then
				local d = (root.Position - bag.Anchor.Position).Magnitude
				if d <= Config.Sleep.SleepRange and (not bestDist or d < bestDist) then
					best = bag
					bestDist = d
				end
			end
		end
		if best then
			self.Sleep:StartSleep(player, best)
		end
	end, { RateLimit = 5 })
	Network:ListenToClient("SackAction", function(player, data)
		local action = typeof(data) == "table" and data.Action or nil
		if action == "Store" then
			self.Sack:Store(player)
		elseif action == "Take" then
			self.Sack:Take(player)
		end
	end, { RateLimit = 10 })
	local toolAim = Instance.new("RemoteEvent")
	toolAim.Name = "ToolAim"
	toolAim.Parent = remotes
	Aegis.secure(toolAim, { args = { "string", "Instance", "Vector3" } }, function(player, toolName, hitInstance, hitPosition)
		if typeof(hitPosition) == "Vector3" and not finiteVector(hitPosition) then
			return
		end
		self.Weapons:OnToolAim(player, toolName, hitInstance, hitPosition)
	end)
	local notify = Instance.new("RemoteEvent")
	notify.Name = "Notify"
	notify.Parent = remotes
	self._notifyRemote = notify
	local fishingSync = Instance.new("RemoteEvent")
	fishingSync.Name = "FishingSync"
	fishingSync.Parent = remotes
	Aegis.secure(fishingSync, { args = { "number" }, rateLimit = { 40, 1 } }, function(player, barPos)
		if typeof(barPos) == "number" then
			self.Fish:SyncBar(player, barPos)
		end
	end)
	local wolfCommand = Instance.new("RemoteEvent")
	wolfCommand.Name = "WolfCommand"
	wolfCommand.Parent = remotes
	Aegis.secure(wolfCommand, { args = { "string", "Vector3?" } }, function(player, mode, targetPos)
		if mode == "Follow" or mode == "Wander" or mode == "Alert" or mode == "Attack" or mode == "Stop" then
			self.Animals:SetCommand(player, mode, targetPos)
		end
	end)
	local wolfBehaviour = Instance.new("RemoteEvent")
	wolfBehaviour.Name = "WolfBehaviour"
	wolfBehaviour.Parent = remotes
	Aegis.secure(wolfBehaviour, { args = { "string" } }, function(player, behaviour)
		if behaviour == "Passive" or behaviour == "Neutral" or behaviour == "Attack" then
			self.Animals:SetBehaviour(player, behaviour)
		end
	end)
	local dragAction = Instance.new("RemoteEvent")
	dragAction.Name = "DragAction"
	dragAction.Parent = remotes
	Aegis.secure(dragAction, { args = { "string", "Instance?" } }, function(player, action, target)
		if action == "Drop" then
			local item = DragSystem.GetPlayerItem(player)
			if item then
				DragSystem.Stop(player, item)
			end
		elseif action == "Grab" then
			if typeof(target) == "Instance" and target:IsA("BasePart") then
				local part = target
				if part:GetAttribute("Draggable") ~= true then
					local model = target.Parent
					if model and model:GetAttribute("Draggable") == true then
						for _, d in ipairs(model:GetDescendants()) do
							if d:IsA("BasePart") and d:GetAttribute("Draggable") == true then
								part = d
								break
							end
						end
					end
				end
				if part:GetAttribute("Draggable") ~= true then
					return
				end
				local model = part.Parent
				if model and model:GetAttribute("Burning") == true then
					return
				end
				DragSystem.Start(player, part)
			end
		end
	end)
	local kidAssign = Instance.new("RemoteEvent")
	kidAssign.Name = "KidAssignTask"
	kidAssign.Parent = remotes
	Aegis.secure(kidAssign, { args = { "number", "string" } }, function(player, kidId, task)
		if not self.Kids or typeof(kidId) ~= "number" or typeof(task) ~= "string" then return end
		for _, kid in ipairs(self.Kids.Kids) do
			if kid.Id == kidId then
				self.Kids:AssignTask(player, kid, task)
				break
			end
		end
	end)
	Aegis.secure(setSprinting, { args = { "boolean" } }, function(player, value)
		self._sprinting[player] = value == true
	end)
	self.Clock.OnPhaseChanged:Connect(function(phase, day)
		local function rollWeather(forDay)
			if forDay < Config.Temperature.FirstWeatherDay then
				return "Clear"
			end
			local roll = math.random()
			if roll < Config.Temperature.WeatherChance.Blizzard then
				return "Blizzard"
			elseif roll < Config.Temperature.WeatherChance.Blizzard + Config.Temperature.WeatherChance.Storm then
				return "Storm"
			end
			return "Clear"
		end
		self.Temperature:SetWeather(rollWeather(day))
		print(("[Arctic] %s of day %d - weather: %s"):format(phase, day, self.Temperature:GetWeather()))
		local nextDay = phase == "Night" and day + 1 or day
		local forecast = rollWeather(nextDay)
		self.Temperature:SetForecast(forecast)
		if forecast == "Blizzard" or forecast == "Storm" then
			for _, player in ipairs(Players:GetPlayers()) do
				self:Notify(player, forecast .. " incoming next phase -- stock up on wood!")
			end
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		self:_setupPlayer(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		self:_setupPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		self.Animals:CleanupPlayer(player)
		if self.Kids then
			self.Kids:CleanupPlayer(player)
		end
		if self.Sleep then
			self.Sleep:CleanupPlayer(player)
		end
		if self.Sack then
			self.Sack:CleanupPlayer(player)
		end
		if self.Pelts then
			self.Pelts:CleanupPlayer(player)
		end
		if self.Merchant then
			self.Merchant:CleanupPlayer(player)
		end
		self.Fish:_endSession(player)
		self._rodGranted[player] = nil
		self:_releaseLogs(player)
		self._survivals[player] = nil
		self._sprinting[player] = nil
		self._tutorial[player] = nil
		self._published[player] = nil
		self._foot[player] = nil
		self._burn[player] = nil
		self._cough[player] = nil
		self.Weapons:CleanupPlayer(player)
	end)
end
function Gameplay:_syncAttributes(player)
	local survival = self._survivals[player]
	if not survival then
		return
	end
	local values = {
		Health = math.floor(survival.Health),
		Warmth = math.floor(survival.Warmth),
		Hunger = math.floor(survival.Hunger:Get()),
		IsSick = survival.IsSick,
		Coins = survival.Coins or 0,
		KidPanel = self.Kids and self.Kids:PanelStringFor(player) or "",
		LighterFuel = self.Weapons:GetFuel(player),
		TutorialStep = self:_tutorialStep(player),
	}
	local published = self._published[player]
	if not published then
		published = {}
		self._published[player] = published
	end
	for name, value in pairs(values) do
		if published[name] ~= value then
			published[name] = value
			player:SetAttribute(name, value)
		end
	end
end
function Gameplay:RecordAction(player, action)
	Aegis.recordAction(player, action)
end
function Gameplay:_makeSurvival(player)
	local survival = SurvivalPlayer.new(self.Clock, self.Temperature)
	survival.OnSickChanged:Connect(function(isSick)
		if isSick then
			self:Notify(player, "You're sick -- get warm and rest. And quiet: coughing draws wolves.")
		else
			self:Notify(player, "You feel better.")
		end
	end)
	survival.OnDied:Connect(function()
		Leaderboards.RecordDays(player, self.Clock:GetDay())
		if self.Kids then
			self.Kids:OnOwnerGone(player)
		end
		self.Fish:_endSession(player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end)
	return survival
end
local TUTORIAL_ORDER = { "Felled", "Dug", "Built", "Lit" }
function Gameplay:_markTutorial(player, key)
	local flags = self._tutorial[player]
	if flags then
		flags[key] = true
	end
end
function Gameplay:_tutorialStep(player)
	local flags = self._tutorial[player]
	if not flags then
		return 1
	end
	for i, key in ipairs(TUTORIAL_ORDER) do
		if not flags[key] then
			return i
		end
	end
	return 5
end
function Gameplay:_setupPlayer(player)
	self._survivals[player] = self:_makeSurvival(player)
	self._sprinting[player] = false
	self.Weapons:SetupPlayer(player)
	if not self._tutorial[player] then
		self._tutorial[player] = {}
	end
	self:_syncAttributes(player)
	player.CharacterAdded:Connect(function(character)
		self:_onCharacter(player, character)
	end)
	if player.Character then
		self:_onCharacter(player, player.Character)
	elseif not (self._survivals[player] and self._survivals[player].Dead) then
		player:LoadCharacter()
	end
end
function Gameplay:_onCharacter(player, character)
	local existing = self._survivals[player]
	if existing and existing.Dead and not self._reviving[player] then
		character:Destroy()
		return
	end
	self._reviving[player] = nil
	self:_releaseLogs(player)
	self._survivals[player] = self:_makeSurvival(player)
	self._sprinting[player] = false
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.WalkSpeed = Config.Survival.WalkSpeed
	self._survivals[player]:BindHumanoid(humanoid)
	local root = character:WaitForChild("HumanoidRootPart")
	root.CFrame = CFrame.new(7, self.World:GroundY(7, 0) + 4, 0)
	local backpack = player:WaitForChild("Backpack")
	local playerAxe = backpack:WaitForChild("Axe", 5) or character:FindFirstChild("Axe")
	if playerAxe then
		playerAxe.Activated:Connect(function()
			self.Weapons:SwingAxe(player)
		end)
	end
	local playerBlueprint = backpack:WaitForChild("Blueprint", 5) or character:FindFirstChild("Blueprint")
	if playerBlueprint then
		playerBlueprint.Activated:Connect(function()
			if self._openBuildMenu then
				self._openBuildMenu:FireClient(player)
			end
		end)
	end
	self:_syncAttributes(player)
end
function Gameplay:_releaseLogs(player)
	DragSystem.StopPlayer(player)
end
function Gameplay:AttachDragPrompt(log)
	self:_attachDragPrompt(log)
	self:_refreshLog(log)
end
function Gameplay:ReleaseDraggedLogs(player)
	self:_releaseLogs(player)
end








function Gameplay:_refreshLog(log)
	local logPart = getLogPart(log)
	if not logPart then
		return
	end
	log:SetAttribute("Weight", logWeight(logPart))
	log:SetAttribute("Burnable", true)
	if log:GetAttribute("Burning") == nil then
		log:SetAttribute("Burning", false)
	end
	local prompt = logPart:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.ObjectText = "WoodLog " .. log:GetAttribute("Weight") .. "kg"
		prompt.Enabled = log:GetAttribute("Burning") ~= true
	end
end
function Gameplay:_attachDragPrompt(log)
	local logPart = getLogPart(log)
	if not logPart then
		return
	end
	log:SetAttribute("Draggable", true)
	logPart:SetAttribute("Draggable", true)
	local existing = logPart:FindFirstChildOfClass("ProximityPrompt")
	if existing then
		existing:Destroy()
	end
end
function Gameplay:GrantKidMultiplier(player, kidId)
	if self._kidMultiplierGranted[kidId] then
		return
	end
	self._kidMultiplierGranted[kidId] = true
	self.Clock:SetMultiplier(self.Clock:GetMultiplier() + 1)
	for _, other in ipairs(Players:GetPlayers()) do
		self:Notify(other, ("Kid rescued! Day multiplier +1 (now x%d)."):format(self.Clock:GetMultiplier()))
	end
end
function Gameplay:ReviveWithMedkit(player)
	local survival = self._survivals[player]
	if not survival or not survival.Dead then
		return
	end
	self._reviving[player] = true
	player:LoadCharacter()
	self:Notify(player, "Medkit used -- you're back! Don't waste it.")
end
function Gameplay:Notify(player, text)
	if self._notifyRemote then
		self._notifyRemote:FireClient(player, text)
	end
end
local function standingInFire(gameplay, position)
	for _, fire in ipairs(gameplay.World.Fires or {}) do
		if fire.Lit and fire.Fuel > 0 then
			local anchor = fire.CookingPart or fire.Core
			if anchor then
				local dx = anchor.Position.X - position.X
				local dz = anchor.Position.Z - position.Z
				if dx * dx + dz * dz <= Config.Campfire.BurnRadius * Config.Campfire.BurnRadius then
					return true
				end
			end
		end
	end
	for log in pairs(gameplay._burning) do
		if log and log.Parent then
			local lp = log:GetPivot().Position
			local dx = lp.X - position.X
			local dz = lp.Z - position.Z
			if dx * dx + dz * dz <= 2.2 * 2.2 then
				return true
			end
		end
	end
	return false
end
function Gameplay:_tickCough(player, survival, root)
	if not survival.IsSick or survival.Dead then
		self._cough[player] = nil
		return
	end
	local now = os.clock()
	local state = self._cough[player]
	if not state then
		state = { Next = now + Config.Sickness.CoughMinSeconds }
		self._cough[player] = state
	end
	if now >= state.Next then
		local span = Config.Sickness.CoughMaxSeconds - Config.Sickness.CoughMinSeconds
		state.Next = now + Config.Sickness.CoughMinSeconds + math.random() * span
		player:SetAttribute("CoughCount", (player:GetAttribute("CoughCount") or 0) + 1)
		if root then
			self.Animals:NoiseAt(root.Position, player, Config.Sickness.CoughRadius)
		end
	end
end
function Gameplay:_tickBurn(player, survival, root, dt)
	local now = os.clock()
	local state = self._burn[player]
	if root and standingInFire(self, root.Position) then
		if not state then
			state = { Acc = 0 }
			self._burn[player] = state
			local burnEmitters = FireEffect.AttachFire(root)
			for _, emitter in ipairs(burnEmitters) do
				emitter.Enabled = true
			end
			if #burnEmitters == 0 then
				local flame = Instance.new("Fire")
				flame.Name = "BurnFlames"
				flame.Heat = 9
				flame.Size = 4
				flame.Parent = root
				state.Flame = flame
			else
				state.Flames = burnEmitters
			end
			self:Notify(player, "You're on fire!")
		end
		state.Until = now + math.random(Config.Campfire.BurnSecondsMin, Config.Campfire.BurnSecondsMax)
	end
	if state then
		if not root or now > (state.Until or 0) then
			if state.Flame then
				state.Flame:Destroy()
			end
			if state.Flames then
				for _, emitter in ipairs(state.Flames) do
					if emitter.Parent then
						emitter:Destroy()
					end
				end
			end
			self._burn[player] = nil
			return
		end
		state.Acc += dt
		while state.Acc >= 1 do
			state.Acc -= 1
			survival:Damage(Config.Campfire.BurnDamagePerSecond)
		end
	end
end
function Gameplay:Update(dt)
	local world = self.World
	if not self._fastestRecorded and self.Clock:GetDay() >= 100 then
		self._fastestRecorded = true
		if not self._runStart then self._runStart = os.clock() end
		local elapsed = os.clock() - self._runStart
		for player, survival in pairs(self._survivals) do
			if survival and not survival.Dead then
				Leaderboards.RecordFastest100(player, elapsed)
			end
		end
	end
	self.Fish:Cook(dt)
	self.Meat:Cook(dt)
	self.Fish:TickFishing(dt)
	if self.Sleep then
		self.Sleep:Update(dt)
	end
	if self.Kids then
		self.Kids:Update(dt)
	end
	if self.Coal then
		self.Coal:Update(dt)
	end
	for _, fire in ipairs(world.Fires) do
		if self.Pelts then
			self.Pelts:EnsureCraftPrompt(fire)
		end
	end
	self:_feedFires()
	self:_tickBurning(dt)
	self:_spreadFire(dt)
	TrackMarks.Update(dt)
	for player, survival in pairs(self._survivals) do
		if not self._rodGranted[player] and self.Clock:GetDay() >= 2 then
			if self.Weapons:GiveTool(player, "FishingRod") then
				self._rodGranted[player] = true
			end
		end
		local context = { IsSprinting = self._sprinting[player] == true }
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local dragItem = DragSystem.GetPlayerItem(player)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local baseSpeed = self._sprinting[player] and Config.Survival.SprintSpeed or Config.Survival.WalkSpeed
			local factor = 1
			if dragItem then
				local w = logWeight(dragItem)
				factor = math.clamp(1 - w * Config.Log.DragSlowPerWeight, Config.Log.MinDragSpeedFactor, 1)
			end
			if self.Sleds then
				local pullWeight = self.Sleds:GetPullWeight(player)
				if pullWeight then
					factor = math.clamp(1 - pullWeight * Config.Sled.PullSlowPerWeight, Config.Sled.MinPullSpeedFactor, 1)
				end
			end
			humanoid.WalkSpeed = baseSpeed * factor
		end
		if root then
			local rate = world:WarmthRateAt(root.Position)
			if rate then
				context.FireRate = rate
			end
			local bonus = 0
			if self.Sleep then
				bonus += self.Sleep:GetWarmthBonus(player)
			end
			if self.Shelters then
				bonus += self.Shelters:WarmthBonusAt(root.Position)
			end
			if bonus > 0 then
				context.WarmthBonus = bonus
			end
		end
		if root then
			for log in pairs(self._burning) do
				local lp = getLogPart(log)
				if lp then
					local dx = lp.Position.X - root.Position.X
					local dz = lp.Position.Z - root.Position.Z
					if dx * dx + dz * dz <= Config.Campfire.BurningLogRadius * Config.Campfire.BurningLogRadius then
						context.FireRate = (context.FireRate or 0) + Config.Campfire.BurningLogWarmRate
					end
				end
			end
		end
		self:_tickBurn(player, survival, root, dt)
		self:_tickCough(player, survival, root)
		local warmState
		if survival.Warmth <= Config.Sickness.ColdWarmthThreshold then
			warmState = "Freezing"
		elseif context.FireRate then
			warmState = "By the fire"
		else
			warmState = "Losing warmth"
		end
		if survival._warmState ~= warmState then
			survival._warmState = warmState
			player:SetAttribute("WarmState", warmState)
		end
		if root then
			local foot = self._foot[player]
			if not foot then
				foot = { LastPos = root.Position, Dist = 0, Side = 1 }
				self._foot[player] = foot
			end
			local moved = (root.Position - foot.LastPos) * Vector3.new(1, 0, 1)
			foot.LastPos = root.Position
			if moved.Magnitude > 0 then
				foot.Dist += moved.Magnitude
				if foot.Dist >= Config.Tracks.FootStep then
					foot.Dist = 0
					foot.Side = -foot.Side
					local dir = moved.Unit
					local footName = foot.Side == 1 and "RightFoot" or "LeftFoot"
					local legName = foot.Side == 1 and "Right Leg" or "Left Leg"
					local footPart = character
						and (character:FindFirstChild(footName) or character:FindFirstChild(legName))
					local pos = footPart and footPart.Position
						or (root.Position + root.CFrame.RightVector * (0.4 * foot.Side))
					TrackMarks.SpawnFoot(pos, math.atan2(dir.X, dir.Z), Config.Tracks.FootLife)
				end
			end
		end
		survival:Update(dt, context)
		self:_syncAttributes(player)
	end
end
return Gameplay
