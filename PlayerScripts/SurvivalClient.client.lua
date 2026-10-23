local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local StarterGui = game:GetService("StarterGui")
task.spawn(function()
	for _ = 1, 20 do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		end)
		task.wait(0.25)
	end
end)
local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local DragSystem = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("DragSystem"))
DragSystem.InitClient()
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local setSprinting = remotes:WaitForChild("SetSprinting")
local storeRemote = remotes:WaitForChild("StoreDraggedItem", 10)
local eatRemote = remotes:WaitForChild("EatFish")
local openBuildMenuRemote = remotes:WaitForChild("OpenBuildMenu")
local placeBlueprintRemote = remotes:WaitForChild("PlaceBlueprint")

local AUBERGINE = Color3.fromHex("3A0F34")
local SILVER = Color3.fromHex("DDE3E7")
local MARIGOLD = Color3.fromHex("EAA000")

local gui = Instance.new("ScreenGui")
gui.Name = "SurvivalHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Freezing overlay: fades in over the screen as this player's
-- warmth runs out (client-only effect).
local frost = Instance.new("Frame")
frost.Name = "Frost"
frost.Size = UDim2.fromScale(1, 1)
frost.BackgroundColor3 = Color3.fromRGB(174, 216, 240)
frost.BackgroundTransparency = 1
frost.BorderSizePixel = 0
frost.Parent = gui

local function makeLabel(parent, text, size, position, color, textSize)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text
	label.Size = size
	label.Position = position
	label.TextColor3 = color
	label.TextSize = textSize
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function addStroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end


-- Day counter: flush with the top center of the screen, plain
-- white text with a thin black stroke.
local dayBanner = Instance.new("TextLabel")
dayBanner.Name = "DayBanner"
dayBanner.BackgroundTransparency = 1
dayBanner.AnchorPoint = Vector2.new(0.5, 0)
dayBanner.Position = UDim2.new(0.5, 0, 0, 0)
dayBanner.Size = UDim2.fromOffset(520, 34)
dayBanner.Text = "Day: 1"
dayBanner.TextColor3 = Color3.new(1, 1, 1)
dayBanner.TextSize = 24
dayBanner.Font = Enum.Font.GothamBold
dayBanner.TextXAlignment = Enum.TextXAlignment.Center
dayBanner.Parent = gui
local dayStroke = Instance.new("UIStroke")
dayStroke.Color = Color3.new(0, 0, 0)
dayStroke.Thickness = 1
dayStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
dayStroke.Parent = dayBanner
local dayScale = Instance.new("UIScale")
dayScale.Parent = dayBanner

local function dayText(day)
	return "Day: " .. tostring(day)
end

-- Smooth day switch: the animation starts ~2 seconds BEFORE the
-- switch (timed off the server's PhaseEndsAt stamp), eases the
-- banner up while the night ends, the number flips at the switch
-- itself, then it settles back over the next ~1.6 seconds.
local dayAnimActive = false
local function animateDaySwitch(secondsLeft)
	if dayAnimActive then
		return
	end
	dayAnimActive = true
	task.spawn(function()
		local up = TweenService:Create(
			dayScale,
			TweenInfo.new(math.max(secondsLeft, 0.2), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ Scale = 1.22 }
		)
		up:Play()
		up.Completed:Wait()
		-- The flip happens in refreshWorld when the Day attribute
		-- lands; give it a beat at the peak before settling.
		task.wait(0.25)
		local down = TweenService:Create(
			dayScale,
			TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ Scale = 1 }
		)
		down:Play()
		down.Completed:Wait()
		dayAnimActive = false
	end)
end

task.spawn(function()
	while true do
		task.wait(0.1)
		if ReplicatedStorage:GetAttribute("Phase") == "Night" then
			local endsAt = ReplicatedStorage:GetAttribute("PhaseEndsAt")
			if endsAt then
				local left = endsAt - workspace:GetServerTimeNow()
				if left > 0 and left <= 2 then
					animateDaySwitch(left)
				end
			end
		end
	end
end)

local sickLabel = makeLabel(gui, "SICK", UDim2.fromOffset(80, 22), UDim2.new(1, -96, 0, 46), MARIGOLD, 16)
sickLabel.TextXAlignment = Enum.TextXAlignment.Right
sickLabel.Visible = false

-- Day 1 objective banner (top center).
local objectivePanel = Instance.new("Frame")
objectivePanel.Name = "ObjectivePanel"
objectivePanel.Size = UDim2.fromOffset(330, 30)
objectivePanel.Position = UDim2.new(0.5, -165, 0, 50)
objectivePanel.BackgroundColor3 = AUBERGINE
objectivePanel.BackgroundTransparency = 0.25
objectivePanel.BorderSizePixel = 0
objectivePanel.Parent = gui
local objectiveCorner = Instance.new("UICorner")
objectiveCorner.CornerRadius = UDim.new(0, 8)
objectiveCorner.Parent = objectivePanel
addStroke(objectivePanel, SILVER, 1, 0.55)
local objectiveLabel = makeLabel(objectivePanel, "Day 1: Fell a tree", UDim2.new(1, -12, 1, 0), UDim2.fromOffset(6, 0), SILVER, 13)
objectiveLabel.TextXAlignment = Enum.TextXAlignment.Center

local OBJECTIVES = {
	"Day 1: Fell a tree",
	"Day 1: Dig a snow shelter",
	"Day 1: Build a campfire (blueprint stick)",
	"Day 1: Light the campfire with your lighter",
}

-- Stat bars (Ajay's layout): each stat gets its OWN frame.
-- Health sits flush top-right where Roblox's health bar usually
-- lives; Warmth and Hunger are small frames stacked mid-left.
local function makeStatFrame(name, size, position, anchorPoint)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchorPoint
	frame.BackgroundColor3 = AUBERGINE
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	addStroke(frame, SILVER, 1, 0.55)
	return frame
end

local function makeBar(parent, name)
	local frameH = parent.Size.Y.Offset
	makeLabel(parent, name, UDim2.fromOffset(58, 16), UDim2.fromOffset(8, (frameH - 16) / 2), SILVER, 12)
	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -76, 0, 12)
	track.Position = UDim2.fromOffset(68, (frameH - 12) / 2)
	track.BackgroundColor3 = SILVER
	track.BackgroundTransparency = 0.6
	track.BorderSizePixel = 0
	track.Parent = parent
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 6)
	trackCorner.Parent = track
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = MARIGOLD
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill
	return fill
