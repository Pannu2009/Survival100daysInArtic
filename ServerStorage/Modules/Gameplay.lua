local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPack = game:GetService("StarterPack")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local DragSystem = require(Modules:WaitForChild("DragSystem"))
local SurvivalPlayer = require(script.Parent:WaitForChild("SurvivalPlayer"))
local FishSystem = require(script.Parent:WaitForChild("FishSystem"))

local Gameplay = {}
Gameplay.__index = Gameplay

local function findWoodPart(model)
	return model:FindFirstChild("WoodPart", true)
		or model:FindFirstChild("Trunk", true)
		or model:FindFirstChildWhichIsA("BasePart", true)
end

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

local function lengthAxis(size)
	if size.Y >= size.X and size.Y >= size.Z then
		return Vector3.yAxis, size.Y
	elseif size.X >= size.Z then
		return Vector3.xAxis, size.X
	else
		return Vector3.zAxis, size.Z
	end
end

local function setLength(part, axisVec, newLength)
	local s = part.Size
	if axisVec == Vector3.yAxis then
		part.Size = Vector3.new(s.X, newLength, s.Z)
	elseif axisVec == Vector3.xAxis then
		part.Size = Vector3.new(newLength, s.Y, s.Z)
	else
		part.Size = Vector3.new(s.X, s.Y, newLength)
	end
end

local function rotateAround(model, center, rotation)
	local cf = model:GetPivot()
	model:PivotTo(CFrame.new(center) * rotation * CFrame.new(-center) * cf)
end

function Gameplay.new(world, clock, temperature)
	local self = setmetatable({}, Gameplay)
	self.World = world
	self.Clock = clock
	self.Temperature = temperature
	self._survivals = {}
	self._sprinting = {}
	self._lighterFuel = {}
	self._tutorial = {}
	self._burning = {}
	self._spread = {}
	self.Fish = FishSystem.new(self)
	self._digReady = {}
	self._axeReady = {}
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

	self:_buildAxe()
	self:_buildShovel()
	self:_buildBlueprintTool()
	self:_buildLighter()

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
		self:_onToolAim(player, toolName, hitInstance, hitPosition)
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
		self._lighterFuel[player] = nil
		self._tutorial[player] = nil
		self._published[player] = nil
		self._digReady[player] = nil
		self._axeReady[player] = nil
	end)
end

function Gameplay:_buildAxe()
	-- Ajay's own axe from Assets.Tools wins when it exists.
	local assets = ReplicatedStorage:WaitForChild("Assets", 5)
	local toolsFolder = assets and assets:FindFirstChild("Tools")
	local axeTemplate = toolsFolder and toolsFolder:FindFirstChild("Axe")
	if axeTemplate and axeTemplate:IsA("Tool") then
		local axe = axeTemplate:Clone()
		axe.Name = "Axe"
		axe.CanBeDropped = false
		-- Normalize his model so it always equips and activates: strip
		-- stray scripts, unanchor every part, weld loose parts to the
		-- Handle, and if no part is named Handle, promote the biggest
		-- part — a Tool with no Handle can never be held, so clicks
		-- silently do nothing.
		local handle = nil
		local biggest = nil
		local biggestVolume = -1
		local parts = {}
		for _, d in ipairs(axe:GetDescendants()) do
			if d:IsA("Script") or d:IsA("LocalScript") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = false
				table.insert(parts, d)
				if d.Name == "Handle" then
					handle = d
				end
				local volume = d.Size.X * d.Size.Y * d.Size.Z
				if volume > biggestVolume then
					biggestVolume = volume
					biggest = d
				end
			end
		end
		if not handle and biggest then
			biggest.Name = "Handle"
			handle = biggest
		end
		if handle then
			for _, part in ipairs(parts) do
				if part ~= handle then
					part.Massless = true
					part.CanCollide = false
					local welded = false
					for _, c in ipairs(part:GetDescendants()) do
						if c:IsA("WeldConstraint") or c:IsA("Weld") then
							welded = true
							break
						end
					end
					if not welded then
						local weld = Instance.new("WeldConstraint")
						weld.Part0 = handle
						weld.Part1 = part
						weld.Parent = part
					end
				end
			end
		end
		axe.RequiresHandle = handle ~= nil
		axe.Parent = StarterPack
		return
	end

	local axe = Instance.new("Tool")
	axe.Name = "Axe"
	axe.RequiresHandle = true
	axe.CanBeDropped = false

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.45, 3.4, 0.45)
	handle.Material = Enum.Material.Wood
	handle.Color = Color3.fromRGB(110, 78, 48)
	handle.Parent = axe

	local axeHead = Instance.new("Part")
	axeHead.Name = "Head"
	axeHead.Size = Vector3.new(0.3, 1.1, 1.6)
	axeHead.CFrame = CFrame.new(0, 1.5, 0)
	axeHead.Material = Enum.Material.Metal
	axeHead.Color = Color3.fromRGB(150, 155, 160)
	axeHead.CanCollide = false
	axeHead.Massless = true
	axeHead.Parent = axe

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = axeHead
	weld.Parent = axeHead

	axe.Parent = StarterPack
