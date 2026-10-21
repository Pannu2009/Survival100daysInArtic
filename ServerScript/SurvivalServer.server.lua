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

local function groundY(x, z)
	local result = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0))
	if result then
		return result.Position.Y
	end
	return 0
end

local treesFolder = Instance.new("Folder")
treesFolder.Name = "Trees"
treesFolder.Parent = workspace

local trunkColor = Color3.fromRGB(92, 64, 42)
local pineColor = Color3.fromRGB(38, 64, 48)

for _, spot in ipairs(layout.Trees) do
	local y = groundY(spot.X, spot.Z)
	local model = Instance.new("Model")
	model.Name = "Tree"

	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Size = Vector3.new(1.6, 9, 1.6)
	trunk.CFrame = CFrame.new(spot.X, y + 4.5, spot.Z)
	trunk.Anchored = true
	trunk.Material = Enum.Material.Wood
	trunk.Color = trunkColor
	trunk.Parent = model

	local top = Instance.new("Part")
	top.Name = "Top"
	top.Shape = Enum.PartType.Ball
	top.Size = Vector3.new(7.5, 11, 7.5)
	top.CFrame = CFrame.new(spot.X, y + 11, spot.Z)
	top.Anchored = true
	top.Material = Enum.Material.SmoothPlastic
	top.Color = pineColor
	top.Parent = model

	model.PrimaryPart = trunk
	model:SetAttribute("Health", Config.Tree.Health)
	model.Parent = treesFolder
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

local function onAxeActivated(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local nearest = nil
	local nearestDistance = Config.Tree.ChopRange
	for _, tree in ipairs(treesFolder:GetChildren()) do
		local pivot = tree:GetPivot().Position
		local dx = pivot.X - root.Position.X
		local dz = pivot.Z - root.Position.Z
		local distance = math.sqrt(dx * dx + dz * dz)
		if distance < nearestDistance then
			nearest = tree
			nearestDistance = distance
		end
	end
	if not nearest then
		return
	end

	local remaining = (nearest:GetAttribute("Health") or Config.Tree.Health) - 1
	if remaining > 0 then
		nearest:SetAttribute("Health", remaining)
		return
	end

	wood[player] = (wood[player] or 0) + Config.Tree.WoodPerTree
	player:SetAttribute("Wood", wood[player])

	for _, part in ipairs(nearest:GetChildren()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
	local pivot = nearest:GetPivot()
	nearest:PivotTo(pivot * CFrame.Angles(0, 0, math.rad(75)))
	task.delay(2.5, function()
		if nearest.Parent then
			nearest:Destroy()
		end
	end)
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

local function onCharacter(player, character)
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
	survivals[player] = nil
	sprinting[player] = nil
	wood[player] = nil
end)

setSprinting.OnServerEvent:Connect(function(player, value)
	sprinting[player] = value == true
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if sprinting[player] then
			humanoid.WalkSpeed = Config.Survival.SprintSpeed
		else
			humanoid.WalkSpeed = Config.Survival.WalkSpeed
		end
	end
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
