local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPack = game:GetService("StarterPack")
local Lighting = game:GetService("Lighting")

local SharedModules = ReplicatedStorage:WaitForChild("Modules")
local ServerModules = ServerStorage:WaitForChild("Modules")
local Config = require(SharedModules:WaitForChild("Config"))
local DayNightClock = require(ServerModules:WaitForChild("DayNightClock"))
local Temperature = require(ServerModules:WaitForChild("Temperature"))
local SurvivalPlayer = require(ServerModules:WaitForChild("SurvivalPlayer"))
local WorldGen = require(ServerModules:WaitForChild("WorldGen"))
local TerrainBuilder = require(ServerModules:WaitForChild("TerrainBuilder"))

local clock = DayNightClock.new()
local temperature = Temperature.new()

local survivals = {}
local sprinting = {}
local wood = {}
local campfireFuel = Config.Campfire.StartFuelSeconds

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local setSprinting = Instance.new("RemoteEvent")
setSprinting.Name = "SetSprinting"
setSprinting.Parent = remotes

local function randomSeed()
	local letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	local parts = {}
	for i = 1, 6 do
		local n = math.random(1, #letters)
		parts[i] = letters:sub(n, n)
	end
	return table.concat(parts)
end

local seedString = Config.World.DevSeed
if seedString == "" then
	seedString = randomSeed()
end
local layout = WorldGen.Generate(seedString)
TerrainBuilder.Build(layout)
ReplicatedStorage:SetAttribute("WorldSeed", layout.SeedString)
print("[Arctic] World seed: " .. layout.SeedString)

local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate:Destroy()
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { workspace:WaitForChild("Terrain") }

local function groundY(x, z)
	local result = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), groundParams)
	if result then
		return result.Position.Y
	end
	return 0
end

local treesFolder = Instance.new("Folder")
treesFolder.Name = "Trees"
treesFolder.Parent = workspace

local logsFolder = Instance.new("Folder")
logsFolder.Name = "Logs"
logsFolder.Parent = workspace

local dragging = {}

local assets = ReplicatedStorage:FindFirstChild("Assets")
local treeTemplate = assets and assets:FindFirstChild("Tree")
local woodLogTemplate = assets and assets:FindFirstChild("WoodLog")
if treeTemplate then
	print("[Arctic] Planting with Assets.Tree")
else
	warn("[Arctic] Assets.Tree not found - no trees will be planted")
end
if woodLogTemplate then
	print("[Arctic] Felling drops Assets.WoodLog")
else
	warn("[Arctic] Assets.WoodLog not found - felled trees will drop no log")
end

local function snapToGround(model, x, z)
	local pivot = model:GetPivot()
	model:PivotTo(CFrame.new(x, 0, z) * pivot.Rotation)
	local cf, size = model:GetBoundingBox()
	local dy = groundY(x, z) - (cf.Position.Y - size.Y / 2)
	if dy ~= 0 then
		model:PivotTo(model:GetPivot() + Vector3.new(0, dy, 0))
	end
end

local function findWoodPart(model)
	return model:FindFirstChild("WoodPart", true)
		or model:FindFirstChild("Trunk", true)
		or model:FindFirstChildWhichIsA("BasePart", true)
end

local function logWeight(logPart)
	local size = logPart.Size
	return math.floor(size.X * size.Y * size.Z * Config.Log.WeightPerVolume + 0.5)
end

for _, spot in ipairs(layout.Trees) do
	if not treeTemplate then
		break
	end
	local model = treeTemplate:Clone()
	model.Name = "Tree"
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	model:SetAttribute("Health", Config.Tree.Health)
	model.Parent = treesFolder
	model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	snapToGround(model, spot.X, spot.Z)
end

local campfire = Instance.new("Model")
campfire.Name = "Campfire"

