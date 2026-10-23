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
	self.Fires = {}
	self.Blueprints = {}
	self.OnBlueprintAdd = nil
	self.OnBlueprintBuilt = nil
	self.OnLightAttempt = nil
	self._publishedWorld = {}
	self.TreesFolder = nil
	self.TreeTemplate = nil
	self.WoodLogTemplate = nil
	self.BonfireTemplate = nil
	self.FireBoxTemplate = nil
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

-- Warmth is per-fire now: any lit, fueled fire warms its radius.
function WorldBuilder:WarmthRateAt(position)
	for _, fire in ipairs(self.Fires) do
		if fire.Lit and fire.Fuel > 0 then
			if fire.WarmthPart then
				-- The FireBox volume is the warmth area when present.
				local p = fire.WarmthPart.CFrame:PointToObjectSpace(position)
				local s = fire.WarmthPart.Size
				if math.abs(p.X) <= s.X / 2
					and math.abs(p.Z) <= s.Z / 2
					and p.Y >= -s.Y / 2 - 2
					and p.Y <= s.Y / 2 + 3
				then
					return Config.Campfire.WarmthRate
				end
			else
				local radius = Config.Campfire.WarmthRadius
				local dx = position.X - fire.Core.Position.X
				local dz = position.Z - fire.Core.Position.Z
				if dx * dx + dz * dz <= radius * radius then
					return Config.Campfire.WarmthRate
				end
			end
		end
	end
	return nil
end

-- True when a point sits within `radius` of any fire or blueprint
-- (digging protection, blueprint spacing).
function WorldBuilder:IsNearStructure(x, z, radius)
	local function near(position)
		local dx = x - position.X
		local dz = z - position.Z
		return dx * dx + dz * dz < radius * radius
	end
	for _, fire in ipairs(self.Fires) do
		if near(fire.Core.Position) then
			return true
		end
	end
	for _, bp in ipairs(self.Blueprints) do
		if near(bp.Position) then
			return true
		end
	end
	return false
end

function WorldBuilder:FireRadius(_fire)
	return Config.Campfire.WarmthRadius
end

function WorldBuilder:TerrainRaycastDown(x, z)
	return workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), self._groundParams)
end

-- Credit a fire with burned fuel (physical feeding via AddWoodBox).
function WorldBuilder:AddFuel(fire, burnUnits)
	fire.Fuel += burnUnits * Config.Campfire.FuelPerBurnUnit
	self:_refreshFireVisual(fire)
end

function WorldBuilder:_refreshFireVisual(fire)
	local burning = fire.Lit and fire.Fuel > 0
	if fire.Fire then
		fire.Fire.Enabled = burning
	end
	if fire.Light then
		fire.Light.Enabled = burning
	end
	for _, emitter in ipairs(fire.Emitters) do
		if emitter.Parent then
			emitter.Enabled = burning
		end
	end
	if fire.LightPrompt then
		fire.LightPrompt.Enabled = not burning and fire.Fuel > 0
	end
end

function WorldBuilder:TickFire(dt)
	for _, fire in ipairs(self.Fires) do
		if fire.Lit and fire.Fuel > 0 then
			fire.Fuel = math.max(0, fire.Fuel - dt)
			if fire.Fuel <= 0 then
				fire.Lit = false
			end
		end
		self:_refreshFireVisual(fire)
	end
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
	self.FireBoxTemplate = assets and assets:FindFirstChild("FireBox")
	if self.BonfireTemplate then
		print("[Arctic] Campfire uses Assets.BonFire")
	else
		warn("[Arctic] Assets.BonFire not found - campfire stays code-built")
	end

	self:_plantTrees()
	-- No fixed campfire anymore: players build their own from
	-- blueprints (open-world direction, 2026-10-22).
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