end

local healthFrame = makeStatFrame("HealthFrame", UDim2.fromOffset(216, 36), UDim2.new(1, -6, 0, 3), Vector2.new(1, 0))
local healthFill = makeBar(healthFrame, "Health")
local warmthFrame = makeStatFrame("WarmthFrame", UDim2.fromOffset(172, 28), UDim2.new(0, 8, 0.42, 0), Vector2.new(0, 0))
local warmthFill = makeBar(warmthFrame, "Warmth")
local hungerFrame = makeStatFrame("HungerFrame", UDim2.fromOffset(172, 28), UDim2.new(0, 8, 0.42, 34), Vector2.new(0, 0))
local hungerFill = makeBar(hungerFrame, "Hunger")

-- Lighter fuel: a small pill floating just over the hotbar,
-- visible only while the lighter is in hand.
local lighterFuelPill = makeStatFrame("LighterFuel", UDim2.fromOffset(120, 26), UDim2.new(0.5, -60, 1, -118), Vector2.new(0, 0))
lighterFuelPill.Visible = false
local lighterFuelLabel = makeLabel(lighterFuelPill, "Fuel: 100", UDim2.new(1, 0, 1, 0), UDim2.fromOffset(0, 0), SILVER, 13)
lighterFuelLabel.TextXAlignment = Enum.TextXAlignment.Center

local sprintButton = Instance.new("TextButton")
sprintButton.Name = "SprintButton"
sprintButton.Size = UDim2.fromOffset(112, 54)
sprintButton.Position = UDim2.new(1, -124, 1, -124)
sprintButton.BackgroundColor3 = MARIGOLD
sprintButton.Text = "SPRINT"
sprintButton.TextColor3 = AUBERGINE
sprintButton.TextSize = 17
sprintButton.Font = Enum.Font.GothamBold
sprintButton.BorderSizePixel = 0
sprintButton.Parent = gui

local sprintCorner = Instance.new("UICorner")
sprintCorner.CornerRadius = UDim.new(0, 12)
sprintCorner.Parent = sprintButton
addStroke(sprintButton, AUBERGINE, 1.5, 0.25)

-- Context action: appears while a dragged log hovers over the sled's
-- cargo zone. Tappable on touch, clickable on PC, key-bound per
-- platform (E on keyboard, X on gamepad).
local storeButton = Instance.new("TextButton")
storeButton.Name = "StoreButton"
storeButton.Size = UDim2.fromOffset(132, 54)
storeButton.Position = UDim2.new(1, -144, 1, -190)
storeButton.BackgroundColor3 = MARIGOLD
storeButton.Text = ""
storeButton.AutoButtonColor = true
storeButton.BorderSizePixel = 0
storeButton.Visible = false
storeButton.Parent = gui

local storeCorner = Instance.new("UICorner")
storeCorner.CornerRadius = UDim.new(0, 12)
storeCorner.Parent = storeButton
addStroke(storeButton, AUBERGINE, 1.5, 0.25)

local storeTitle = makeLabel(storeButton, "STORE ITEM", UDim2.new(1, -8, 0, 22), UDim2.fromOffset(4, 6), AUBERGINE, 15)
storeTitle.TextXAlignment = Enum.TextXAlignment.Center
local storeHint = makeLabel(storeButton, "", UDim2.new(1, -8, 0, 16), UDim2.fromOffset(4, 31), AUBERGINE, 12)
storeHint.TextXAlignment = Enum.TextXAlignment.Center

local canStore = false
local function tryStore()
	if canStore and storeRemote then
		storeRemote:FireServer()
	end
end
storeButton.Activated:Connect(tryStore)

-- Eat fish button: same contextual pattern as Store — appears
-- while dragging a fish or standing near one.
local eatButton = Instance.new("TextButton")
eatButton.Name = "EatButton"
eatButton.Size = UDim2.fromOffset(132, 54)
eatButton.Position = UDim2.new(1, -156, 1, -206)
eatButton.BackgroundColor3 = MARIGOLD
eatButton.Text = "EAT FISH"
eatButton.TextColor3 = AUBERGINE
eatButton.TextSize = 16
eatButton.Font = Enum.Font.GothamBold
eatButton.BorderSizePixel = 0
eatButton.Visible = false
eatButton.Parent = gui
local eatCorner = Instance.new("UICorner")
eatCorner.CornerRadius = UDim.new(0, 12)
eatCorner.Parent = eatButton
addStroke(eatButton, AUBERGINE, 1.5, 0.25)
local eatHint = makeLabel(gui, "tap", UDim2.fromOffset(132, 16), UDim2.new(1, -156, 1, -148), SILVER, 11)
eatHint.TextXAlignment = Enum.TextXAlignment.Center
eatHint.Visible = false

local eatTarget = nil
local function tryEat()
	if eatTarget then
		eatRemote:FireServer(eatTarget)
	end
end
eatButton.Activated:Connect(tryEat)

-- Build menu (blueprint stick) + campfire placement mode.
local buildMenu = Instance.new("Frame")
buildMenu.Name = "BuildMenu"
buildMenu.Size = UDim2.fromOffset(300, 200)
buildMenu.Position = UDim2.new(0.5, -150, 0.5, -100)
buildMenu.BackgroundColor3 = AUBERGINE
buildMenu.BackgroundTransparency = 0.1
buildMenu.BorderSizePixel = 0
buildMenu.Visible = false
buildMenu.Parent = gui
local buildMenuCorner = Instance.new("UICorner")
buildMenuCorner.CornerRadius = UDim.new(0, 12)
buildMenuCorner.Parent = buildMenu
addStroke(buildMenu, SILVER, 1, 0.4)
local buildTitle = makeLabel(buildMenu, "BUILD", UDim2.new(1, -16, 0, 24), UDim2.fromOffset(8, 8), SILVER, 17)
buildTitle.TextXAlignment = Enum.TextXAlignment.Center