end

function Gameplay:_buildShovel()
	local shovel = Instance.new("Tool")
	shovel.Name = "Shovel"
	shovel.RequiresHandle = true
	shovel.CanBeDropped = false

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 3.6, 0.4)
	handle.Material = Enum.Material.Wood
	handle.Color = Color3.fromRGB(110, 78, 48)
	handle.Parent = shovel

	local blade = Instance.new("Part")
	blade.Name = "Blade"
	blade.Size = Vector3.new(1.1, 1.4, 0.18)
	blade.CFrame = CFrame.new(0, -2.2, 0)
	blade.Material = Enum.Material.Metal
	blade.Color = Color3.fromRGB(150, 155, 160)
	blade.CanCollide = false
	blade.Massless = true
	blade.Parent = shovel

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = blade
	weld.Parent = blade

	shovel.Parent = StarterPack
end

function Gameplay:_buildBlueprintTool()
	local tool = Instance.new("Tool")
	tool.Name = "Blueprint"
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.28, 3.2, 0.28)
	handle.Material = Enum.Material.Wood
	handle.Color = Color3.fromRGB(234, 160, 0)
	handle.Parent = tool

	tool.Parent = StarterPack
end

function Gameplay:_buildLighter()
	-- Ajay's own lighter from Assets.Tools wins when it exists. His
	-- script inside it (flame effects and such) is KEPT on purpose —
	-- unlike the axe, nothing is stripped here. Gameplay still owns
	-- the fuel and ignition logic through the Activated connection in
	-- _onCharacter; his script only has to handle the visuals.
	local assets = ReplicatedStorage:WaitForChild("Assets", 5)
	local toolsFolder = assets and assets:FindFirstChild("Tools")
	local lighterTemplate = toolsFolder and toolsFolder:FindFirstChild("Lighter")
	if lighterTemplate and lighterTemplate:IsA("Tool") then
		local lighter = lighterTemplate:Clone()
		lighter.Name = "Lighter"
		lighter.CanBeDropped = false
		-- Same normalization as the axe, minus script stripping:
		-- unanchor every part, guarantee a Handle, weld loose parts.
		local handle = nil
		local biggest = nil
		local biggestVolume = -1
		local parts = {}
		for _, d in ipairs(lighter:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = false
				table.insert(parts, d)
				if d.Name == "Handle" then
					handle = d
				end
				local volume = d.Size.X * d.Size.Y * d.Size.Z
				if volume > biggestVolume then
					biggestVolume = volume
					biggest = d
				end
			end
		end
		if not handle and biggest then
			biggest.Name = "Handle"
			handle = biggest
		end
		if handle then
			for _, part in ipairs(parts) do
				if part ~= handle then
					part.Massless = true
					part.CanCollide = false
					local welded = false
					for _, c in ipairs(part:GetDescendants()) do
						if c:IsA("WeldConstraint") or c:IsA("Weld") then
							welded = true
							break
						end
					end
					if not welded then
						local weld = Instance.new("WeldConstraint")
						weld.Part0 = handle
						weld.Part1 = part
						weld.Parent = part
					end
				end
			end
		end
		lighter.RequiresHandle = handle ~= nil
		lighter.Parent = StarterPack
		return
	end

	local tool = Instance.new("Tool")
	tool.Name = "Lighter"
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 0.9, 0.3)
	handle.Material = Enum.Material.Metal
	handle.Color = Color3.fromRGB(220, 90, 30)
	handle.Parent = tool

	tool.Parent = StarterPack
end

-- Dig one snow column at (tx, tz). The target comes from the
-- player's center-dot aim; every check runs server-side.
function Gameplay:_digAt(player, tx, tz)
	local now = os.clock()
	if now < (self._digReady[player] or 0) then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	if not character:FindFirstChild("Shovel") then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local dx = tx - root.Position.X
	local dz = tz - root.Position.Z
	if dx * dx + dz * dz > Config.Digging.AimRange * Config.Digging.AimRange then
		return
	end
	self._digReady[player] = now + Config.Digging.Cooldown

	if self.World:IsNearStructure(tx, tz, Config.Digging.SafeRadius) then
		return
	end

	local hit = self.World:TerrainRaycastDown(tx, tz)
	if not hit or hit.Material ~= Enum.Material.Snow then
		return
	end

	local terrain = workspace:WaitForChild("Terrain")
	local center = hit.Position - Vector3.new(0, Config.Digging.Radius * 0.35, 0)
	terrain:FillBall(center, Config.Digging.Radius, Enum.Material.Air)
	self:_markTutorial(player, "Dug")