function WorldBuilder:_createFire(x, z)
	local campfire
	local fireCore
	local groundY = self:GroundY(x, z)
	local emitters = {}

	if self.BonfireTemplate then
		-- Ajay's BonFire model is the campfire visual. The game owns
		-- the fire state, so bundled scripts are stripped, every part
		-- is anchored, and an invisible Core anchor at the model's
		-- center carries the prompts, billboard, and fire state.
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
			self:SnapToGround(campfire, x, z)
		end

		local center = Vector3.new(x, groundY, z)
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
				table.insert(emitters, obj)
			end
		end
	else
		campfire = Instance.new("Model")
		campfire.Name = "Campfire"

		fireCore = Instance.new("Part")
		fireCore.Name = "Core"
		fireCore.Size = Vector3.new(3, 1, 3)
		fireCore.CFrame = CFrame.new(x, groundY + 0.9, z)
		fireCore.Anchored = true
		fireCore.Material = Enum.Material.Wood
		fireCore.Color = Color3.fromRGB(70, 45, 28)
		fireCore.Parent = campfire
		campfire.Parent = workspace
	end

	local fire = {
		Model = campfire,
		Core = fireCore,
		-- A built fire carries starter fuel from its construction
		-- wood, so the lighter works on it right away; feeding logs
		-- is how it stays alive after that.
		Fuel = Config.Campfire.BuildFuelSeconds,
		Lit = false,
		Emitters = emitters,
		GroundY = groundY,
	}

	local flame = campfire:FindFirstChildOfClass("Fire", true)
	if not flame then
		flame = Instance.new("Fire")
		flame.Size = 6
		flame.Heat = 12
		flame.Parent = fireCore
	end
	fire.Fire = flame

	local fireLight = fireCore:FindFirstChildOfClass("PointLight")
		or campfire:FindFirstChildOfClass("PointLight", true)
	if not fireLight then
		fireLight = Instance.new("PointLight")
		fireLight.Color = Color3.fromRGB(255, 176, 66)
		fireLight.Range = 20
		fireLight.Brightness = 2
		fireLight.Parent = fireCore
	end
	fire.Light = fireLight

	-- Feeding is physical: burnable items that land in the model's
	-- AddWoodBox are consumed as this fire's fuel (Gameplay watches
	-- the box every tick).
	local addBox = campfire:FindFirstChild("AddWoodBox", true)
	if addBox and addBox:IsA("BasePart") then
		addBox.CanCollide = false
		addBox.CanTouch = false
		fire.AddBox = addBox
	end

	local lightPrompt = Instance.new("ProximityPrompt")
	lightPrompt.ActionText = "Light with lighter"
	lightPrompt.ObjectText = "Campfire"
	lightPrompt.HoldDuration = 0.3
	lightPrompt.MaxActivationDistance = 12
	lightPrompt.Enabled = false
	lightPrompt.Parent = fireCore
	lightPrompt.Triggered:Connect(function(player)
		if self.OnLightAttempt and self.OnLightAttempt(player, fire) then
			self:_refreshFireVisual(fire)
		end
	end)
	fire.LightPrompt = lightPrompt

	local radius = self:FireRadius(fire)
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
	ring.Transparency = 0.93
	ring.Parent = campfire
	fire.Ring = ring

	-- Ajay's FireBox rides on every built fire: FeelsWarmth becomes
	-- the volume players feel warmth in (sized to the fire's warm
	-- radius), CookingPart is the zone food cooks in, stretched to
	-- fit a full log. Both are invisible logic volumes in game.
	if self.FireBoxTemplate then
		local box = self.FireBoxTemplate:Clone()
		for _, obj in ipairs(box:GetDescendants()) do
			if obj:IsA("Script") or obj:IsA("LocalScript") then
				obj:Destroy()
			end
		end
		box.Parent = campfire

		local warmthPart = box:FindFirstChild("FeelsWarmth", true)
		if warmthPart and warmthPart:IsA("BasePart") then
			warmthPart.Anchored = true
			warmthPart.CanCollide = false
			warmthPart.CanQuery = false
			warmthPart.CanTouch = false
			warmthPart.Transparency = 1
			local h = warmthPart.Size.Y
			warmthPart.Size = Vector3.new(radius * 2, h, radius * 2)
			warmthPart.CFrame = CFrame.new(fireCore.Position.X, groundY + h / 2, fireCore.Position.Z)
			fire.WarmthPart = warmthPart
		end

		local cookingPart = box:FindFirstChild("CookingPart", true)
		if cookingPart and cookingPart:IsA("BasePart") then
			cookingPart.Anchored = true
			cookingPart.CanCollide = false
			cookingPart.CanQuery = false
			cookingPart.CanTouch = false
			cookingPart.Transparency = 1
			local s = cookingPart.Size
			if math.max(s.X, s.Z) < 7 then
				if s.X >= s.Z then
					s = Vector3.new(7, s.Y, s.Z)
				else
					s = Vector3.new(s.X, s.Y, 7)
				end
				cookingPart.Size = s
			end
			cookingPart.CFrame = CFrame.new(fireCore.Position.X, groundY + 0.8, fireCore.Position.Z)
			fire.CookingPart = cookingPart
		end
	end

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
	fire.Title = title

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
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = MARIGOLD
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 5)
	fillCorner.Parent = fill
	fire.Fill = fill

	local state = Instance.new("TextLabel")
	state.Size = UDim2.new(1, -12, 0, 16)
	state.Position = UDim2.fromOffset(6, 42)
	state.BackgroundTransparency = 1
	state.Text = "OUT - drop a log in the wood box, then light it"
	state.TextColor3 = SILVER
	state.TextSize = 12
	state.Font = Enum.Font.Gotham
	state.TextXAlignment = Enum.TextXAlignment.Left
	state.Parent = bg
	fire.State = state

	table.insert(self.Fires, fire)
	self:_refreshFireVisual(fire)
	return fire
