local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local DragSystem = require(Modules:WaitForChild("DragSystem"))
local SurvivalPlayer = require(script.Parent:WaitForChild("SurvivalPlayer"))
local FishSystem = require(script.Parent:WaitForChild("FishSystem"))
local Animals = require(script.Parent:WaitForChild("Animals"))
-- Phase 3 systems, one per module. Kids is a child module
-- UNDER Animals (Animals/Kids.lua), loaded from the parent
-- ModuleScript -- not a sibling file.
local Kids = require(script.Parent:WaitForChild("Animals"):WaitForChild("Kids"))
local Sleep = require(script.Parent:WaitForChild("Sleep"))
local Shelters = require(script.Parent:WaitForChild("Shelters"))
local Pelts = require(script.Parent:WaitForChild("Pelts"))
local Merchant = require(script.Parent:WaitForChild("Merchant"))
local Coal = require(script.Parent:WaitForChild("Coal"))
local Weapons = require(script.Parent:WaitForChild("Weapons"))
local TrackMarks = require(script.Parent:WaitForChild("TrackMarks"))
local Economy = require(script.Parent:WaitForChild("Economy"))
local Aegis = require(script.Parent:WaitForChild("Aegis"))

local Gameplay = {}

-- Remote positions arrive from clients: a NaN component poisons
-- every magnitude comparison downstream (NaN > x is false, so
-- range checks PASS on garbage). Reject non-finite vectors at
-- the sink, same rule as the fishing SyncBar hardening.
local function finiteVector(v)
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z
		and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6
