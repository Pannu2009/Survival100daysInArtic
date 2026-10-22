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
	self.TreesFolder = nil
	self.FireCore = nil
	self.TreeTemplate = nil
	self.WoodLogTemplate = nil
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
	for i, needed in ipairs(Config.Campfire.LevelWood) do
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
	local campfire = Instance.new("Model")
	campfire.Name = "Campfire"

	local fireCore = Instance.new("Part")
	fireCore.Name = "Core"
	fireCore.Size = Vector3.new(3, 1, 3)
	fireCore.CFrame = CFrame.new(0, self:GroundY(0, 0) + 0.5, 0)
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

	self.FireCore = fireCore
	self._fire = fire
	self._light = fireLight

	feedPrompt.Triggered:Connect(function(player)
		if self.OnFeedAttempt and self.OnFeedAttempt(player) then
			self.Fuel += Config.Campfire.FuelPerWood
			self.TotalFed += 1
			self:_recalcLevel()
		end
	end)

	local radius = self:GetWarmthRadius()
	local ring = Instance.new("Part")
	ring.Name = "WarmthRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.15, radius * 2, radius * 2)
	ring.CFrame = CFrame.new(fireCore.Position.X, self:GroundY(fireCore.Position.X, fireCore.Position.Z) + 0.12, fireCore.Position.Z)
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

	ReplicatedStorage:SetAttribute("Day", clock:GetDay())
	ReplicatedStorage:SetAttribute("Phase", clock:GetPhase())
	ReplicatedStorage:SetAttribute("Multiplier", clock:GetMultiplier())
	ReplicatedStorage:SetAttribute("Weather", temperature:GetWeather())
	ReplicatedStorage:SetAttribute("AmbientTempC", temperature:GetAmbientTempC(clock:GetPhase()))
	ReplicatedStorage:SetAttribute("CampfireFuel", math.floor(self.Fuel))
	ReplicatedStorage:SetAttribute("CampfireLevel", self.Level)

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
			self._fireState.Text = "OUT - feed wood to relight"
		end
	end
end

return WorldBuilder