end

-- A placed blueprint: a ghost of the campfire players fill with
-- logs (CampfireCostKg total) until it becomes a real fire.
function WorldBuilder:PlaceBlueprint(x, z)
	local hit = self:TerrainRaycastDown(x, z)
	if not hit or hit.Material ~= Enum.Material.Snow then
		return nil
	end
	if self:IsNearStructure(x, z, Config.Blueprint.MinSpacing) then
		return nil
	end
	local groundY = self:GroundY(x, z)

	local model
	if self.BonfireTemplate then
		model = self.BonfireTemplate:Clone()
		model.Name = "CampfireBlueprint"
		for _, obj in ipairs(model:GetDescendants()) do
			if obj:IsA("BasePart") then
				obj.Anchored = true
				obj.CanCollide = false
				obj.CanQuery = false
				obj.Transparency = math.max(obj.Transparency, 0.55)
			elseif obj:IsA("Script") or obj:IsA("LocalScript") then
				obj:Destroy()
			elseif obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("PointLight") then
				obj.Enabled = false
			end
		end
		model.Parent = workspace
		if model:IsA("Model") then
			self:SnapToGround(model, x, z)
		end
	else
		model = Instance.new("Model")
		model.Name = "CampfireBlueprint"
		local marker = Instance.new("Part")
		marker.Shape = Enum.PartType.Cylinder
		marker.Size = Vector3.new(0.4, 6, 6)
		marker.CFrame = CFrame.new(x, groundY + 0.2, z) * CFrame.Angles(0, 0, math.rad(90))
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false
		marker.Material = Enum.Material.SmoothPlastic
		marker.Color = MARIGOLD
		marker.Transparency = 0.5
		marker.Parent = model
		model.Parent = workspace
	end

	local core = Instance.new("Part")
	core.Name = "BlueprintCore"
	core.Size = Vector3.new(2, 2, 2)
	core.CFrame = CFrame.new(x, groundY + 1, z)
	core.Anchored = true
	core.Transparency = 1
	core.CanCollide = false
	core.CanTouch = false
	core.Parent = model

	local bp = {
		Model = model,
		Core = core,
		Position = Vector3.new(x, groundY, z),
		FedKg = 0,
		Contributors = {},
	}

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Add log"
	prompt.ObjectText = "Campfire blueprint"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.Parent = core
	prompt.Triggered:Connect(function(player)
		local kg = self.OnBlueprintAdd and self.OnBlueprintAdd(player, bp)
		if kg then
			bp.FedKg += kg
			if bp.Label then
				bp.Label.Text = ("CAMPFIRE %d/%dkg"):format(math.floor(bp.FedKg), Config.Blueprint.CampfireCostKg)
			end
			if bp.FedKg >= Config.Blueprint.CampfireCostKg then
				self:CompleteBlueprint(bp)
			end
		end
	end)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BlueprintGui"
	billboard.Size = UDim2.fromOffset(170, 40)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.MaxDistance = 70
	billboard.Parent = core

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = AUBERGINE
	bg.BackgroundTransparency = 0.25
	bg.BorderSizePixel = 0
	bg.Parent = billboard
	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 8)
	bgCorner.Parent = bg

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -12, 1, 0)
	label.Position = UDim2.fromOffset(6, 0)
	label.BackgroundTransparency = 1
	label.Text = ("CAMPFIRE 0/%dkg"):format(Config.Blueprint.CampfireCostKg)
	label.TextColor3 = MARIGOLD
	label.TextSize = 15
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = bg
	bp.Label = label

	table.insert(self.Blueprints, bp)
	return bp