end

-- Center-dot tool aim: the client raycasts the middle of the
-- screen and reports what the dot is on; the server decides what
-- happens. The shovel digs where the dot points; the lighter
-- lights the exact log or fire the dot is on. This is the pattern
-- future dot tools plug into.
function Gameplay:_onToolAim(player, toolName, hitInstance, hitPosition)
	if typeof(hitPosition) ~= "Vector3" then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if toolName == "Shovel" then
		if not character:FindFirstChild("Shovel") then
			return
		end
		-- The claimed point must sit on the real terrain column.
		local hit = self.World:TerrainRaycastDown(hitPosition.X, hitPosition.Z)
		if not hit or (hit.Position - hitPosition).Magnitude > 3.5 then
			return
		end
		self:_digAt(player, hitPosition.X, hitPosition.Z)
	elseif toolName == "Lighter" then
		if not character:FindFirstChild("Lighter") then
			return
		end
		if (hitPosition - root.Position).Magnitude > Config.Lighter.AimRange then
			return
		end
		-- Dot on a log: that exact log catches.
		if typeof(hitInstance) == "Instance" and hitInstance:IsA("BasePart") then
			local model = hitInstance.Parent
			if model and model.Parent == self.LogsFolder
				and model:GetAttribute("Burnable")
				and model:GetAttribute("Burning") ~= true
				and not model:GetAttribute("OnSled")
			then
				local lp = getLogPart(model)
				if lp and lp:GetAttribute("DraggedBy") == nil then
					self:_igniteLog(player, model)
					return
				end
			end
		end
		-- Dot on a campfire: light that fire.
		for _, fire in ipairs(self.World.Fires) do
			if not fire.Lit and fire.Fuel > 0
				and (fire.Core.Position - hitPosition).Magnitude <= 4
			then
				self:_lightFire(player, fire)
				return
			end
		end
	end
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
		LighterFuel = self._lighterFuel[player] or 0,
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
	if self._lighterFuel[player] == nil then
		self._lighterFuel[player] = Config.Lighter.StartFuel
	end
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
			self:_onAxeActivated(player)
		end)
	end
	-- Shovel and Lighter no longer act from server-side Activated:
	-- they are center-dot tools now (see _onToolAim).
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
	local fuel = self._lighterFuel[player] or 0
	if fuel < Config.Lighter.LightCost then
		return false
	end
	self._lighterFuel[player] = fuel - Config.Lighter.LightCost
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
	local fuel = self._lighterFuel[player] or 0
	if fuel < Config.Lighter.LightCost then
		return false
	end
	self._lighterFuel[player] = fuel - Config.Lighter.LightCost
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