local campfireBuildButton = Instance.new("TextButton")
campfireBuildButton.Size = UDim2.fromOffset(164, 46)
campfireBuildButton.Position = UDim2.fromOffset(12, 42)
campfireBuildButton.BackgroundColor3 = MARIGOLD
campfireBuildButton.Text = "Campfire - 40kg of logs"
campfireBuildButton.TextColor3 = AUBERGINE
campfireBuildButton.TextSize = 15
campfireBuildButton.Font = Enum.Font.GothamBold
campfireBuildButton.BorderSizePixel = 0
campfireBuildButton.Parent = buildMenu
local campfireBuildCorner = Instance.new("UICorner")
campfireBuildCorner.CornerRadius = UDim.new(0, 10)
campfireBuildCorner.Parent = campfireBuildButton
addStroke(campfireBuildButton, AUBERGINE, 1.5, 0.25)

local buildIconHolder = Instance.new("Frame")
buildIconHolder.Name = "BuildIconHolder"
buildIconHolder.Size = UDim2.fromOffset(100, 100)
buildIconHolder.Position = UDim2.fromOffset(188, 42)
buildIconHolder.BackgroundTransparency = 1
buildIconHolder.BorderSizePixel = 0
buildIconHolder.Parent = buildMenu

local buildCloseButton = Instance.new("TextButton")
buildCloseButton.Size = UDim2.new(1, -24, 0, 34)
buildCloseButton.Position = UDim2.fromOffset(12, 156)
buildCloseButton.BackgroundColor3 = SILVER
buildCloseButton.BackgroundTransparency = 0.4
buildCloseButton.Text = "Close"
buildCloseButton.TextColor3 = AUBERGINE
buildCloseButton.TextSize = 14
buildCloseButton.Font = Enum.Font.GothamBold
buildCloseButton.BorderSizePixel = 0
buildCloseButton.Parent = buildMenu
local buildCloseCorner = Instance.new("UICorner")
buildCloseCorner.CornerRadius = UDim.new(0, 10)
buildCloseCorner.Parent = buildCloseButton
buildCloseButton.Activated:Connect(function()
	buildMenu.Visible = false
end)

openBuildMenuRemote.OnClientEvent:Connect(function()
	buildMenu.Visible = true
end)

local placing = false
local aimPosition = nil
local buildGhost = nil

local placeButton = Instance.new("TextButton")
placeButton.Name = "PlaceButton"
placeButton.Size = UDim2.fromOffset(150, 50)
placeButton.Position = UDim2.new(0.5, -160, 1, -128)
placeButton.BackgroundColor3 = MARIGOLD
placeButton.Text = "PLACE HERE"
placeButton.TextColor3 = AUBERGINE
placeButton.TextSize = 16
placeButton.Font = Enum.Font.GothamBold
placeButton.BorderSizePixel = 0
placeButton.Visible = false
placeButton.Parent = gui
local placeCorner = Instance.new("UICorner")
placeCorner.CornerRadius = UDim.new(0, 12)
placeCorner.Parent = placeButton
addStroke(placeButton, AUBERGINE, 1.5, 0.25)

local cancelPlaceButton = Instance.new("TextButton")
cancelPlaceButton.Name = "CancelPlaceButton"
cancelPlaceButton.Size = UDim2.fromOffset(110, 50)
cancelPlaceButton.Position = UDim2.new(0.5, 2, 1, -128)
cancelPlaceButton.BackgroundColor3 = SILVER
cancelPlaceButton.BackgroundTransparency = 0.25
cancelPlaceButton.Text = "Cancel"
cancelPlaceButton.TextColor3 = AUBERGINE
cancelPlaceButton.TextSize = 15
cancelPlaceButton.Font = Enum.Font.GothamBold
cancelPlaceButton.BorderSizePixel = 0
cancelPlaceButton.Visible = false
cancelPlaceButton.Parent = gui
local cancelPlaceCorner = Instance.new("UICorner")
cancelPlaceCorner.CornerRadius = UDim.new(0, 12)
cancelPlaceCorner.Parent = cancelPlaceButton
addStroke(cancelPlaceButton, AUBERGINE, 1.5, 0.4)

local function stopPlacing()
	placing = false
	placeButton.Visible = false
	cancelPlaceButton.Visible = false
	if buildGhost then
		buildGhost.Parent = nil
	end
end

local function startPlacing()
	buildMenu.Visible = false
	if not buildGhost then
		buildGhost = Instance.new("Part")
		buildGhost.Name = "BuildGhost"
		buildGhost.Shape = Enum.PartType.Cylinder
		buildGhost.Size = Vector3.new(0.4, 6.4, 6.4)
		buildGhost.Anchored = true
		buildGhost.CanCollide = false
		buildGhost.CanQuery = false
		buildGhost.CanTouch = false
		buildGhost.Material = Enum.Material.SmoothPlastic
		buildGhost.Color = MARIGOLD
		buildGhost.Transparency = 0.45
	end
	buildGhost.Parent = workspace
	placing = true
	placeButton.Visible = true
	cancelPlaceButton.Visible = true
end

campfireBuildButton.Activated:Connect(startPlacing)
cancelPlaceButton.Activated:Connect(stopPlacing)
placeButton.Activated:Connect(function()
	if aimPosition then
		placeBlueprintRemote:FireServer(aimPosition)
	end
	stopPlacing()
end)

local hotbar = Instance.new("Frame")
hotbar.Name = "Hotbar"
hotbar.Size = UDim2.fromOffset(302, 56)
hotbar.Position = UDim2.new(0.5, -151, 1, -64)
hotbar.BackgroundColor3 = AUBERGINE
hotbar.BackgroundTransparency = 0.25
hotbar.BorderSizePixel = 0
hotbar.Parent = gui

local hotbarCorner = Instance.new("UICorner")
hotbarCorner.CornerRadius = UDim.new(0, 10)
hotbarCorner.Parent = hotbar
addStroke(hotbar, SILVER, 1, 0.55)

