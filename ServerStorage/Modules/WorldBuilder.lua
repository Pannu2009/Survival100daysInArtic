local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local TerrainBuilder = require(script.Parent:WaitForChild("TerrainBuilder"))

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
	self.OnFeedAttempt = nil
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

function WorldBuilder:IsLit()
	return self.Fuel > 0
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
		end
	end)
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
end

return WorldBuilder
