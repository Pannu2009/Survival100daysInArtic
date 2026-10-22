local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local TerrainBuilder = require(script.Parent:WaitForChild("TerrainBuilder"))

local AUBERGINE = Color3.fromHex("3A0F34")
local SILVER = Color3.fromHex("DDE3E7")
local MARIGOLD = Color3.fromHex("EAA000")

local WorldBuilder = {}
WorldBuilder.__index = WorldBuilder

local function scaleModel(model, sx, sy, sz)
	local pivot = model:GetPivot()
	local factors = Vector3.new(sx, sy, sz)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local rel = pivot:ToObjectSpace(part.CFrame)
			local newPos = rel.Position * factors
			part.Size = part.Size * factors
			part.CFrame = pivot * CFrame.new(newPos) * rel.Rotation
		end
	end
end

function WorldBuilder.new(layout)
	local self = setmetatable({}, WorldBuilder)
	self.Layout = layout
	self.Fuel = Config.Campfire.StartFuelSeconds
	self.Level = 1
	self.TotalFed = 0
	self.OnFeedAttempt = nil
	self._ring = nil
	self._ringLevel = nil
	self._fireTitle = nil
	self._fireFill = nil
	self._fireState = nil
	self._publishedWorld = {}
	self.TreesFolder = nil
	self.FireCore = nil
	self.TreeTemplate = nil
	self.WoodLogTemplate = nil
	self.BonfireTemplate = nil
	self._fireEmitters = {}
	self._fire = nil
	self._light = nil
	self._groundParams = RaycastParams.new()
	self._groundParams.FilterType = Enum.RaycastFilterType.Include
	self._groundParams.FilterDescendantsInstances = { workspace:WaitForChild("Terrain") }
	return self
end

function WorldBuilder:GroundY(x, z)
	local result = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), self._groundParams)
	if result then
		return result.Position.Y
	end
	return 0
end

function WorldBuilder:SnapToGround(model, x, z)
	local pivot = model:GetPivot()
	model:PivotTo(CFrame.new(x, 0, z) * pivot.Rotation)
	local cf, size = model:GetBoundingBox()
	local dy = self:GroundY(x, z) - (cf.Position.Y - size.Y / 2)
	if dy ~= 0 then
		model:PivotTo(model:GetPivot() + Vector3.new(0, dy, 0))
	end
end

local function partBottomY(part)
	local cf = part.CFrame
	local half = part.Size / 2
	local minY = math.huge
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local corner = cf:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
				if corner.Y < minY then
					minY = corner.Y
				end
			end
		end
	end
	return minY
end

function WorldBuilder:SnapPartToGround(model, part, x, z)
	local pivot = model:GetPivot()
	model:PivotTo(CFrame.new(x, pivot.Position.Y, z) * pivot.Rotation)
	local dy = self:GroundY(x, z) - partBottomY(part)
	if dy ~= 0 then
		model:PivotTo(model:GetPivot() + Vector3.new(0, dy, 0))
	end
end

function WorldBuilder:IsLit()
	return self.Fuel > 0
end

function WorldBuilder:GetWarmthRadius()
	return Config.Campfire.RadiusByLevel[self.Level] or Config.Campfire.RadiusByLevel[1]
end

function WorldBuilder:TerrainRaycastDown(x, z)
	return workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), self._groundParams)
end

function WorldBuilder:_recalcLevel()
	local level = 1
	for i, needed in ipairs(Config.Campfire.LevelBurnUnits) do
		if self.TotalFed >= needed then
			level = i
		end
	end
	if level ~= self.Level then
		self.Level = level
		print(("[Arctic] Campfire reached level %d - warm radius %d studs"):format(level, self:GetWarmthRadius()))
	end
end

function WorldBuilder:TickFire(dt)
	if self.Fuel > 0 then
		self.Fuel = math.max(0, self.Fuel - dt)
	end
	local lit = self:IsLit()
	if self._fire then
		self._fire.Enabled = lit
	end
	if self._light then
		self._light.Enabled = lit
	end
	for _, emitter in ipairs(self._fireEmitters) do
		if emitter.Parent then
			emitter.Enabled = lit
		end
	end
	return lit
end