function Gameplay:_dropLogPieces(treeModel, spotPos)
	local template = self.World.WoodLogTemplate
	if not template then
		return
	end
	local woodPart = findWoodPart(treeModel)
	if not woodPart then
		return
	end
	local woodSize = woodPart.Size
	local axisVec, woodLength = lengthAxis(woodSize)
	local isBig = woodLength >= Config.Log.BigTreeLength
	local targetLength = isBig and Config.Log.BigPieceTargetLength or Config.Log.PieceTargetLength
	local maxPieces = isBig and Config.Log.BigTreeMaxPieces or Config.Log.MaxPieces
	local pieceCount = math.clamp(math.round(woodLength / targetLength), 1, maxPieces)
	local pieceLength = woodLength / pieceCount

	for _ = 1, pieceCount do
		local log = template:Clone()
		local logPart = getLogPart(log)
		if logPart then
			log.Name = "WoodLog"
			logPart.Size = woodSize
			setLength(logPart, axisVec, pieceLength)
			for _, part in ipairs(log:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = true
					if part == logPart then
						part.Anchored = true
					else
						part.Anchored = false
						local weld = Instance.new("WeldConstraint")
						weld.Part0 = logPart
						weld.Part1 = part
						weld.Parent = part
					end
				end
			end
			log.Parent = self.LogsFolder

			if axisVec == Vector3.yAxis then
				log:PivotTo(log:GetPivot() * CFrame.Angles(0, 0, math.rad(90)))
			end
			local pivot = log:GetPivot()
			local yaw = CFrame.Angles(0, math.random() * math.pi * 2, 0)
			log:PivotTo(CFrame.new(pivot.Position) * yaw * (pivot - pivot.Position))

			local ox = spotPos.X + (math.random() - 0.5) * 3
			local oz = spotPos.Z + (math.random() - 0.5) * 3
			self.World:SnapPartToGround(log, logPart, ox, oz)

			self:_attachDragPrompt(log)
			self:_refreshLog(log)
		end
	end
end

function Gameplay:_shakeTree(tree)
	if tree:GetAttribute("Shaking") or tree:GetAttribute("Falling") then
		return
	end
	tree:SetAttribute("Shaking", true)
	task.spawn(function()
		local pos = tree:GetPivot().Position
		local base = Vector3.new(pos.X, self.World:GroundY(pos.X, pos.Z), pos.Z)
		local axis = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
		if axis.Magnitude < 0.1 then
			axis = Vector3.new(1, 0, 0)
		end
		axis = axis.Unit
		local tilt = CFrame.fromAxisAngle(axis, math.rad(2.5))
		rotateAround(tree, base, tilt)
		task.wait(0.07)
		if tree.Parent then
			rotateAround(tree, base, tilt:Inverse())
			local settle = CFrame.fromAxisAngle(axis, math.rad(-1.2))
			rotateAround(tree, base, settle)
			task.wait(0.06)
			if tree.Parent then
				rotateAround(tree, base, settle:Inverse())
			end
		end
		if tree.Parent then
			tree:SetAttribute("Shaking", false)
		end
	end)
end

function Gameplay:_fellTree(tree)
	tree:SetAttribute("Falling", true)
	local spotPos = tree:GetPivot().Position
	task.spawn(function()
		local base = Vector3.new(spotPos.X, self.World:GroundY(spotPos.X, spotPos.Z), spotPos.Z)
		local axis = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
		if axis.Magnitude < 0.1 then
			axis = Vector3.new(1, 0, 0)
		end
		axis = axis.Unit
		local total = math.rad(math.random(72, 86))
		local steps = 16
		local previous = 0
		for i = 1, steps do
			if not tree.Parent then
				return
			end
			local t = i / steps
			local angle = total * t * t
			rotateAround(tree, base, CFrame.fromAxisAngle(axis, angle - previous))
			previous = angle
			task.wait(0.03)
		end
		if not tree.Parent then
			return
		end
		local bounce = CFrame.fromAxisAngle(axis, math.rad(-4))
		rotateAround(tree, base, bounce)
		task.wait(0.07)
		if not tree.Parent then
			return
		end
		rotateAround(tree, base, bounce:Inverse())
		self:_dropLogPieces(tree, spotPos)
		tree:Destroy()
	end)
end


function Gameplay:_onAxeActivated(player)
	local now = os.clock()
	if now < (self._axeReady[player] or 0) then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	if not character:FindFirstChild("Axe") then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	self._axeReady[player] = now + Config.Tree.ChopCooldown

	local candidates = {}
	local treesFolder = self.World.TreesFolder
	if treesFolder then
		for _, tree in ipairs(treesFolder:GetChildren()) do
			if not tree:GetAttribute("Falling") then
				-- Range is measured to the nearest point of the tree's
				-- bounding box, not its pivot: his tree models are tall
				-- and their pivots sit high, so pivot distance put big
				-- trees out of ChopRange even when he stood at the trunk.
				local cf, size = tree:GetBoundingBox()
				local localPos = cf:PointToObjectSpace(root.Position)
				local closest = cf:PointToWorldSpace(Vector3.new(
					math.clamp(localPos.X, -size.X / 2, size.X / 2),
					math.clamp(localPos.Y, -size.Y / 2, size.Y / 2),
					math.clamp(localPos.Z, -size.Z / 2, size.Z / 2)
				))
				local distance = (closest - root.Position).Magnitude
				if distance <= Config.Tree.ChopRange then
					table.insert(candidates, { model = tree, distance = distance, point = closest })
				end
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)

	local target = nil
	local origin = root.Position + Vector3.new(0, 1, 0)
	for _, candidate in ipairs(candidates) do
		local direction = candidate.point - origin
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		-- Terrain is excluded: trees stand ON terrain, and a snow bump
		-- between the player and the trunk was silently eating swings.
		-- Rocks, cabins and props still block the line of sight.
		rayParams.FilterDescendantsInstances = { character, candidate.model, workspace.Terrain }
		rayParams.IgnoreWater = true
		local hit = workspace:Raycast(origin, direction, rayParams)
		if not hit or hit.Distance >= direction.Magnitude - 2 then
			target = candidate.model
			break
		end
	end
	if not target then
		return
	end

	local remaining = (target:GetAttribute("Health") or Config.Tree.Health) - 1
	if remaining > 0 then
		target:SetAttribute("Health", remaining)
		self:_shakeTree(target)
		return
	end

	self:_fellTree(target)
	self:_markTutorial(player, "Felled")
end

function Gameplay:Update(dt)
	local world = self.World
	self.Fish:Cook(dt)
	self:_feedFires()
	self:_tickBurning(dt)
	self:_spreadFire(dt)
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

		survival:Update(dt, context)
		self:_syncAttributes(player)
	end
end

return Gameplay
