local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local DragSystem = require(Modules:WaitForChild("DragSystem"))
local SurvivalPlayer = require(script.Parent:WaitForChild("SurvivalPlayer"))
local FishSystem = require(script.Parent:WaitForChild("FishSystem"))
local Weapons = require(script.Parent:WaitForChild("Weapons"))
local TrackMarks = require(script.Parent:WaitForChild("TrackMarks"))

local Gameplay = {}
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
	self.Clock = clock
	self.Temperature = temperature
	self._survivals = {}
	self._sprinting = {}
	self._tutorial = {}
	self._burning = {}
	self._spread = {}
	self.Fish = FishSystem.new(self)
	self.Weapons = Weapons.new(self)
	self._foot = {}
	self._published = {}
	self.LogsFolder = nil
	self._setSprinting = nil
	return self
end

function Gameplay:Start()
	local logsFolder = Instance.new("Folder")
	logsFolder.Name = "Logs"
	logsFolder.Parent = workspace
	self.LogsFolder = logsFolder

	TrackMarks.Init(self.World)
	self.Fish:Start()

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

	local remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage

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
	placeBlueprint.OnServerEvent:Connect(function(player, position)
		if typeof(position) ~= "Vector3" then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		if (position - root.Position).Magnitude > Config.Blueprint.PlaceRange then
			return
		end
		self.World:PlaceBlueprint(position.X, position.Z)
	end)

	self.Weapons:BuildTools()

	self.World.OnBlueprintAdd = function(player, bp)
		return self:_addLogToBlueprint(player, bp)
	end
	self.World.OnBlueprintBuilt = function(bp)
		for player in pairs(bp.Contributors) do
			self:_markTutorial(player, "Built")
		end
	end
	self.World.OnLightAttempt = function(player, fire)
		return self:_lightFire(player, fire)
	end

	local eatFish = Instance.new("RemoteEvent")
	eatFish.Name = "EatFish"
	eatFish.Parent = remotes
	eatFish.OnServerEvent:Connect(function(player, fish)
		self.Fish:Eat(player, fish)
	end)

	local toolAim = Instance.new("RemoteEvent")
	toolAim.Name = "ToolAim"
	toolAim.Parent = remotes
	toolAim.OnServerEvent:Connect(function(player, toolName, hitInstance, hitPosition)
		self.Weapons:OnToolAim(player, toolName, hitInstance, hitPosition)
	end)

	setSprinting.OnServerEvent:Connect(function(player, value)
		self._sprinting[player] = value == true
	end)

	self.Clock.OnPhaseChanged:Connect(function(phase, day)
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
		self:_releaseLogs(player)
		self._survivals[player] = nil
		self._sprinting[player] = nil
		self._tutorial[player] = nil
		self._published[player] = nil
		self._foot[player] = nil
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

function Gameplay:_makeSurvival(player)
	local survival = SurvivalPlayer.new(self.Clock, self.Temperature)
	survival.OnDied:Connect(function()
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
	end
end

function Gameplay:_onCharacter(player, character)
	self:_releaseLogs(player)
	self._survivals[player] = self:_makeSurvival(player)
	self._sprinting[player] = false

	local humanoid = character:WaitForChild("Humanoid")
	humanoid.WalkSpeed = Config.Survival.WalkSpeed

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

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Drag"
	prompt.ObjectText = "WoodLog"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = logPart
	prompt.Triggered:Connect(function(player)
		if log:GetAttribute("OnSled") then
			return
		end
		if log:GetAttribute("Burning") == true then
			-- Burning wood is hands-off: no grabbing it back.
			return
		end
		if logPart:GetAttribute("DraggedBy") == player.UserId then
			DragSystem.Stop(player, logPart)
		elseif logPart:GetAttribute("DraggedBy") == nil then
			if DragSystem.Start(player, logPart) then
				prompt.ActionText = "Drop"
			end
		end
	end)
end

function Gameplay:Update(dt)
	local world = self.World
	self.Fish:Cook(dt)
	self:_feedFires()
	self:_tickBurning(dt)
	self:_spreadFire(dt)
	TrackMarks.Update(dt)
	for player, survival in pairs(self._survivals) do
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