function WorldBuilder:Build()
	local layout = self.Layout

	if Config.World.GenerateTerrain then
		TerrainBuilder.Build(layout)
	end

	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	self.TreeTemplate = assets and assets:FindFirstChild("Tree")
	self.WoodLogTemplate = assets and assets:FindFirstChild("WoodLog")
	if self.TreeTemplate then
		print("[Arctic] Planting with Assets.Tree")
	else
		warn("[Arctic] Assets.Tree not found - no trees will be planted")
	end
	if self.WoodLogTemplate then
		print("[Arctic] Felling drops Assets.WoodLog")
	else
		warn("[Arctic] Assets.WoodLog not found - felled trees will drop no log")
	end
	self.BonfireTemplate = assets and (assets:FindFirstChild("BonFire") or assets:FindFirstChild("Bonfire"))
	if self.BonfireTemplate then
		print("[Arctic] Campfire uses Assets.BonFire")
	else
		warn("[Arctic] Assets.BonFire not found - campfire stays code-built")
	end

	self:_plantTrees()
	self:_buildCampfire()
end

function WorldBuilder:_plantTrees()
	local treesFolder = Instance.new("Folder")
	treesFolder.Name = "Trees"
	treesFolder.Parent = workspace
	self.TreesFolder = treesFolder

	if not self.TreeTemplate then
		return
	end

	for _, spot in ipairs(self.Layout.Trees) do
		local model = self.TreeTemplate:Clone()
		model.Name = "Tree"
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
		model.Parent = treesFolder
		scaleModel(model, spot.T or 1, spot.H or 1, spot.T or 1)
		model:SetAttribute("Health", Config.Tree.Health)
		model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.random() * math.pi * 2, 0))
		self:SnapToGround(model, spot.X, spot.Z)
	end
end

function WorldBuilder:_buildCampfire()
	local campfire
	local fireCore
	local groundY = self:GroundY(0, 0)

	if self.BonfireTemplate then
		-- Ajay's BonFire model is the campfire visual. The game still
		-- owns the fire state, so bundled scripts are stripped, every
		-- part is anchored, and an invisible Core anchor at the model's
		-- center carries the prompt, billboard, and fire state.
		campfire = self.BonfireTemplate:Clone()
		campfire.Name = "Campfire"
		for _, obj in ipairs(campfire:GetDescendants()) do
			if obj:IsA("BasePart") then
				obj.Anchored = true
			elseif obj:IsA("Script") or obj:IsA("LocalScript") then
				obj:Destroy()
			end
		end
		campfire.Parent = workspace
		if campfire:IsA("Model") then
			self:SnapToGround(campfire, 0, 0)
		end

		local center = Vector3.new(0, groundY, 0)
		if campfire:IsA("Model") then
			center = campfire:GetBoundingBox().Position
		elseif campfire:IsA("BasePart") then
			center = campfire.Position
		else
			local firstPart = campfire:FindFirstChildWhichIsA("BasePart", true)
			if firstPart then
				center = firstPart.Position
			end
		end
		fireCore = Instance.new("Part")
		fireCore.Name = "Core"
		fireCore.Size = Vector3.new(3, 1, 3)
		fireCore.CFrame = CFrame.new(center.X, groundY + 0.9, center.Z)
		fireCore.Anchored = true
		fireCore.Transparency = 1
		fireCore.CanCollide = false
		fireCore.CanTouch = false
		fireCore.Parent = campfire

		for _, obj in ipairs(campfire:GetDescendants()) do
			if obj:IsA("ParticleEmitter") then
				table.insert(self._fireEmitters, obj)
			end
		end
	else
		campfire = Instance.new("Model")
		campfire.Name = "Campfire"

		fireCore = Instance.new("Part")
		fireCore.Name = "Core"
		fireCore.Size = Vector3.new(3, 1, 3)
		fireCore.CFrame = CFrame.new(0, groundY + 0.9, 0)
		fireCore.Anchored = true
		fireCore.Material = Enum.Material.Wood
		fireCore.Color = Color3.fromRGB(70, 45, 28)
		fireCore.Parent = campfire
	end

	local fire = campfire:FindFirstChildOfClass("Fire", true)
	if not fire then
		fire = Instance.new("Fire")
		fire.Size = 6
		fire.Heat = 12
		fire.Parent = fireCore
	end

	local fireLight = fireCore:FindFirstChildOfClass("PointLight")
		or campfire:FindFirstChildOfClass("PointLight", true)
	if not fireLight then
		fireLight = Instance.new("PointLight")
		fireLight.Color = Color3.fromRGB(255, 176, 66)
		fireLight.Range = 20
		fireLight.Brightness = 2
		fireLight.Parent = fireCore
	end

	local feedPrompt = Instance.new("ProximityPrompt")
	feedPrompt.ActionText = "Feed log"
	feedPrompt.ObjectText = "Campfire"
	feedPrompt.HoldDuration = 0.4
	feedPrompt.MaxActivationDistance = 10
	feedPrompt.Parent = fireCore

	campfire.Parent = workspace

	self.FireCore = fireCore
	self._fire = fire
	self._light = fireLight

	feedPrompt.Triggered:Connect(function(player)
		local burnUnits = self.OnFeedAttempt and self.OnFeedAttempt(player)
		if burnUnits then
			self.Fuel += burnUnits * Config.Campfire.FuelPerBurnUnit
			self.TotalFed += burnUnits
			self:_recalcLevel()
		end
	end)

	local radius = self:GetWarmthRadius()
	local ring = Instance.new("Part")
	ring.Name = "WarmthRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.15, radius * 2, radius * 2)
	ring.CFrame = CFrame.new(fireCore.Position.X, self:GroundY(fireCore.Position.X, fireCore.Position.Z) + 0.35, fireCore.Position.Z)
		* CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.SmoothPlastic
	ring.Color = MARIGOLD
	ring.Transparency = 0.78
	ring.Parent = campfire
	self._ring = ring
	self._ringLevel = self.Level

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CampfireGui"
	billboard.Size = UDim2.fromOffset(170, 62)
	billboard.StudsOffset = Vector3.new(0, 3.6, 0)
	billboard.MaxDistance = 70
	billboard.Parent = fireCore

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = AUBERGINE
	bg.BackgroundTransparency = 0.25
	bg.BorderSizePixel = 0
	bg.Parent = billboard
	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 8)
	bgCorner.Parent = bg

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -12, 0, 20)
	title.Position = UDim2.fromOffset(6, 4)
	title.BackgroundTransparency = 1
	title.Text = "CAMPFIRE Lv 1"
	title.TextColor3 = SILVER
	title.TextSize = 15
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = bg
	self._fireTitle = title

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -12, 0, 10)
	track.Position = UDim2.fromOffset(6, 28)
	track.BackgroundColor3 = SILVER
	track.BackgroundTransparency = 0.6
	track.BorderSizePixel = 0
	track.Parent = bg
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 5)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0.4, 1)
	fill.BackgroundColor3 = MARIGOLD
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 5)
	fillCorner.Parent = fill
	self._fireFill = fill

	local state = Instance.new("TextLabel")
	state.Size = UDim2.new(1, -12, 0, 16)
	state.Position = UDim2.fromOffset(6, 42)
	state.BackgroundTransparency = 1
	state.Text = "Fuel 240s"
	state.TextColor3 = SILVER
	state.TextSize = 12
	state.Font = Enum.Font.Gotham
	state.TextXAlignment = Enum.TextXAlignment.Left
	state.Parent = bg
	self._fireState = state