local inputMode = "Keyboard"
local function toggleTool(toolName)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if character:FindFirstChild(toolName) then
		humanoid:UnequipTools()
		return
	end
	local backpack = player:FindFirstChild("Backpack")
	local tool = backpack and backpack:FindFirstChild(toolName)
	if tool then
		humanoid:EquipTool(tool)
	end
end

local MAX_SLOTS = 10
local TOOL_ORDER = { "Axe", "Shovel", "Blueprint", "Lighter", "FishingRod" }
local slotPool = {}
local slotTools = {}

local function slotHintFor(index)
	if inputMode == "Keyboard" then
		return tostring(index % 10)
	elseif inputMode == "Gamepad" then
		return ({ "◀", "▶", "▲", "▼", "R3" })[index] or ""
	end
	return ""
end

-- ViewportFrame icons: clone a tool's parts into a WorldModel,
-- center them on the origin from the bounding box, and frame them
-- with an auto-fit camera. Ajay tunes angles in Config.ViewportIcons
-- (per-tool overrides there) -- background stays transparent so the
-- slot's own color shows through.
local function buildIconModel(source)
	local model = Instance.new("Model")
	local any = false
	for _, d in ipairs(source:GetDescendants()) do
		if d:IsA("BasePart") then
			local part = d:Clone()
			for _, child in ipairs(part:GetChildren()) do
				if not child:IsA("Mesh") and not child:IsA("SpecialMesh")
					and not child:IsA("Decal") and not child:IsA("Texture")
					and not child:IsA("SurfaceAppearance") then
					child:Destroy()
				end
			end
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.Parent = model
			any = true
		end
	end
	if not any then
		model:Destroy()
		return nil
	end
	local cf = model:GetBoundingBox()
	local pivot = model:GetPivot()
	model:PivotTo(CFrame.new(pivot.Position - cf.Position) * (pivot - pivot.Position))
	return model
end

local function setViewportIcon(vpf, source, iconName)
	local oldWorld = vpf:FindFirstChildOfClass("WorldModel")
	if oldWorld then
		oldWorld:Destroy()
	end
	local oldCam = vpf:FindFirstChildOfClass("Camera")
	if oldCam then
		oldCam:Destroy()
	end
	vpf.CurrentCamera = nil
	if not source then
		return
	end
	local model = buildIconModel(source)
	if not model then
		return
	end
	local world = Instance.new("WorldModel")
	world.Parent = vpf
	model.Parent = world
	local tuning = Config.ViewportIcons
	local over = tuning.PerTool[iconName] or {}
	local yaw = over.Yaw or tuning.Yaw
	local pitch = over.Pitch or tuning.Pitch
	local zoom = over.Zoom or tuning.Zoom
	local _, size = model:GetBoundingBox()
	local maxDim = math.max(size.X, size.Y, size.Z, 0.1)
	local dist = maxDim * 1.35 * zoom / math.tan(math.rad(17.5))
	local dir = Vector3.new(
		math.sin(yaw) * math.cos(pitch),
		math.sin(pitch),
		math.cos(yaw) * math.cos(pitch)
	)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	camera.CFrame = CFrame.lookAt(dir * dist, Vector3.new(0, 0, 0))
	camera.Parent = vpf
	vpf.CurrentCamera = camera
end

local function makePoolSlot(index)
	local slot = Instance.new("TextButton")
	slot.Text = ""
	slot.AutoButtonColor = false
	slot.Size = UDim2.fromOffset(68, 58)
	slot.Position = UDim2.fromOffset(6 + (index - 1) * 74, 6)
	slot.BackgroundColor3 = SILVER
	slot.BackgroundTransparency = 0.75
	slot.BorderSizePixel = 0
	slot.Visible = false
	slot.Parent = hotbar
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = slot
	addStroke(slot, AUBERGINE, 1, 0.6)
	local icon = Instance.new("Frame")
	icon.Name = "IconHolder"
	icon.Size = UDim2.fromOffset(44, 44)
	icon.Position = UDim2.fromOffset(12, 2)
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.Parent = slot
	local label = makeLabel(slot, "", UDim2.new(1, -8, 0, 12), UDim2.fromOffset(4, 46), SILVER, 11)
	label.TextXAlignment = Enum.TextXAlignment.Center
	local value = makeLabel(slot, "", UDim2.new(1, -8, 0, 18), UDim2.fromOffset(4, 24), MARIGOLD, 13)
	value.Visible = false
	value.TextXAlignment = Enum.TextXAlignment.Center
	local hint = makeLabel(slot, "", UDim2.fromOffset(24, 14), UDim2.fromOffset(3, 2), AUBERGINE, 11)
	slotPool[index] = { Frame = slot, Name = label, Value = value, Hint = hint, Icon = icon, IconTool = nil }
	slot.Activated:Connect(function()
		local toolName = slotTools[index]
		if toolName then
			toggleTool(toolName)
		end
	end)
end
for i = 1, MAX_SLOTS do
	makePoolSlot(i)
end

-- The tools the player owns, canonical order first (the game's
-- tool list), then anything else they picked up, alphabetical.
local function ownedTools()
	local owned = {}
	local seen = {}
	local function scan(container)
		if not container then
			return
		end
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Tool") and not seen[child.Name] then
				seen[child.Name] = true
				table.insert(owned, child.Name)
			end
		end
	end
	scan(player:FindFirstChild("Backpack"))
	scan(player.Character)
	local ordered = {}
	for _, name in ipairs(TOOL_ORDER) do
		if seen[name] then
			table.insert(ordered, name)
			seen[name] = nil
		end
	end
	local extra = {}
	for name in pairs(seen) do
		table.insert(extra, name)
	end
	table.sort(extra)
	for _, name in ipairs(extra) do
		table.insert(ordered, name)
	end
	return ordered
end