end

function WorldBuilder:CompleteBlueprint(bp)
	for i, other in ipairs(self.Blueprints) do
		if other == bp then
			table.remove(self.Blueprints, i)
			break
		end
	end
	if bp.Model then
		bp.Model:Destroy()
	end
	local fire = self:_createFire(bp.Position.X, bp.Position.Z)
	if self.OnBlueprintBuilt then
		self.OnBlueprintBuilt(bp)
	end
	return fire
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

	-- Realism pass (one-time): cold air haze, a touch of sun
	-- glare, and a slight cool grade over everything. Per-phase
	-- brightness/ambient below still owns the day-night feel.
	if not Lighting:FindFirstChild("ArcticAtmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "ArcticAtmosphere"
		atmosphere.Density = 0.28
		atmosphere.Offset = 0.2
		atmosphere.Color = Color3.fromRGB(196, 214, 232)
		atmosphere.Decay = Color3.fromRGB(96, 116, 148)
		atmosphere.Glare = 0.35
		atmosphere.Haze = 1.4
		atmosphere.Parent = Lighting
		local sun = Instance.new("SunRaysEffect")
		sun.Name = "ArcticSunRays"
		sun.Intensity = 0.05
		sun.Spread = 0.85
		sun.Parent = Lighting
		local grade = Instance.new("ColorCorrectionEffect")
		grade.Name = "ArcticGrade"
		grade.Saturation = 0.05
		grade.Contrast = 0.05
		grade.TintColor = Color3.fromRGB(238, 244, 255)
		grade.Parent = Lighting
	end

	-- Brightness and ambient follow the sun: full daylight at
	-- midday, properly dark at night, smooth fades between.
	local daylight = math.clamp(1 - math.abs(timeOfDay - 12.5) / 6.5, 0, 1)
	Lighting.Brightness = Config.DayCycle.NightBrightness
		+ daylight * (Config.DayCycle.DayBrightness - Config.DayCycle.NightBrightness)
	local ambient = Color3.fromRGB(16, 20, 38):Lerp(Color3.fromRGB(135, 145, 160), daylight)
	Lighting.Ambient = ambient
	Lighting.OutdoorAmbient = ambient

	local published = self._publishedWorld
	local function publish(name, value)
		if published[name] ~= value then
			published[name] = value
			ReplicatedStorage:SetAttribute(name, value)
		end
	end
	publish("Day", clock:GetDay())
	publish("Phase", clock:GetPhase())
	-- Server timestamp of the next phase switch, set every tick so
	-- clients can time animations to land exactly on the switch.
	ReplicatedStorage:SetAttribute("PhaseEndsAt", workspace:GetServerTimeNow() + clock:GetSecondsLeft())
	publish("Multiplier", clock:GetMultiplier())
	publish("Weather", temperature:GetWeather())
	publish("AmbientTempC", math.floor(temperature:GetAmbientTempC(clock:GetPhase())))
	local litCount = 0
	for _, fire in ipairs(self.Fires) do
		local burning = fire.Lit and fire.Fuel > 0
		if burning then
			litCount += 1
		end
		if fire.Ring then
			fire.Ring.Transparency = burning and 0.78 or 0.93
		end
		if fire.Title then
			fire.Title.Text = "CAMPFIRE"
		end
		if fire.Fill then
			local fraction = math.clamp(fire.Fuel / Config.Campfire.FuelDisplayMax, 0, 1)
			fire.Fill.Size = UDim2.fromScale(fraction, 1)
		end
		if fire.State then
			if burning then
				fire.State.Text = "Fuel " .. math.floor(fire.Fuel) .. "s · warm " .. self:FireRadius(fire) .. " studs"
			elseif fire.Fuel > 0 then
				fire.State.Text = "Unlit - light it with a lighter"
			else
				fire.State.Text = "OUT - drop a log in the wood box, then light it"
			end
		end
	end
	publish("LitFires", litCount)
end

return WorldBuilder