local fireCore = Instance.new("Part")
fireCore.Name = "Core"
fireCore.Size = Vector3.new(3, 1, 3)
fireCore.CFrame = CFrame.new(0, groundY(0, 0) + 0.5, 0)
fireCore.Anchored = true
fireCore.Material = Enum.Material.Wood
fireCore.Color = Color3.fromRGB(70, 45, 28)
fireCore.Parent = campfire

local fire = Instance.new("Fire")
fire.Size = 6
fire.Heat = 12
fire.Parent = fireCore

local fireLight = Instance.new("PointLight")
fireLight.Color = Color3.fromRGB(255, 176, 66)
fireLight.Range = 20
fireLight.Brightness = 2
fireLight.Parent = fireCore

local feedPrompt = Instance.new("ProximityPrompt")
feedPrompt.ActionText = "Feed wood"
feedPrompt.ObjectText = "Campfire"
feedPrompt.HoldDuration = 0.4
feedPrompt.MaxActivationDistance = 10
feedPrompt.Parent = fireCore

campfire.Parent = workspace

feedPrompt.Triggered:Connect(function(player)
	if (wood[player] or 0) < 1 then
		return
	end
	wood[player] -= 1
	player:SetAttribute("Wood", wood[player])
	campfireFuel += Config.Campfire.FuelPerWood
end)

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