-- Ajay's hand-framed icons live in ReplicatedStorage/PointFrames,
-- named "<Tool>Frame" or just "<Tool>" (AxeFrame, Campfire,
-- FishingRod, LighterFrame...). A slot clones its tool's frame
-- when the tool arrives and destroys it when the slot changes --
-- nothing is created ahead of time.
local function findPointFrame(name)
	local folder = ReplicatedStorage:FindFirstChild("PointFrames")
	if not folder then
		return nil
	end
	local template = folder:FindFirstChild(name .. "Frame") or folder:FindFirstChild(name)
	if template and template:IsA("ViewportFrame") then
		return template
	end
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("ViewportFrame") and child.Name:lower():find(name:lower(), 1, true) then
			return child
		end
	end
	return nil
end

local function setSlotIcon(entry, toolName)
	for _, child in ipairs(entry.Icon:GetChildren()) do
		child:Destroy()
	end
	if not toolName then
		return
	end
	local template = findPointFrame(toolName)
	if not template then
		return
	end
	local clone = template:Clone()
	clone.Size = UDim2.fromOffset(44, 44)
	clone.Position = UDim2.fromOffset(0, 0)
	clone.Parent = entry.Icon
end

local function refreshHotbar()
	local owned = ownedTools()
	local character = player.Character
	local count = math.max(math.min(#owned, MAX_SLOTS), 1)
	local width = 74 * count + 6
	hotbar.Size = UDim2.fromOffset(width, 70)
	hotbar.Position = UDim2.new(0.5, -width / 2, 1, -78)
	for i = 1, MAX_SLOTS do
		local entry = slotPool[i]
		local toolName = owned[i]
		slotTools[i] = toolName
		entry.Frame.Visible = toolName ~= nil
		if not toolName and entry.IconTool ~= nil then
			entry.IconTool = nil
			setSlotIcon(entry, nil)
		end
		if toolName then
			entry.Name.Text = toolName
			if entry.IconTool ~= toolName then
				entry.IconTool = toolName
				setSlotIcon(entry, toolName)
			end
			local equipped = character and character:FindFirstChild(toolName) ~= nil
			entry.Frame.BackgroundColor3 = equipped and MARIGOLD or SILVER
			entry.Frame.BackgroundTransparency = equipped and 0 or 0.75
			entry.Value.Text = equipped and "in hand" or ""
			entry.Hint.Text = slotHintFor(i)
		end
	end
end

local hotbarBackpack = player:WaitForChild("Backpack")
hotbarBackpack.ChildAdded:Connect(refreshHotbar)
hotbarBackpack.ChildRemoved:Connect(refreshHotbar)

local function hookCharacter(character)
	character.ChildAdded:Connect(refreshHotbar)
	character.ChildRemoved:Connect(refreshHotbar)
	refreshHotbar()
end
if player.Character then
	hookCharacter(player.Character)
end
player.CharacterAdded:Connect(hookCharacter)

-- Blueprint menu icon, created ONLY while the menu is open and
-- destroyed when it closes (Ajay's optimization rule). Preferred
-- source: his hand-framed ViewportFrames in
-- ReplicatedStorage/PointFrames, named after the structure
-- ("Campfire"). Fallback: an auto-framed viewport of the Assets
-- model.
local buildIconLive = nil
local function clearBuildIcon()
	if buildIconLive then
		buildIconLive:Destroy()
		buildIconLive = nil
	end
end
local function showBuildIcon()
	clearBuildIcon()
	local pointFrames = ReplicatedStorage:FindFirstChild("PointFrames")
	local template = pointFrames and pointFrames:FindFirstChild("Campfire")
	if template and template:IsA("ViewportFrame") then
		local clone = template:Clone()
		clone.Size = UDim2.fromOffset(100, 100)
		clone.Position = UDim2.fromOffset(0, 0)
		clone.Parent = buildIconHolder
		buildIconLive = clone
		return
	end
	local vpf = Instance.new("ViewportFrame")
	vpf.Size = UDim2.fromOffset(100, 100)
	vpf.Position = UDim2.fromOffset(0, 0)
	vpf.BackgroundColor3 = Color3.fromRGB(24, 8, 22)
	vpf.BackgroundTransparency = 0.2
	vpf.BorderSizePixel = 0
	vpf.Ambient = Color3.fromRGB(165, 165, 178)
	vpf.LightColor = Color3.fromRGB(255, 250, 240)
	vpf.LightDirection = Vector3.new(-1, -1.4, -0.6)
	vpf.Parent = buildIconHolder
	local vpfCorner = Instance.new("UICorner")
	vpfCorner.CornerRadius = UDim.new(0, 8)
	vpfCorner.Parent = vpf
	buildIconLive = vpf
	local assets = ReplicatedStorage:WaitForChild("Assets", 5)
	local fireModel = assets and (assets:FindFirstChild("BonFire") or assets:FindFirstChild("FireBox"))
	if fireModel then
		setViewportIcon(vpf, fireModel, "Campfire")
	end
end
buildMenu:GetPropertyChangedSignal("Visible"):Connect(function()
	if buildMenu.Visible then
		showBuildIcon()
	else
		clearBuildIcon()
	end
end)

-- Platform control modes: the HUD and bindings follow the input the
-- player is actually using and switch live when it changes (touch
-- buttons on mobile, keys on PC, gamepad buttons on console).
local function detectMode()
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "Touch"
	end
	if last.Name:sub(1, 7) == "Gamepad" then
		return "Gamepad"
	end
	if last == Enum.UserInputType.None then
		if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
			return "Touch"
		end
		if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
			return "Gamepad"
		end
	end
	return "Keyboard"
end

local function applyMode()
	inputMode = detectMode()
	sprintButton.Visible = inputMode == "Touch"
	refreshHotbar()
	storeHint.Text = inputMode == "Keyboard" and "press E" or inputMode == "Gamepad" and "press X" or "tap"
	eatHint.Text = inputMode == "Keyboard" and "press F" or inputMode == "Gamepad" and "press Y" or "tap"
end
UserInputService.LastInputTypeChanged:Connect(applyMode)
applyMode()

local isSprinting = false
local function setSprint(value)
	if value == isSprinting then
		return
	end
	isSprinting = value
	setSprinting:FireServer(value)
end

sprintButton.MouseButton1Down:Connect(function()
	setSprint(true)
end)
sprintButton.MouseButton1Up:Connect(function()
	setSprint(false)
end)
sprintButton.MouseLeave:Connect(function()
	setSprint(false)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if inputMode == "Keyboard" then
		if input.KeyCode == Enum.KeyCode.LeftShift then
			setSprint(true)
		elseif input.KeyCode == Enum.KeyCode.E then
			tryStore()
		elseif input.KeyCode == Enum.KeyCode.F then
			tryEat()
		else
			local slotKeys = {
				[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3,
				[Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6,
				[Enum.KeyCode.Seven] = 7, [Enum.KeyCode.Eight] = 8, [Enum.KeyCode.Nine] = 9,
				[Enum.KeyCode.Zero] = 10,
			}
			local index = slotKeys[input.KeyCode]
			if index and slotTools[index] then
				toggleTool(slotTools[index])
			end
		end
	elseif inputMode == "Gamepad" then
		if input.KeyCode == Enum.KeyCode.ButtonL3 then
			setSprint(true)
		elseif input.KeyCode == Enum.KeyCode.ButtonX then
			tryStore()
		elseif input.KeyCode == Enum.KeyCode.ButtonY then
			tryEat()
		else
			local padSlots = {
				[Enum.KeyCode.DPadLeft] = 1, [Enum.KeyCode.DPadRight] = 2,
				[Enum.KeyCode.DPadUp] = 3, [Enum.KeyCode.DPadDown] = 4,
				[Enum.KeyCode.ButtonR3] = 5,
			}
			local index = padSlots[input.KeyCode]
			if index and slotTools[index] then
				toggleTool(slotTools[index])
			end
		end
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3 then
		setSprint(false)
	end
end)

local dayShown = nil
local function refreshWorld()
	local day = ReplicatedStorage:GetAttribute("Day") or 1
	-- The number flips exactly at the switch; the smooth scale
	-- animation around it is timed separately off PhaseEndsAt.
	dayBanner.Text = dayText(day)
	dayShown = day
end

local function setBar(fill, value, maxValue)
	local fraction = math.clamp((value or maxValue) / maxValue, 0, 1)
	fill.Size = UDim2.fromScale(fraction, 1)
end

local function refreshPlayer()
	setBar(healthFill, player:GetAttribute("Health"), Config.Survival.MaxHealth)
	setBar(warmthFill, player:GetAttribute("Warmth"), Config.Survival.MaxWarmth)
	local warmthNow = player:GetAttribute("Warmth") or Config.Survival.MaxWarmth
	if warmthNow < 35 then
		frost.BackgroundTransparency = 0.55 + 0.45 * (warmthNow / 35)
	else
		frost.BackgroundTransparency = 1
	end
	setBar(hungerFill, player:GetAttribute("Hunger"), Config.Survival.MaxHunger)
	lighterFuelLabel.Text = "Fuel: " .. tostring(player:GetAttribute("LighterFuel") or 0)
	-- The tutorial ends the moment the campfire is lit (step 5):
	-- the banner goes away for good.
	local tutorialStep = player:GetAttribute("TutorialStep") or 1
	objectivePanel.Visible = tutorialStep < 5
	if tutorialStep < 5 then
		objectiveLabel.Text = OBJECTIVES[tutorialStep] or OBJECTIVES[1]
	end
	sickLabel.Visible = player:GetAttribute("IsSick") == true
	refreshHotbar()
end

ReplicatedStorage.AttributeChanged:Connect(refreshWorld)
player.AttributeChanged:Connect(refreshPlayer)
refreshWorld()
refreshPlayer()

-- Fishing panel: driven by server-published attributes
-- (FishingPhase / FishingProgress / FishingStartAt / FishingSeed).
-- The reel needle and zone are pure functions of elapsed time from
-- the shared start values -- the same math the server judges taps
-- with -- so they render locally at full frame rate.
local fishingPanel = Instance.new("Frame")
fishingPanel.Name = "FishingPanel"
fishingPanel.Size = UDim2.fromOffset(340, 104)
fishingPanel.Position = UDim2.new(0.5, -170, 1, -196)
fishingPanel.BackgroundColor3 = AUBERGINE
fishingPanel.BackgroundTransparency = 0.25
fishingPanel.BorderSizePixel = 0
fishingPanel.Visible = false
fishingPanel.Parent = gui
local fishingCorner = Instance.new("UICorner")
fishingCorner.CornerRadius = UDim.new(0, 10)
fishingCorner.Parent = fishingPanel
addStroke(fishingPanel, SILVER, 1, 0.55)
local fishingTitle = makeLabel(fishingPanel, "", UDim2.new(1, -16, 0, 26), UDim2.fromOffset(8, 6), SILVER, 16)
fishingTitle.TextXAlignment = Enum.TextXAlignment.Center
local reelTrack = Instance.new("Frame")
reelTrack.Size = UDim2.fromOffset(308, 18)
reelTrack.Position = UDim2.fromOffset(16, 40)
reelTrack.BackgroundColor3 = SILVER
reelTrack.BackgroundTransparency = 0.7
reelTrack.BorderSizePixel = 0
reelTrack.Parent = fishingPanel
local reelZoneFrame = Instance.new("Frame")
reelZoneFrame.BackgroundColor3 = MARIGOLD
reelZoneFrame.BackgroundTransparency = 0.25
reelZoneFrame.BorderSizePixel = 0
reelZoneFrame.Size = UDim2.fromOffset(80, 18)
reelZoneFrame.Parent = reelTrack
local reelNeedle = Instance.new("Frame")
reelNeedle.Size = UDim2.fromOffset(3, 18)
reelNeedle.BackgroundColor3 = Color3.new(1, 1, 1)
reelNeedle.BorderSizePixel = 0
reelNeedle.Parent = reelTrack
local progressTrack = Instance.new("Frame")
progressTrack.Size = UDim2.fromOffset(308, 10)
progressTrack.Position = UDim2.fromOffset(16, 68)
progressTrack.BackgroundColor3 = SILVER
progressTrack.BackgroundTransparency = 0.7
progressTrack.BorderSizePixel = 0
progressTrack.Parent = fishingPanel
local progressFill = Instance.new("Frame")
progressFill.BackgroundColor3 = MARIGOLD
progressFill.BorderSizePixel = 0
progressFill.Size = UDim2.fromScale(0, 1)
progressFill.Parent = progressTrack

local function clientReelNeedle(elapsed)
	local phase = (elapsed % 1.6) / 1.6
	if phase < 0.5 then
		return phase * 2
	end
	return 2 - phase * 2
end
local function clientReelZone(elapsed, seed)
	return 0.5 + 0.38 * math.sin(elapsed * 0.9 + seed)
end

game:GetService("RunService").Heartbeat:Connect(function()
	local phase = player:GetAttribute("FishingPhase")
	fishingPanel.Visible = phase ~= nil and phase ~= ""
	if not fishingPanel.Visible then
		return
	end
	local inReel = phase == "Reel"
	reelTrack.Visible = inReel
	progressTrack.Visible = inReel
	if phase == "Waiting" then
		fishingTitle.Text = "Waiting for a bite..."
		fishingTitle.TextSize = 16
	elseif phase == "Bite" then
		fishingTitle.Text = "! TAP !"
		fishingTitle.TextSize = 26
	elseif inReel then
		fishingTitle.Text = "Reel it in -- tap in the gold zone!"
		fishingTitle.TextSize = 16
		local startAt = player:GetAttribute("FishingStartAt") or 0
		local seed = player:GetAttribute("FishingSeed") or 0
		local elapsed = math.max(0, workspace:GetServerTimeNow() - startAt)
		local zone = clientReelZone(elapsed, seed)
		local needle = clientReelNeedle(elapsed)
		local trackWidth = reelTrack.AbsoluteSize.X
		local zoneHalf = 0.13
		reelZoneFrame.Size = UDim2.fromOffset(trackWidth * zoneHalf * 2, 18)
		reelZoneFrame.Position = UDim2.fromOffset((zone - zoneHalf) * trackWidth, 0)
		reelNeedle.Position = UDim2.fromOffset(needle * trackWidth - 1, 0)
		local progress = (player:GetAttribute("FishingProgress") or 0) / 100
		progressFill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
	end
end)

-- Drag mover: as network owner, float my dragged piece at a point in
-- front of the camera (aim with the center dot). The server validates.
local RunService = game:GetService("RunService")
local logsFolder = workspace:WaitForChild("Logs")
local dragSurfaceParams = RaycastParams.new()
dragSurfaceParams.FilterType = Enum.RaycastFilterType.Exclude
dragSurfaceParams.IgnoreWater = true

local function dragLengthAxis(size)
	if size.Y >= size.X and size.Y >= size.Z then
		return Vector3.yAxis
	elseif size.X >= size.Z then
		return Vector3.xAxis
	else
		return Vector3.zAxis
	end
end

local function dragHorizontal(v)
	local h = Vector3.new(v.X, 0, v.Z)
	if h.Magnitude < 0.01 then
		return Vector3.xAxis
	end
	return h.Unit
end

-- Track the dragged part by its DraggedBy attribute instead of
-- scanning the whole folder every frame.
local myDragPart = nil
local lastDragSend = 0
local dragSmoothedTarget = nil
local dragSmoothedPart = nil
local function trackLog(log)
	local part = log:FindFirstChild("Log", true) or log:FindFirstChildWhichIsA("BasePart", true)
	if not part then
		return
	end
	local function check()
		if part:GetAttribute("DraggedBy") == player.UserId then
			myDragPart = part
		elseif myDragPart == part then
			myDragPart = nil
		end
	end
	part:GetAttributeChangedSignal("DraggedBy"):Connect(check)
	check()
end
for _, log in ipairs(logsFolder:GetChildren()) do
	trackLog(log)
end
logsFolder.ChildAdded:Connect(trackLog)

-- Center aim dot: the game's main interaction pointer. Visible
-- while dragging and while a center-dot tool is equipped.
local dragDot = Instance.new("Frame")
dragDot.Name = "DragDot"
dragDot.Size = UDim2.fromOffset(8, 8)
dragDot.Position = UDim2.new(0.5, -4, 0.5, -4)
dragDot.BackgroundColor3 = Color3.new(1, 1, 1)
dragDot.BackgroundTransparency = 0.2
dragDot.BorderSizePixel = 0
dragDot.Visible = false
dragDot.Parent = gui
local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = dragDot

-- Center-dot tools: the shovel and the lighter act where the dot
-- is pointing. The client raycasts the center of the camera and
-- reports the hit; the server validates and decides (ToolAim).
local toolAimRemote = remotes:WaitForChild("ToolAim")
local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude
aimParams.IgnoreWater = true
local wiredAimTools = {}
local function watchAimTool(tool)
	if wiredAimTools[tool] then
		return
	end
	if tool.Name ~= "Shovel" and tool.Name ~= "Lighter" and tool.Name ~= "FishingRod"
		and tool.Name ~= "Axe" then
		return
	end
	wiredAimTools[tool] = true
	tool.Activated:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		aimParams.FilterDescendantsInstances = { player.Character }
		local hit = workspace:Raycast(
			camera.CFrame.Position,
			camera.CFrame.LookVector * 40,
			aimParams
		)
		if hit then
			toolAimRemote:FireServer(tool.Name, hit.Instance, hit.Position)
		end
	end)
end
local aimBackpack = player:WaitForChild("Backpack")
for _, tool in ipairs(aimBackpack:GetChildren()) do
	watchAimTool(tool)
end
aimBackpack.ChildAdded:Connect(watchAimTool)
local function hookAimCharacter(character)
	for _, child in ipairs(character:GetChildren()) do
		watchAimTool(child)
	end
	character.ChildAdded:Connect(watchAimTool)
end
if player.Character then
	hookAimCharacter(player.Character)
end
player.CharacterAdded:Connect(hookAimCharacter)

local function nearestFish()
	local fishFolder = workspace:FindFirstChild("Fish")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not fishFolder or not root then
		return nil
	end
	local best = nil
	local bestDistance = 8
	for _, fish in ipairs(fishFolder:GetChildren()) do
		local part = fish:FindFirstChild("F1") or fish:FindFirstChildWhichIsA("BasePart", true)
		if part then
			local d = (part.Position - root.Position).Magnitude
			if d < bestDistance then
				best = fish
				bestDistance = d
			end
		end
	end
	return best
end

RunService.RenderStepped:Connect(function(dt)
	local myPart = myDragPart
	local characterNow = player.Character
	local aimEquipped = characterNow
		and (characterNow:FindFirstChild("Shovel") or characterNow:FindFirstChild("Lighter")
			or characterNow:FindFirstChild("FishingRod") or characterNow:FindFirstChild("Axe"))
	dragDot.Visible = myPart ~= nil or aimEquipped ~= nil
	lighterFuelPill.Visible = characterNow ~= nil and characterNow:FindFirstChild("Lighter") ~= nil
	if not myPart then
		dragSmoothedPart = nil
		dragSmoothedTarget = nil
	end

	canStore = false
	if myPart and myPart.Parent and not myPart.Parent:GetAttribute("OnSled") then
		local sledModel = workspace:FindFirstChild("Sled")
		local cargoPart = sledModel and (sledModel:FindFirstChild("CargoZone", true)
			or sledModel:FindFirstChild("RedaPart", true)
			or sledModel:FindFirstChild("Cargo", true))
		if cargoPart then
			local rel = cargoPart.CFrame:PointToObjectSpace(myPart.Position)
			local half = cargoPart.Size / 2 + Vector3.new(1.5, 2.5, 1.5)
			canStore = math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
		end
	end
	storeButton.Visible = canStore

	local draggedModel = myPart and myPart.Parent
	if draggedModel and draggedModel.Name == "Fish" then
		eatTarget = draggedModel
	else
		eatTarget = nearestFish()
	end
	eatButton.Visible = eatTarget ~= nil
	eatHint.Visible = eatButton.Visible

	if not myPart then
		return
	end
	if not myPart.Parent then
		myDragPart = nil
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local cf = myPart.CFrame
	local pos = cf.Position

	-- The item floats at a point in front of the camera: where you
	-- look is where it goes, including up and down (99 Nights style).
	local look = camera.CFrame.LookVector
	local anchor = root.Position + look * Config.Log.DragDistance

	local axisVec = dragLengthAxis(myPart.Size)
	local currentDir = dragHorizontal(cf:VectorToWorldSpace(axisVec))
	local faceDir = dragHorizontal(look)
	if currentDir:Dot(faceDir) < 0 then
		faceDir = -faceDir
	end
	local crossY = currentDir.Z * faceDir.X - currentDir.X * faceDir.Z
	local dotProd = currentDir.X * faceDir.X + currentDir.Z * faceDir.Z
	local yawDelta = math.atan2(crossY, dotProd) * (1 - math.exp(-dt * 4))
	if math.abs(yawDelta) > 0.0005 then
		cf = CFrame.new(cf.Position) * CFrame.Angles(0, yawDelta, 0) * (cf - cf.Position)
	end

	local size = myPart.Size
	local halfY = (math.abs(cf.RightVector.Y) * size.X
		+ math.abs(cf.UpVector.Y) * size.Y
		+ math.abs(cf.LookVector.Y) * size.Z) / 2

	-- Rest height comes from whatever solid surface is under the
	-- aim point: terrain, the sled bed, or the campfire — trees and
	-- other logs do not count, so canopies never lift the item.
	local exclude = { character, myPart.Parent, logsFolder }
	local treesFolder = workspace:FindFirstChild("Trees")
	if treesFolder then
		table.insert(exclude, treesFolder)
	end
	dragSurfaceParams.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(Vector3.new(anchor.X, 300, anchor.Z), Vector3.new(0, -600, 0), dragSurfaceParams)
	local minY = pos.Y
	if hit then
		minY = hit.Position.Y + halfY + 0.05
	end
	-- Carried items hover: looking level keeps them floating at the
	-- aim height, looking down settles them to hover height (never a
	-- ground scrape), looking up lifts toward the rise cap.
	local desiredY = math.max(anchor.Y, minY + Config.Log.DragHover)
	local targetY = math.clamp(desiredY, minY, root.Position.Y + Config.Log.DragMaxRise)
	local target = Vector3.new(anchor.X, targetY, anchor.Z)

	-- Glide, don't snap: the aim target is low-passed so terrain
	-- bumps stop shaking the carry height, the item eases toward it
	-- inside the server's accepted step speed, and physics velocity
	-- is zeroed every frame so gravity can't fight the hold between
	-- frames (that fight was the shake).
	if dragSmoothedPart ~= myPart then
		dragSmoothedPart = myPart
		dragSmoothedTarget = target
	end
	dragSmoothedTarget = dragSmoothedTarget:Lerp(target, 1 - math.exp(-dt * 10))
	local delta = dragSmoothedTarget - pos
	local gap = delta.Magnitude
	local newPos = pos
	if gap > 0.001 then
		local step = math.min(gap * (1 - math.exp(-dt * 12)), 38 * dt)
		newPos = pos + delta.Unit * step
	end

	myPart.CFrame = CFrame.new(newPos) * (cf - cf.Position)
	myPart.AssemblyLinearVelocity = Vector3.zero
	myPart.AssemblyAngularVelocity = Vector3.zero

	-- Stream the applied position as a movement intent at 20 Hz.
	-- The server validates reach and step speed per intent and keeps
	-- the last accepted position as the ledger the item must track.
	local now = os.clock()
	if now - lastDragSend >= 1 / 20 then
		lastDragSend = now
		DragSystem.SendUpdate(myPart, newPos)
	end
end)

-- Placement aim: the ghost follows the center of the camera while
-- placing a blueprint; the server makes the final call.
RunService.RenderStepped:Connect(function()
	if not placing then
		return
	end
	local camera = workspace.CurrentCamera
	local character = player.Character
	if not camera or not character then
		return
	end
	local ray = camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 80, params)
	if hit then
		aimPosition = hit.Position
		if buildGhost then
			buildGhost.CFrame = CFrame.new(hit.Position + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
		end
	end
end)