end
Gameplay.__index = Gameplay

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
	self.Merchant = Merchant.new(self)
	self.Coal = Coal.new(self)
	self._sleepBagMultiplierGranted = false
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
	-- Death is final for a run: no automatic respawning. Characters
	-- are loaded manually, once per player, in _setupPlayer; a
	-- deliberate revive system can opt back in via _reviving.
	Players.CharacterAutoLoads = false

	local logsFolder = Instance.new("Folder")
	logsFolder.Name = "Logs"
	logsFolder.Parent = workspace
	self.LogsFolder = logsFolder

	TrackMarks.Init(self.World)
	self.Fish:Start()
	self.Animals:Start()
	-- Phase 3 setup: all six systems start here, after the
	-- world is built (SurvivalServer builds before Start).
	self.Sleep:Start()
	self.Shelters:Start()
	self.Pelts:Start()
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
		-- Phase 3 seam: the client names the structure; anything
		-- not in the registry falls back to the campfire.
		local structureId = "Campfire"
		if typeof(structureName) == "string" and Config.Structures[structureName] then
			structureId = structureName
		end
		-- Session limits (Ajay, post-playtest): 1 campfire per
		-- SESSION (server-wide), 1 sleeping bag per PLAYER.
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
		-- One player may only have 3 live ghosts: an unbuilt
		-- blueprint is a full model + prompt + billboard, and the
		-- fires/blueprints lists are iterated every tick, so
		-- uncapped placement is a map-flooding grief.
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
		-- Tutorial credit is the CAMPFIRE build (Day 1); Phase 3
		-- structures branch on bp.StructureId here.
		if bp.StructureId == nil or bp.StructureId == "Campfire" then
			for player in pairs(bp.Contributors) do
				self:_markTutorial(player, "Built")
			end
		elseif bp.StructureId == "SleepingBag" then
			-- Phase 3: a built bag becomes a sleepable bag,
			-- and the FIRST bag built on the server grants
			-- the design's +1 sleeping-bag multiplier, once.
			local model, anchor = self.World:CreateStructure("SleepingBag", bp.Position.X, bp.Position.Z, false)
			if model and anchor then
				local owner = bp.PlacedBy
				if not owner then
					for pl in pairs(bp.Contributors) do owner = pl break end
				end
				self.Sleep:RegisterBag(model, anchor, owner)
			end
			if not self._sleepBagMultiplierGranted then
				self._sleepBagMultiplierGranted = true
				self.Clock:SetMultiplier(self.Clock:GetMultiplier() + 1)
				for _, player in ipairs(Players:GetPlayers()) do
					self:Notify(player, "Sleeping bag built! Day multiplier +1.")
				end
			end
		elseif bp.StructureId == "Shed" then
			-- Phase 3: a built shed becomes a storage shelter
			-- (warmth radius, see Shelters:WarmthBonusAt).
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
		if mode == "Follow" or mode == "Wander" or mode == "Alert" or mode == "Attack" then
			self.Animals:SetCommand(player, mode, targetPos)
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
				-- The client may send any part of the item (a fish
				-- is five parts); resolve to the marked part.
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
					return -- burning wood is hands-off
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
		-- Calm start: no storm or blizzard before Day 5.
		if day < Config.Temperature.FirstWeatherDay then
			self.Temperature:SetWeather("Clear")
			print(("[Arctic] %s of day %d - weather: %s"):format(phase, day, self.Temperature:GetWeather()))
			return
		end
		local roll = math.random()
		if roll < Config.Temperature.WeatherChance.Blizzard then
			self.Temperature:SetWeather("Blizzard")
		elseif roll < Config.Temperature.WeatherChance.Blizzard + Config.Temperature.WeatherChance.Storm then
			self.Temperature:SetWeather("Storm")
		else
			self.Temperature:SetWeather("Clear")
		end
		print(("[Arctic] %s of day %d - weather: %s"):format(phase, day, self.Temperature:GetWeather()))
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
	-- Publish only what the HUD displays, and only when it changed.
	-- The simulation keeps full float precision; clients get integers.
	local values = {
		Health = math.floor(survival.Health),
		Warmth = math.floor(survival.Warmth),
		Hunger = math.floor(survival.Hunger:Get()),
		IsSick = survival.IsSick,
		Coins = survival.Coins or 0,
		-- Stats only: Pelts / Fur / Medkits / KidCount are no longer
		-- published to the HUD. The systems still run internally
		-- (crafting, merchant, kids), they just are not shown.
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

-- BehaviorGuard feed: the game's real player actions, so the
-- metronome + adaptive bot checks have data. Warn-only, no
-- behavior change -- this just gives Aegis something to learn.
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
		-- Death is final, and a dead owner loses their kids:
		-- they wait where they stand, rescuable by anyone.
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

-- Day 1 tutorial: four personal steps, completable in any order;
-- the published step is the first one still missing (5 = done).
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
		-- Dead is dead: no fresh character and no survival reset.
		-- (A revive must set _reviving[player] before loading one.)
		character:Destroy()
		return
	end
	-- A revive that passed the check above consumes its flag
	-- HERE: without this, one medkit revive would leave the
	-- flag set and every later death would respawn for free.
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
	-- Shovel and Lighter no longer act from server-side Activated:
	-- they are center-dot tools now (see Weapons:OnToolAim).
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

-- Take one physical log for a fire or blueprint at `position`:
-- the log the player is dragging wins, else the nearest loose log.
-- A log is the wood — feeding and building both consume real logs.
function Gameplay:_takeLogNear(player, position)
	if not self.LogsFolder then
		return nil
	end

	local chosen = nil
	local draggedPart = DragSystem.GetPlayerItem(player)
	if draggedPart then
		local model = draggedPart.Parent
		if model
			and model.Parent == self.LogsFolder
			and not model:GetAttribute("OnSled")
			and model:GetAttribute("Burning") ~= true
			and (model:GetPivot().Position - position).Magnitude <= Config.Campfire.FeedRange
		then
			chosen = model
		end
	end

	if not chosen then
		local nearestDistance = Config.Campfire.FeedRange
		for _, log in ipairs(self.LogsFolder:GetChildren()) do
			local logPart = getLogPart(log)
			if logPart
				and not log:GetAttribute("OnSled")
				and log:GetAttribute("Burning") ~= true
				and logPart:GetAttribute("DraggedBy") == nil
			then
				local distance = (log:GetPivot().Position - position).Magnitude
				if distance <= nearestDistance then
					chosen = log
					nearestDistance = distance
				end
			end
		end
	end

	if not chosen then
		return nil
	end

	local logPart = getLogPart(chosen)
	if not logPart then
		return nil
	end

	local taken = {
		Weight = chosen:GetAttribute("Weight") or 0,
		BurnUnits = logBurnUnits(logPart),
	}
	if logPart:GetAttribute("DraggedBy") then
		DragSystem.ForceStop(logPart)
	end
	chosen:Destroy()
	return taken
end

function Gameplay:_addLogToBlueprint(player, bp)
	-- Prompt callbacks are client-triggered: re-check range here
	-- (MaxActivationDistance is a client-side property).
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - bp.Position).Magnitude > 14 then
		return nil
	end
	local taken = self:_takeLogNear(player, bp.Position)
	if not taken then
		return nil
	end
	bp.Contributors[player] = true
	return taken.Weight
end