end

function WorldBuilder:UpdateState(clock, temperature)
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

	local published = self._publishedWorld
	local function publish(name, value)
		if published[name] ~= value then
			published[name] = value
			ReplicatedStorage:SetAttribute(name, value)
		end
	end
	publish("Day", clock:GetDay())
	publish("Phase", clock:GetPhase())
	publish("Multiplier", clock:GetMultiplier())
	publish("Weather", temperature:GetWeather())
	publish("AmbientTempC", math.floor(temperature:GetAmbientTempC(clock:GetPhase())))
	publish("CampfireFuel", math.floor(self.Fuel))
	publish("CampfireLevel", self.Level)

	if self._ring and self._ringLevel ~= self.Level then
		self._ringLevel = self.Level
		local radius = self:GetWarmthRadius()
		self._ring.Size = Vector3.new(0.15, radius * 2, radius * 2)
	end
	if self._ring then
		self._ring.Transparency = self:IsLit() and 0.78 or 0.93
	end
	if self._fireTitle then
		self._fireTitle.Text = "CAMPFIRE Lv " .. self.Level
	end
	if self._fireFill then
		local fraction = math.clamp(self.Fuel / Config.Campfire.FuelDisplayMax, 0, 1)
		self._fireFill.Size = UDim2.fromScale(fraction, 1)
	end
	if self._fireState then
		if self:IsLit() then
			self._fireState.Text = "Fuel " .. math.floor(self.Fuel) .. "s · warm " .. self:GetWarmthRadius() .. " studs"
		else
			self._fireState.Text = "OUT - feed a log to relight"
		end
	end
end

return WorldBuilder