local function spawnLog(treeModel)
	local woodPart = findWoodPart(treeModel)
	if not woodPart then
		return
	end
	local woodSize = woodPart.Size
	local spot = treeModel:GetPivot().Position

	if not woodLogTemplate then
		return
	end
	local log = woodLogTemplate:Clone()
	local logPart = log:FindFirstChild("Log", true) or log:FindFirstChildWhichIsA("BasePart", true)
	if not logPart then
		return
	end

	log.Name = "WoodLog"
	logPart.Size = woodSize
	for _, part in ipairs(log:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = true
		end
	end
	log:SetAttribute("FullSize", woodSize)
	log:SetAttribute("PiecesLeft", Config.Log.PiecesPerLog)
	log:SetAttribute("PieceHits", 0)
	log:SetAttribute("Weight", logWeight(logPart))
	log.Parent = logsFolder

	if woodSize.Y >= woodSize.X and woodSize.Y >= woodSize.Z then
		log:PivotTo(log:GetPivot() * CFrame.Angles(0, 0, math.rad(90)))
	end
	snapToGround(log, spot.X, spot.Z)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Drag"
	prompt.ObjectText = "WoodLog " .. log:GetAttribute("Weight") .. "kg"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.Parent = logPart
	prompt.Triggered:Connect(function(player)
		if log:GetAttribute("DraggedBy") == player.UserId then
			log:SetAttribute("DraggedBy", nil)
			if dragging[player] == log then
				dragging[player] = nil
			end
			prompt.ActionText = "Drag"
		elseif log:GetAttribute("DraggedBy") == nil then
			local previous = dragging[player]
			if previous and previous ~= log then
				previous:SetAttribute("DraggedBy", nil)
				local prevPart = previous:FindFirstChild("Log", true)
				local prevPrompt = prevPart and prevPart:FindFirstChildOfClass("ProximityPrompt")
				if prevPrompt then
					prevPrompt.ActionText = "Drag"
				end
			end
			log:SetAttribute("DraggedBy", player.UserId)
			dragging[player] = log
			prompt.ActionText = "Drop"
		end
	end)
end

local function cutLog(player, log)
	local logPart = log:FindFirstChild("Log", true) or log:FindFirstChildWhichIsA("BasePart", true)
	if not logPart then
		return
	end

	local hits = (log:GetAttribute("PieceHits") or 0) + 1
	if hits < Config.Log.HitsPerPiece then
		log:SetAttribute("PieceHits", hits)
		return
	end
	log:SetAttribute("PieceHits", 0)

	local piecesLeft = (log:GetAttribute("PiecesLeft") or Config.Log.PiecesPerLog) - 1
	wood[player] = (wood[player] or 0) + Config.Log.WoodPerPiece
	player:SetAttribute("Wood", wood[player])

	if piecesLeft <= 0 then
		if dragging[player] == log then
			dragging[player] = nil
		end
		log:Destroy()
		return
	end
	log:SetAttribute("PiecesLeft", piecesLeft)

	local full = log:GetAttribute("FullSize") or logPart.Size
	local fraction = piecesLeft / Config.Log.PiecesPerLog
	local newSize
	if full.Y >= full.X and full.Y >= full.Z then
		newSize = Vector3.new(full.X, full.Y * fraction, full.Z)
	elseif full.X >= full.Z then
		newSize = Vector3.new(full.X * fraction, full.Y, full.Z)
	else
		newSize = Vector3.new(full.X, full.Y, full.Z * fraction)
	end
	logPart.Size = newSize
	log:SetAttribute("Weight", logWeight(logPart))

	local spot = log:GetPivot().Position
	snapToGround(log, spot.X, spot.Z)

	local prompt = logPart:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.ObjectText = "WoodLog " .. log:GetAttribute("Weight") .. "kg"
	end
end

local function onAxeActivated(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local target = nil
	local targetIsLog = false
	local nearestDistance = Config.Tree.ChopRange

	for _, tree in ipairs(treesFolder:GetChildren()) do
		local pivot = tree:GetPivot().Position
		local dx = pivot.X - root.Position.X
		local dz = pivot.Z - root.Position.Z
		local distance = math.sqrt(dx * dx + dz * dz)
		if distance < nearestDistance then
			target = tree
			targetIsLog = false
			nearestDistance = distance
		end
	end
	for _, log in ipairs(logsFolder:GetChildren()) do
		local pivot = log:GetPivot().Position
		local dx = pivot.X - root.Position.X
		local dz = pivot.Z - root.Position.Z
		local distance = math.sqrt(dx * dx + dz * dz)
		if distance < nearestDistance then
			target = log
			targetIsLog = true
			nearestDistance = distance
		end
	end
	if not target then
		return
	end

	if targetIsLog then
		cutLog(player, target)
		return
	end

	local remaining = (target:GetAttribute("Health") or Config.Tree.Health) - 1
	if remaining > 0 then
		target:SetAttribute("Health", remaining)
		return
	end

	spawnLog(target)
	target:Destroy()
end

local function syncAttributes(player, survival)
	player:SetAttribute("Health", math.floor(survival.Health))
	player:SetAttribute("Warmth", math.floor(survival.Warmth))
	player:SetAttribute("Hunger", math.floor(survival.Hunger:Get()))
	player:SetAttribute("IsSick", survival.IsSick)
	player:SetAttribute("Wood", wood[player] or 0)
end

local function makeSurvival(player)
	local survival = SurvivalPlayer.new(clock, temperature)
	survival.OnDied:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end)
	return survival
end

local function releaseLogs(player)
	for _, log in ipairs(logsFolder:GetChildren()) do
		if log:GetAttribute("DraggedBy") == player.UserId then
			log:SetAttribute("DraggedBy", nil)
			local logPart = log:FindFirstChild("Log", true)
			local prompt = logPart and logPart:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.ActionText = "Drag"
			end
		end
	end
	dragging[player] = nil
end

local function onCharacter(player, character)
	releaseLogs(player)
	survivals[player] = makeSurvival(player)
	wood[player] = 0
	sprinting[player] = false

	local humanoid = character:WaitForChild("Humanoid")
	humanoid.WalkSpeed = Config.Survival.WalkSpeed

	local root = character:WaitForChild("HumanoidRootPart")
	root.CFrame = CFrame.new(7, groundY(7, 0) + 4, 0)

	local backpack = player:WaitForChild("Backpack")
	local playerAxe = backpack:WaitForChild("Axe", 5) or character:FindFirstChild("Axe")
	if playerAxe then
		playerAxe.Activated:Connect(function()
			onAxeActivated(player)
		end)
	end

	syncAttributes(player, survivals[player])
end

local function setupPlayer(player)
	survivals[player] = makeSurvival(player)
	wood[player] = 0
	sprinting[player] = false
	syncAttributes(player, survivals[player])
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		onCharacter(player, player.Character)
	end
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	releaseLogs(player)
	survivals[player] = nil
	sprinting[player] = nil
	wood[player] = nil
end)