-- Lighting costs lighter fuel (the lighter starts at 100). The fire
-- needs fuel inside it first — an empty fire cannot catch.
function Gameplay:_lightFire(player, fire)
	if fire.Lit or fire.Fuel <= 0 then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - fire.Core.Position).Magnitude > 14 then
		return false
	end
	if not self.Weapons:SpendFuel(player) then
		return false
	end
	fire.Lit = true
	-- Lighting the campfire is the Day 1 finale: the tutorial
	-- ends here, whatever order the steps happened in.
	for _, key in ipairs(TUTORIAL_ORDER) do
		self:_markTutorial(player, key)
	end
	return true
end

-- Ignite one burnable log with the lighter. A burning log is a
-- small fire of its own: it warms nearby players, cooks fish, and
-- burns for as long as its wood is worth, then it's gone.
function Gameplay:_igniteLog(player, log)
	local logPart = getLogPart(log)
	if not logPart or log:GetAttribute("Burning") == true then
		return false
	end
	if not self.Weapons:SpendFuel(player) then
		return false
	end
	self:_setBurning(log)
	return true
end

-- The shared catch-fire path: lighter ignition and fire spread
-- both land here. Burning wood leaves the drag system for good,
-- and sled cargo claimed by fire leaves the sled's books.
function Gameplay:_setBurning(log)
	local logPart = getLogPart(log)
	if not logPart or log:GetAttribute("Burning") == true then
		return
	end
	log:SetAttribute("Burning", true)
	DragSystem.ForceStop(logPart)
	if log:GetAttribute("OnSled") and self.Sleds then
		self.Sleds:RemovePiece(log)
	end
	self:_refreshLog(log)

	local flame = Instance.new("Fire")
	flame.Name = "BurnFlame"
	flame.Size = 5
	flame.Heat = 10
	flame.Parent = logPart
	local light = Instance.new("PointLight")
	light.Name = "BurnLight"
	light.Color = Color3.fromRGB(255, 176, 66)
	light.Range = 12
	light.Brightness = 1.5
	light.Parent = logPart

	self._burning[log] = logBurnUnits(logPart) * Config.Campfire.OpenBurnSecondsPerUnit
end

function Gameplay:_tickBurning(dt)
	for log, timeLeft in pairs(self._burning) do
		if not log.Parent then
			self._burning[log] = nil
		else
			timeLeft -= dt
			if timeLeft <= 0 then
				self._burning[log] = nil
				local logPart = getLogPart(log)
				if logPart and logPart:GetAttribute("DraggedBy") then
					DragSystem.ForceStop(logPart)
				end
				log:Destroy()
			else
				self._burning[log] = timeLeft
			end
		end
	end
end

-- Fire spread: a burnable log resting against burning wood builds
-- up exposure and catches too. Wood piles chain-react, and sled
-- cargo is not exempt — park a burning log against your storage
-- and the whole stock goes up. A log being dragged is held clear
-- of the pile, so it only catches once it's dropped.
function Gameplay:_spreadFire(dt)
	if not next(self._burning) then
		if next(self._spread) then
			table.clear(self._spread)
		end
		return
	end
	local burningParts = {}
	for log in pairs(self._burning) do
		local part = getLogPart(log)
		if part then
			table.insert(burningParts, part)
		end
	end
	for _, log in ipairs(self.LogsFolder:GetChildren()) do
		if log:GetAttribute("Burnable") and log:GetAttribute("Burning") ~= true then
			local part = getLogPart(log)
			if part and part:GetAttribute("DraggedBy") == nil then
				local touching = false
				for _, other in ipairs(burningParts) do
					if other ~= part then
						local gap = (other.Position - part.Position).Magnitude
							- (other.Size.Magnitude + part.Size.Magnitude) / 2
						if gap <= Config.Campfire.SpreadGap then
							touching = true
							break
						end
					end
				end
				if touching then
					local exposure = (self._spread[log] or 0) + dt
					if exposure >= Config.Campfire.SpreadSeconds then
						self._spread[log] = nil
						self:_setBurning(log)
					else
						self._spread[log] = exposure
					end
				elseif self._spread[log] then
					self._spread[log] = nil
				end
			end
		end
	end
end

-- Physical campfire feeding: a burnable log that lands inside a
-- fire's AddWoodBox is consumed as that fire's fuel.
function Gameplay:_feedFires()
	for _, fire in ipairs(self.World.Fires) do
		-- Phase 3 coal: a coal piece dropped in a fire's
		-- AddWoodBox burns as coal fuel (long + hot), not wood.
		if fire.AddBox and self.Coal and self.Coal.Folder then
			for _, piece in ipairs(self.Coal.Folder:GetChildren()) do
				if piece:GetAttribute("Coal") == true then
					local inBox = false
					if piece:IsA("BasePart") then
						local rel = fire.AddBox.CFrame:PointToObjectSpace(piece.Position)
						local half = fire.AddBox.Size / 2 + Vector3.new(0.3, 0.3, 0.3)
						inBox = math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
					end
					if inBox and piece:GetAttribute("DraggedBy") == nil then
						piece:Destroy()
						self.World:AddCoal(fire, 1)
					end
				end
			end
		end
		if fire.AddBox then
			for _, log in ipairs(self.LogsFolder:GetChildren()) do
				if not log:GetAttribute("OnSled") then
					local logPart = getLogPart(log)
					local inBox = false
					if logPart then
						local rel = fire.AddBox.CFrame:PointToObjectSpace(logPart.Position)
						local half = fire.AddBox.Size / 2 + Vector3.new(0.3, 0.3, 0.3)
						inBox = math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
					end
					if logPart and inBox then
						local units = logBurnUnits(logPart)
						if logPart:GetAttribute("DraggedBy") then
							DragSystem.ForceStop(logPart)
						end
						self._burning[log] = nil
						log:Destroy()
						if units > 0 then
							self.World:AddFuel(fire, units)
						end
					end
				end
			end
		end
	end
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
		-- A burning log shows no prompt at all: it can't be grabbed.
		prompt.Enabled = log:GetAttribute("Burning") ~= true
	end
end

function Gameplay:_attachDragPrompt(log)
	-- Grabbing is the client's GRAB/DROP button now (center-dot
	-- targeted, DragAction remote). No ProximityPrompt: this just
	-- marks the piece draggable.
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

-- Phase 3: one kid's rescue grants +1 day multiplier,
-- once per kid per run (server-wide, like the bag).
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

-- Phase 3: a medkit revives a dead player. The _reviving
-- flag lets exactly one fresh character through
-- _onCharacter, which clears it -- death stays final
-- for everyone without a medkit.
function Gameplay:ReviveWithMedkit(player)
	local survival = self._survivals[player]
	if not survival or not survival.Dead then
		return
	end
	self._reviving[player] = true
	player:LoadCharacter()
	self:Notify(player, "Medkit used -- you're back! Don't waste it.")
end

-- A small toast on one player's screen (caught / cooked /
-- tamed / warnings). Presentation lives on the client.
function Gameplay:Notify(player, text)
	if self._notifyRemote then
		self._notifyRemote:FireClient(player, text)
	end
end

-- Standing IN a fire is not warmth, it's ignition: lit
-- campfires and burning logs both count (horizontal distance --
-- the root rides ~3 studs over the core).
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

-- Sickness teeth: while sick, you cough every few seconds.
-- The cough is published (CoughCount attribute) so every
-- client can show it, and it is NOISE -- wolves in earshot
-- come to look (Animals:NoiseAt). Being sick by your own
-- fire is miserable; being sick in the open is dangerous.
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
			local flame = Instance.new("Fire")
			flame.Name = "BurnFlames"
			flame.Heat = 9
			flame.Size = 4
			flame.Parent = root
			state.Flame = flame
			self:Notify(player, "You're on fire!")
		end
		state.Until = now + math.random(Config.Campfire.BurnSecondsMin, Config.Campfire.BurnSecondsMax)
	end
	if state then
		if not root or now > (state.Until or 0) then
			if state.Flame then
				state.Flame:Destroy()
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
	self.Fish:Cook(dt)
	self.Fish:TickFishing(dt)
	-- Phase 3 ticks: sleep hunger/wake, kid follow/work/
	-- eat, coal deposit regrowth. Merchant restock is
	-- day-driven (OnDayAdvanced), not tick-driven.
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
		-- Day 2 begins: everyone gets the fishing rod. (Day 1 is
		-- the tutorial -- no rod, gentler hunger.)
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
			-- Phase 3 warmth: a sleeping bag you sleep in,
			-- and any shed/shelter you stand in, add bonus
			-- warmth on top of fire rate (SurvivalPlayer
			-- adds WarmthBonus to the fire rate).
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
		if root and not context.FireRate then
			for log in pairs(self._burning) do
				local lp = getLogPart(log)
				if lp and (lp.Position - root.Position).Magnitude <= Config.Campfire.BurningLogRadius then
					context.FireRate = Config.Campfire.BurningLogWarmRate
					break
				end
			end
		end

		self:_tickBurn(player, survival, root, dt)
		self:_tickCough(player, survival, root)

		-- Why is your warmth moving? Published for the HUD label
		-- under the warmth bar.
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

		-- Footprints: a pressed-snow mark every step while walking.
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