setSprinting.OnServerEvent:Connect(function(player, value)
	sprinting[player] = value == true
end)

clock.OnPhaseChanged:Connect(function(phase, day)
	local roll = math.random()
	if roll < Config.Temperature.WeatherChance.Blizzard then
		temperature:SetWeather("Blizzard")
	elseif roll < Config.Temperature.WeatherChance.Blizzard + Config.Temperature.WeatherChance.Storm then
		temperature:SetWeather("Storm")
	else
		temperature:SetWeather("Clear")
	end
	print(("[Arctic] %s of day %d - weather: %s"):format(phase, day, temperature:GetWeather()))
end)

local function updateWorldState()
	local progress = clock:GetPhaseProgress()
	local timeOfDay
	if clock:GetPhase() == "Day" then
		timeOfDay = 6.5 + progress * 11
	else
		timeOfDay = 17.5 + progress * 13
		if timeOfDay >= 24 then
			timeOfDay -= 24
		end
	end
	Lighting.ClockTime = timeOfDay

	ReplicatedStorage:SetAttribute("Day", clock:GetDay())
	ReplicatedStorage:SetAttribute("Phase", clock:GetPhase())
	ReplicatedStorage:SetAttribute("Multiplier", clock:GetMultiplier())
	ReplicatedStorage:SetAttribute("Weather", temperature:GetWeather())
	ReplicatedStorage:SetAttribute("AmbientTempC", temperature:GetAmbientTempC(clock:GetPhase()))
	ReplicatedStorage:SetAttribute("CampfireFuel", math.floor(campfireFuel))
end

updateWorldState()

while true do
	local dt = task.wait(0.25)
	clock:Update(dt)

	if campfireFuel > 0 then
		campfireFuel = math.max(0, campfireFuel - dt)
	end
	fire.Enabled = campfireFuel > 0
	fireLight.Enabled = campfireFuel > 0

	for player, survival in pairs(survivals) do
		local context = { IsSprinting = sprinting[player] == true }
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")

		local log = dragging[player]
		if log and (not log.Parent or log:GetAttribute("DraggedBy") ~= player.UserId) then
			dragging[player] = nil
			log = nil
		end

		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local baseSpeed = sprinting[player] and Config.Survival.SprintSpeed or Config.Survival.WalkSpeed
			local factor = 1
			if log then
				local w = log:GetAttribute("Weight") or 0
				factor = math.clamp(1 - w * Config.Log.DragSlowPerWeight, Config.Log.MinDragSpeedFactor, 1)
			end
			humanoid.WalkSpeed = baseSpeed * factor
		end

		if log and root then
			local look = root.CFrame.LookVector
			local tx = root.Position.X - look.X * Config.Log.DragDistance
			local tz = root.Position.Z - look.Z * Config.Log.DragDistance
			local pivotPos = log:GetPivot().Position
			local nx = pivotPos.X + (tx - pivotPos.X) * 0.4
			local nz = pivotPos.Z + (tz - pivotPos.Z) * 0.4
			snapToGround(log, nx, nz)
		end

		if root and campfireFuel > 0 then
			local dx = root.Position.X - fireCore.Position.X
			local dz = root.Position.Z - fireCore.Position.Z
			if math.sqrt(dx * dx + dz * dz) <= Config.Campfire.WarmthRadius then
				context.FireRate = Config.Campfire.WarmthRate
			end
		end
		survival:Update(dt, context)
		syncAttributes(player, survival)
	end

	updateWorldState()
end
