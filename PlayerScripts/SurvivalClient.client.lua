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

local NAVY = Color3.fromHex("0B1E2E") -- Frost Night base: deep navy panels/backgrounds
local CYAN = Color3.fromHex("7FE7F2") -- Frost Night cold accent: glacier cyan
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
dayBanner.Size = UDim2.new(0.6, 0, 0, 34) -- Frost Night batch 1: Scale width so the banner never clips on narrow phones
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
objectivePanel.Size = UDim2.new(0.42, 40, 0, 30) -- Frost Night batch 1: Scale width (+40px floor so the text fits)
objectivePanel.AnchorPoint = Vector2.new(0.5, 0)
objectivePanel.Position = UDim2.new(0.5, 0, 0, 50)
objectivePanel.BackgroundColor3 = NAVY
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
	frame.BackgroundColor3 = NAVY
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
	fill.BackgroundColor3 = CYAN
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill
	return fill
end

local healthFrame = makeStatFrame("HealthFrame", UDim2.new(0.22, 40, 0, 36), UDim2.new(1, -6, 0, 3), Vector2.new(1, 0))
local healthFill = makeBar(healthFrame, "Health")
local warmthFrame = makeStatFrame("WarmthFrame", UDim2.new(0.18, 40, 0, 28), UDim2.new(0, 8, 0.42, 0), Vector2.new(0, 0))
-- Why warmth is moving, in words, right under the bar.
local warmthWhy = makeLabel(gui, "", UDim2.new(0.18, 40, 0, 14), UDim2.new(0, 14, 0.42, 31), SILVER, 11)
warmthWhy.TextXAlignment = Enum.TextXAlignment.Left
local warmthFill = makeBar(warmthFrame, "Warmth")
local hungerFrame = makeStatFrame("HungerFrame", UDim2.new(0.18, 40, 0, 28), UDim2.new(0, 8, 0.42, 34), Vector2.new(0, 0))
local hungerFill = makeBar(hungerFrame, "Hunger")


-- Wallet HUD (Frost Night batch 1, Phase 3 readout): the server
-- already publishes Coins / Pelts / FurPieces / Medkits / KidCount
-- via Gameplay:_syncAttributes, so this only READS player
-- attributes -- no new remote, no poll. Updated in refreshPlayer,
-- which already runs on player.AttributeChanged.
local walletFrame = makeStatFrame("WalletFrame", UDim2.new(0.22, 40, 0, 44), UDim2.new(1, -6, 0, 45), Vector2.new(1, 0))
local walletLine1 = makeLabel(walletFrame, "Coins: 0  Medkits: 0", UDim2.new(1, -8, 0, 18), UDim2.fromOffset(4, 3), CYAN, 12)
walletLine1.TextXAlignment = Enum.TextXAlignment.Center
local walletLine2 = makeLabel(walletFrame, "Pelts: 0  Fur: 0  Kids: 0", UDim2.new(1, -8, 0, 18), UDim2.fromOffset(4, 23), SILVER, 12)
walletLine2.TextXAlignment = Enum.TextXAlignment.Center

-- Wind pill (Frost Night batch 1, client-only): reads the wind
-- the server already publishes on ReplicatedStorage (WindDir /
-- WindStrength, used by the blowing-snow dressing). Compass is an
-- approximation from that published angle, not a new simulation.
local windFrame = makeStatFrame("WindFrame", UDim2.new(0.18, 40, 0, 26), UDim2.new(0, 8, 0.42, 68), Vector2.new(0, 0))
local windLabel = makeLabel(windFrame, "Wind --", UDim2.new(1, -8, 0, 18), UDim2.fromOffset(4, 4), CYAN, 12)
windLabel.TextXAlignment = Enum.TextXAlignment.Center
local function refreshWind()
	local dir = ReplicatedStorage:GetAttribute("WindDir") or 0.8
	local strength = ReplicatedStorage:GetAttribute("WindStrength") or 0.2
	local dirs = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
	local deg = (math.deg(dir) % 360 + 360) % 360
	local idx = math.floor(((deg + 22.5) % 360) / 45) + 1
	windLabel.Text = ("Wind %s · %d%%"):format(dirs[idx], math.floor(strength * 100 + 0.5))
end
ReplicatedStorage:GetAttributeChangedSignal("WindDir"):Connect(refreshWind)
ReplicatedStorage:GetAttributeChangedSignal("WindStrength"):Connect(refreshWind)
refreshWind()

-- Lighter fuel: a small pill floating just over the hotbar,
-- visible only while the lighter is in hand.
local lighterFuelPill = makeStatFrame("LighterFuel", UDim2.new(0.14, 40, 0, 26), UDim2.new(0.5, 0, 1, -118), Vector2.new(0.5, 0))
lighterFuelPill.Visible = false
local lighterFuelLabel = makeLabel(lighterFuelPill, "Fuel: 100", UDim2.new(1, 0, 1, 0), UDim2.fromOffset(0, 0), SILVER, 13)
lighterFuelLabel.TextXAlignment = Enum.TextXAlignment.Center

local sprintButton = Instance.new("TextButton")
sprintButton.Name = "SprintButton"
sprintButton.Size = UDim2.fromOffset(72, 72)
sprintButton.Position = UDim2.new(1, -88, 1, -84)
sprintButton.TextSize = 13
sprintButton.BackgroundColor3 = MARIGOLD
sprintButton.Text = "SPRINT"
sprintButton.TextColor3 = NAVY
sprintButton.TextSize = 17
sprintButton.Font = Enum.Font.GothamBold
sprintButton.BorderSizePixel = 0
sprintButton.Parent = gui

local sprintCorner = Instance.new("UICorner")
sprintCorner.CornerRadius = UDim.new(0.5, 0)
sprintCorner.Parent = sprintButton
addStroke(sprintButton, NAVY, 1.5, 0.25)

-- Context action: appears while a dragged log hovers over the sled's
-- cargo zone. Tappable on touch, clickable on PC, key-bound per
-- platform (E on keyboard, X on gamepad).
local storeButton = Instance.new("TextButton")
storeButton.Name = "StoreButton"
storeButton.Size = UDim2.fromOffset(72, 72)
storeButton.Position = UDim2.new(1, -88, 1, -164)
storeButton.TextSize = 14
storeButton.BackgroundColor3 = CYAN
storeButton.Text = ""
storeButton.AutoButtonColor = true
storeButton.BorderSizePixel = 0
storeButton.Visible = false
storeButton.Parent = gui

local storeCorner = Instance.new("UICorner")
storeCorner.CornerRadius = UDim.new(0.5, 0)
storeCorner.Parent = storeButton
addStroke(storeButton, NAVY, 1.5, 0.25)

local storeTitle = makeLabel(storeButton, "STORE ITEM", UDim2.new(1, -8, 0, 22), UDim2.fromOffset(4, 6), NAVY, 15)
storeTitle.TextXAlignment = Enum.TextXAlignment.Center
local storeHint = makeLabel(storeButton, "", UDim2.fromOffset(100, 14), UDim2.new(0.5, -50, 1, 2), SILVER, 11)
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
eatButton.Size = UDim2.fromOffset(72, 72)
eatButton.Position = UDim2.new(1, -88, 1, -244)
eatButton.BackgroundColor3 = CYAN
eatButton.Text = "EAT"
eatButton.TextSize = 14
eatButton.TextColor3 = NAVY
eatButton.TextSize = 16
eatButton.Font = Enum.Font.GothamBold
eatButton.BorderSizePixel = 0
eatButton.Visible = false
eatButton.Parent = gui
local eatCorner = Instance.new("UICorner")
eatCorner.CornerRadius = UDim.new(0.5, 0)
eatCorner.Parent = eatButton
addStroke(eatButton, NAVY, 1.5, 0.25)
local eatHint = makeLabel(eatButton, "tap", UDim2.fromOffset(100, 14), UDim2.new(0.5, -50, 1, 2), SILVER, 11)
eatHint.TextXAlignment = Enum.TextXAlignment.Center
eatHint.Visible = false

-- Grab / Drop button: ONE context button for dragging. It shows
-- GRAB while the center dot is on a draggable item and the hands
-- are empty; while carrying it shows DROP (and only DROP -- you
-- can't grab a second thing). Replaces the per-item prompts.
local dragActionRemote = remotes:WaitForChild("DragAction")
local grabButton = Instance.new("TextButton")
grabButton.Name = "GrabButton"
grabButton.Size = UDim2.fromOffset(72, 72)
grabButton.Position = UDim2.new(1, -88, 1, -324)
grabButton.TextSize = 14
grabButton.BackgroundColor3 = CYAN
grabButton.Text = "GRAB"
grabButton.TextColor3 = NAVY
grabButton.TextSize = 16
grabButton.Font = Enum.Font.GothamBold
grabButton.BorderSizePixel = 0
grabButton.Visible = false
grabButton.Parent = gui
local grabCorner = Instance.new("UICorner")
grabCorner.CornerRadius = UDim.new(0.5, 0)
grabCorner.Parent = grabButton
addStroke(grabButton, NAVY, 1.5, 0.25)
local grabTarget = nil
grabButton.Activated:Connect(function()
	if myDragPartRef and myDragPartRef() then
		dragActionRemote:FireServer("Drop")
	elseif grabTarget then
		dragActionRemote:FireServer("Grab", grabTarget)
	end
end)

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
buildMenu.Size = UDim2.new(0.42, 40, 0, 200) -- Frost Night batch 1: Scale width, centered by anchor
buildMenu.AnchorPoint = Vector2.new(0.5, 0.5)
buildMenu.Position = UDim2.new(0.5, 0, 0.5, 0)
buildMenu.BackgroundColor3 = NAVY
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

-- One button per buildable structure, generated from
-- Config.Structures (Phase 3: new structures appear here by
-- adding a registry entry -- no menu code changes).
local startPlacing -- forward-declared; defined with the ghost below
local selectedStructure = "Campfire"
local structureButtons = 0
for _, structureId in ipairs(Config.StructureOrder) do
	local def = Config.Structures[structureId]
	if def then
		structureButtons += 1
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(0.55, 0, 0, 46)
		button.Position = UDim2.new(0.04, 0, 0, 42 + (structureButtons - 1) * 52)
		button.BackgroundColor3 = CYAN
		button.Text = def.ButtonText
		button.TextColor3 = NAVY
		button.TextSize = 15
		button.Font = Enum.Font.GothamBold
		button.BorderSizePixel = 0
		button.Parent = buildMenu
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = button
		addStroke(button, NAVY, 1.5, 0.25)
		local id = structureId
		button.Activated:Connect(function()
			selectedStructure = id
			if startPlacing then
				startPlacing()
			end
		end)
	end
end

local buildIconHolder = Instance.new("Frame")
buildIconHolder.Name = "BuildIconHolder"
buildIconHolder.Size = UDim2.new(0.33, 0, 0, 100)
buildIconHolder.Position = UDim2.new(0.62, 0, 0, 42)
buildIconHolder.BackgroundTransparency = 1
buildIconHolder.BorderSizePixel = 0
buildIconHolder.Parent = buildMenu

buildMenu.Size = UDim2.new(0.42, 40, 0, 42 + structureButtons * 52 + 52)
local buildCloseButton = Instance.new("TextButton")
buildCloseButton.Size = UDim2.new(1, -24, 0, 34)
buildCloseButton.Position = UDim2.fromOffset(12, 42 + structureButtons * 52 + 6)
buildCloseButton.BackgroundColor3 = SILVER
buildCloseButton.BackgroundTransparency = 0.4
buildCloseButton.Text = "Close"
buildCloseButton.TextColor3 = NAVY
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
placeButton.BackgroundColor3 = CYAN
placeButton.Text = "PLACE HERE"
placeButton.TextColor3 = NAVY
placeButton.TextSize = 16
placeButton.Font = Enum.Font.GothamBold
placeButton.BorderSizePixel = 0
placeButton.Visible = false
placeButton.Parent = gui
local placeCorner = Instance.new("UICorner")
placeCorner.CornerRadius = UDim.new(0, 12)
placeCorner.Parent = placeButton
addStroke(placeButton, NAVY, 1.5, 0.25)

local cancelPlaceButton = Instance.new("TextButton")
cancelPlaceButton.Name = "CancelPlaceButton"
cancelPlaceButton.Size = UDim2.fromOffset(110, 50)
cancelPlaceButton.Position = UDim2.new(0.5, 2, 1, -128)
cancelPlaceButton.BackgroundColor3 = SILVER
cancelPlaceButton.BackgroundTransparency = 0.25
cancelPlaceButton.Text = "Cancel"
cancelPlaceButton.TextColor3 = NAVY
cancelPlaceButton.TextSize = 15
cancelPlaceButton.Font = Enum.Font.GothamBold
cancelPlaceButton.BorderSizePixel = 0
cancelPlaceButton.Visible = false
cancelPlaceButton.Parent = gui
local cancelPlaceCorner = Instance.new("UICorner")
cancelPlaceCorner.CornerRadius = UDim.new(0, 12)
cancelPlaceCorner.Parent = cancelPlaceButton
addStroke(cancelPlaceButton, NAVY, 1.5, 0.4)

local function stopPlacing()
	placing = false
	placeButton.Visible = false
	cancelPlaceButton.Visible = false
	if buildGhost then
		buildGhost.Parent = nil
	end
end

startPlacing = function()
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
		buildGhost.Color = CYAN -- Frost Night: placement preview is not fire, so not marigold
		buildGhost.Transparency = 0.45
	end
	buildGhost.Parent = workspace
	placing = true
	placeButton.Visible = true
	cancelPlaceButton.Visible = true
end

cancelPlaceButton.Activated:Connect(stopPlacing)
placeButton.Activated:Connect(function()
	if aimPosition then
		placeBlueprintRemote:FireServer(aimPosition, selectedStructure)
	end
	stopPlacing()
end)

local hotbar = Instance.new("Frame")
hotbar.Name = "Hotbar"
hotbar.Size = UDim2.fromOffset(302, 56)
hotbar.Position = UDim2.new(0.5, -151, 1, -64)
hotbar.BackgroundColor3 = NAVY
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
	addStroke(slot, NAVY, 1, 0.6)
	local icon = Instance.new("Frame")
	icon.Name = "IconHolder"
	icon.Size = UDim2.new(0.65, 0, 0.76, 0)
	icon.Position = UDim2.new(0.18, 0, 0.03, 0)
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.Parent = slot
	local label = makeLabel(slot, "", UDim2.new(1, -8, 0, 12), UDim2.fromOffset(4, 46), SILVER, 11)
	label.TextXAlignment = Enum.TextXAlignment.Center
	local value = makeLabel(slot, "", UDim2.new(1, -8, 0, 18), UDim2.fromOffset(4, 24), CYAN, 13)
	value.Visible = false
	value.TextXAlignment = Enum.TextXAlignment.Center
	local hint = makeLabel(slot, "", UDim2.fromOffset(24, 14), UDim2.fromOffset(3, 2), NAVY, 11)
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
	clone.Size = UDim2.fromScale(1, 1)
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
			entry.Frame.BackgroundColor3 = equipped and CYAN or SILVER
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
	local def = Config.Structures[selectedStructure] or Config.Structures.Campfire
	local pointFrames = ReplicatedStorage:FindFirstChild("PointFrames")
	local template = pointFrames and pointFrames:FindFirstChild(def.FrameName)
	if template and template:IsA("ViewportFrame") then
		local clone = template:Clone()
		clone.Size = UDim2.fromScale(1, 1)
		clone.Position = UDim2.fromOffset(0, 0)
		clone.Parent = buildIconHolder
		buildIconLive = clone
		return
	end
	local vpf = Instance.new("ViewportFrame")
	vpf.Size = UDim2.fromScale(1, 1)
	vpf.Position = UDim2.fromOffset(0, 0)
	vpf.BackgroundColor3 = Color3.fromRGB(11, 30, 46)
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
	local fireModel = assets and assets:FindFirstChild(def.AssetName)
	if fireModel then
		setViewportIcon(vpf, fireModel, selectedStructure)
	end
end
buildMenu:GetPropertyChangedSignal("Visible"):Connect(function()
	if buildMenu.Visible then
		showBuildIcon()
	else
		clearBuildIcon()
	end
end)

-- Coughs: the server bumps a player's CoughCount attribute
-- when he coughs (sickness). Show a "*cough!*" tag over his
-- head briefly; if a Sound named "Cough" is ever added to
-- SoundService it plays too -- asset-optional, like the
-- wolves' AttackAnim hook.
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local function showCough(anyPlayer)
	local character = anyPlayer.Character
	local head = character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
	if not head then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CoughTag"
	billboard.Size = UDim2.fromOffset(110, 30)
	billboard.StudsOffset = Vector3.new(0, 2.6, 0)
	billboard.MaxDistance = 60
	billboard.Adornee = head
	billboard.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "*cough!*"
	label.TextColor3 = MARIGOLD
	label.TextSize = 16
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard
	Debris:AddItem(billboard, 1.2)
	local template = SoundService:FindFirstChild("Cough")
	if template and template:IsA("Sound") then
		local sound = template:Clone()
		sound.Parent = head
		sound:Play()
		Debris:AddItem(sound, 2)
	end
end
local function watchCoughs(anyPlayer)
	anyPlayer:GetAttributeChangedSignal("CoughCount"):Connect(function()
		showCough(anyPlayer)
	end)
end
for _, anyPlayer in ipairs(Players:GetPlayers()) do
	watchCoughs(anyPlayer)
end
Players.PlayerAdded:Connect(watchCoughs)

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

-- Toasts: small event lines under the day banner (fish caught,
-- fish cooked, wolf tamed, warnings). They stack, sit ~3s, fade.
local TweenService = game:GetService("TweenService")
local toastHolder = Instance.new("Frame")
toastHolder.Name = "Toasts"
toastHolder.Size = UDim2.new(0.4, 0, 0, 120)
toastHolder.AnchorPoint = Vector2.new(0.5, 0)
toastHolder.Position = UDim2.new(0.5, 0, 0, 88)
toastHolder.BackgroundTransparency = 1
toastHolder.BorderSizePixel = 0
toastHolder.Parent = gui
local toastLayout = Instance.new("UIListLayout")
toastLayout.FillDirection = Enum.FillDirection.Vertical
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
toastLayout.Padding = UDim.new(0, 5)
toastLayout.Parent = toastHolder

local function toast(text)
	local labels = {}
	for _, child in ipairs(toastHolder:GetChildren()) do
		if child:IsA("TextLabel") then
			table.insert(labels, child)
		end
	end
	while #labels >= 3 do
		table.remove(labels, 1):Destroy()
	end
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.94, 0, 0, 28)
	label.BackgroundColor3 = NAVY
	label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.Text = text
	label.BorderSizePixel = 0
	label.Parent = toastHolder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 1
	stroke.Transparency = 0.5
	stroke.Parent = label
	task.delay(3.2, function()
		if not label.Parent then
			return
		end
		local fade = TweenService:Create(label, TweenInfo.new(0.5), { BackgroundTransparency = 1, TextTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		label:Destroy()
	end)
end
remotes:WaitForChild("Notify").OnClientEvent:Connect(toast)

-- Danger: a red edge pulse + label while a wolf is hunting you.
local dangerFrame = Instance.new("Frame")
dangerFrame.Name = "DangerFrame"
dangerFrame.Size = UDim2.fromScale(1, 1)
dangerFrame.BackgroundTransparency = 1
dangerFrame.BorderSizePixel = 0
dangerFrame.Visible = false
dangerFrame.Parent = gui
local dangerStroke = Instance.new("UIStroke")
dangerStroke.Color = Color3.fromRGB(214, 48, 43)
dangerStroke.Thickness = 5
dangerStroke.Transparency = 0.5
dangerStroke.Parent = dangerFrame
local dangerLabel = makeLabel(gui, "WOLVES ARE HUNTING YOU", UDim2.new(0.4, 0, 0, 24), UDim2.new(0.5, 0, 0, 128), Color3.fromRGB(255, 90, 80), 17)
dangerLabel.AnchorPoint = Vector2.new(0.5, 0)
dangerLabel.TextXAlignment = Enum.TextXAlignment.Center
dangerLabel.Visible = false
local dangerStroke2 = Instance.new("UIStroke")
dangerStroke2.Color = Color3.new(0, 0, 0)
dangerStroke2.Thickness = 1.2
dangerStroke2.Parent = dangerLabel

local lastColdWarn = 0
local lastFoodWarn = 0

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
	local hungerNow = player:GetAttribute("Hunger") or Config.Survival.MaxHunger
	hungerFill.BackgroundColor3 = hungerNow <= 10 and Color3.fromRGB(214, 48, 43) or CYAN
	-- Warmth reason + danger + the two loud warnings (cooldowned).
	local warmState = player:GetAttribute("WarmState") or ""
	warmthWhy.Text = warmState
	warmthWhy.TextColor3 = warmState == "Freezing" and Color3.fromRGB(255, 90, 80)
		or warmState == "By the fire" and Color3.fromRGB(255, 190, 90)
		or SILVER
	local inDanger = player:GetAttribute("InDanger") == true
	dangerFrame.Visible = inDanger
	dangerLabel.Visible = inDanger
	if inDanger then
		dangerStroke.Transparency = 0.35 + 0.3 * math.sin(os.clock() * 6)
	end
	local nowClock = os.clock()
	if warmthNow <= 25 and nowClock - lastColdWarn > 45 then
		lastColdWarn = nowClock
		toast("You're freezing -- get to a fire!")
	end
	if hungerNow <= 8 and nowClock - lastFoodWarn > 45 then
		lastFoodWarn = nowClock
		toast("You're starving -- eat something!")
	end
	lighterFuelLabel.Text = "Fuel: " .. tostring(player:GetAttribute("LighterFuel") or 0)
	walletLine1.Text = ("Coins: %d  Medkits: %d"):format(player:GetAttribute("Coins") or 0, player:GetAttribute("Medkits") or 0)
	walletLine2.Text = ("Pelts: %d  Fur: %d  Kids: %d"):format(player:GetAttribute("Pelts") or 0, player:GetAttribute("FurPieces") or 0, player:GetAttribute("KidCount") or 0)
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

-- Wolf command buttons (bottom-left circles): appear once you
-- own a wolf. The active mode is marigold. ATTACK sends where
-- your center dot is pointing; your dogs charge the animal
-- nearest that spot.
local wolfCommandRemote = remotes:WaitForChild("WolfCommand")
local wolfButtons = {}
for i, mode in ipairs({ "Follow", "Wander", "Alert", "Attack" }) do
	local b = Instance.new("TextButton")
	b.Name = "Wolf" .. mode
	b.Size = UDim2.fromOffset(56, 56)
	b.Position = UDim2.new(0, 14, 1, -76 - (i - 1) * 64)
	b.BackgroundColor3 = SILVER
	b.BackgroundTransparency = 0.25
	b.TextColor3 = NAVY
	b.Font = Enum.Font.GothamBold
	b.TextSize = 10
	b.Text = mode:upper()
	b.AutoButtonColor = true
	b.Visible = false
	b.Parent = gui
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0.5, 0)
	bc.Parent = b
	addStroke(b, NAVY, 1.5, 0.5)
	b.Activated:Connect(function()
		local targetPos
		if mode == "Attack" then
			local cam = workspace.CurrentCamera
			if cam then
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { player.Character }
				local hit = workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 60, params)
				targetPos = hit and hit.Position or (cam.CFrame.Position + cam.CFrame.LookVector * 35)
			end
		end
		wolfCommandRemote:FireServer(mode, targetPos)
	end)
	wolfButtons[mode] = b
end

local function refreshWolfButtons()
	local count = player:GetAttribute("WolfCount") or 0
	local active = player:GetAttribute("WolfCommand") or "Follow"
	for m, b in pairs(wolfButtons) do
		b.Visible = count > 0
		b.BackgroundColor3 = m == active and CYAN or SILVER
	end
end
player:GetAttributeChangedSignal("WolfCount"):Connect(refreshWolfButtons)
player:GetAttributeChangedSignal("WolfCommand"):Connect(refreshWolfButtons)
refreshWolfButtons()

-- Fishing panel: driven by server-published attributes
-- (FishingPhase / FishingProgress / FishingStartAt / FishingSeed).
-- The reel needle and zone are pure functions of elapsed time from
-- the shared start values -- the same math the server judges taps
-- with -- so they render locally at full frame rate.
local fishingPanel = Instance.new("Frame")
fishingPanel.Name = "FishingPanel"
fishingPanel.Size = UDim2.new(0.55, 0, 0, 124) -- Frost Night batch 1: Scale width
fishingPanel.AnchorPoint = Vector2.new(0.5, 0)
fishingPanel.Position = UDim2.new(0.5, 0, 1, -208)
fishingPanel.BackgroundTransparency = 1
fishingPanel.BorderSizePixel = 0
fishingPanel.Visible = false
fishingPanel.Parent = gui
local fishingTitle = makeLabel(fishingPanel, "", UDim2.new(1, -16, 0, 30), UDim2.fromOffset(8, 6), Color3.new(1, 1, 1), 18)
local fishingTitleStroke = Instance.new("UIStroke")
fishingTitleStroke.Color = Color3.new(0, 0, 0)
fishingTitleStroke.Thickness = 1.4
fishingTitleStroke.Parent = fishingTitle
fishingTitle.TextXAlignment = Enum.TextXAlignment.Center
local reelTrack = Instance.new("Frame")
reelTrack.Size = UDim2.new(0.93, 0, 0, 26)
reelTrack.Position = UDim2.new(0.035, 0, 0, 46)
reelTrack.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
reelTrack.BackgroundTransparency = 0.35
reelTrack.BorderSizePixel = 0
reelTrack.Parent = fishingPanel
local reelTrackCorner = Instance.new("UICorner")
reelTrackCorner.CornerRadius = UDim.new(0, 6)
reelTrackCorner.Parent = reelTrack
addStroke(reelTrack, SILVER, 1, 0.4)
local catchBar = Instance.new("Frame")
catchBar.BackgroundColor3 = Color3.new(1, 1, 1)
catchBar.BackgroundTransparency = 0.45
catchBar.BorderSizePixel = 0
catchBar.Size = UDim2.fromOffset(120, 26)
catchBar.Parent = reelTrack
local catchBarCorner = Instance.new("UICorner")
catchBarCorner.CornerRadius = UDim.new(0, 6)
catchBarCorner.Parent = catchBar
addStroke(catchBar, Color3.new(1, 1, 1), 1.5, 0.15)
local fishMarker = Instance.new("Frame")
fishMarker.Size = UDim2.fromOffset(16, 16)
fishMarker.BackgroundColor3 = Color3.fromRGB(240, 120, 40)
fishMarker.BorderSizePixel = 0
fishMarker.Rotation = 45
fishMarker.ZIndex = 3
fishMarker.Parent = reelTrack
local fishMarkerCorner = Instance.new("UICorner")
fishMarkerCorner.CornerRadius = UDim.new(0, 4)
fishMarkerCorner.Parent = fishMarker
local progressTrack = Instance.new("Frame")
progressTrack.Size = UDim2.new(0.93, 0, 0, 10)
progressTrack.Position = UDim2.new(0.035, 0, 0, 84)
progressTrack.BackgroundColor3 = SILVER
progressTrack.BackgroundTransparency = 0.7
progressTrack.BorderSizePixel = 0
progressTrack.Parent = fishingPanel
local progressFill = Instance.new("Frame")
progressFill.BackgroundColor3 = CYAN
progressFill.BorderSizePixel = 0
progressFill.Size = UDim2.fromScale(0, 1)
progressFill.Parent = progressTrack

-- Bite badge: a big marigold circle with a "!" -- impossible to
-- miss. Waiting gets a small pulsing bobber dot instead.
local biteBadge = Instance.new("Frame")
biteBadge.Size = UDim2.fromOffset(64, 64)
biteBadge.Position = UDim2.new(0.5, -32, 0, 30)
biteBadge.BackgroundColor3 = MARIGOLD
biteBadge.BorderSizePixel = 0
biteBadge.Visible = false
biteBadge.Parent = fishingPanel
local biteBadgeCorner = Instance.new("UICorner")
biteBadgeCorner.CornerRadius = UDim.new(0.5, 0)
biteBadgeCorner.Parent = biteBadge
local biteBadgeText = makeLabel(biteBadge, "!", UDim2.new(1, 0, 1, 0), UDim2.fromOffset(0, -2), NAVY, 42)
biteBadgeText.TextXAlignment = Enum.TextXAlignment.Center
local bobberDot = Instance.new("Frame")
bobberDot.Size = UDim2.fromOffset(14, 14)
bobberDot.Position = UDim2.new(0.5, -7, 0, 42)
bobberDot.BackgroundColor3 = Color3.fromRGB(214, 48, 43)
bobberDot.BorderSizePixel = 0
bobberDot.Visible = false
bobberDot.Parent = fishingPanel
local bobberDotCorner = Instance.new("UICorner")
bobberDotCorner.CornerRadius = UDim.new(0.5, 0)
bobberDotCorner.Parent = bobberDot

local fishingSyncRemote = remotes:WaitForChild("FishingSync")

-- Same wander the server judges with (shared start + seed).
local function clientFishPos(elapsed, seed)
	local p = 0.5
		+ 0.36 * math.sin(elapsed * 0.8 + seed)
		+ 0.12 * math.sin(elapsed * 2.3 + seed * 2)
	return math.clamp(p, 0.08, 0.92)
end

-- Hold to raise your catch bar; let go and it sinks. Mouse, touch,
-- space, or gamepad A all count.
local reelHolding = false
UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.Space
		or input.KeyCode == Enum.KeyCode.ButtonA
	then
		reelHolding = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.Space
		or input.KeyCode == Enum.KeyCode.ButtonA
	then
		reelHolding = false
	end
end)

local localBar = 0.5
local lastSync = 0
local lastPhase = ""
game:GetService("RunService").Heartbeat:Connect(function(dt)
	local phase = player:GetAttribute("FishingPhase")
	if phase == "Reel" and lastPhase ~= "Reel" then
		localBar = 0.5
	end
	lastPhase = phase or ""
	fishingPanel.Visible = phase ~= nil and phase ~= ""
	if not fishingPanel.Visible then
		return
	end
	local inReel = phase == "Reel"
	reelTrack.Visible = inReel
	progressTrack.Visible = inReel
	biteBadge.Visible = phase == "Bite"
	bobberDot.Visible = phase == "Waiting"
	if phase == "Waiting" then
		fishingTitle.Text = "Waiting for a bite..."
		local pulse = 14 + math.sin(os.clock() * 3) * 2.5
		bobberDot.Size = UDim2.fromOffset(pulse, pulse)
		bobberDot.Position = UDim2.new(0.5, -pulse / 2, 0, 42)
	elseif phase == "Bite" then
		fishingTitle.Text = ""
		local pulse = 1 + math.sin(os.clock() * 10) * 0.08
		biteBadge.Size = UDim2.fromOffset(64 * pulse, 64 * pulse)
		biteBadge.Position = UDim2.new(0.5, -32 * pulse, 0, 30)
	elseif inReel then
		fishingTitle.Text = "Keep the fish in your bar -- HOLD to raise it!"
		local startAt = player:GetAttribute("FishingStartAt") or 0
		local seed = player:GetAttribute("FishingSeed") or 0
		local elapsed = math.max(0, workspace:GetServerTimeNow() - startAt)
		-- Your bar is integrated locally (smooth) and streamed to
		-- the server, which keeps the judging copy.
		if reelHolding then
			localBar += Config.Fishing.ReelRiseSpeed * dt
		else
			localBar -= Config.Fishing.ReelFallSpeed * dt
		end
		localBar = math.clamp(localBar, 0.03, 0.97)
		local now = os.clock()
		if now - lastSync > 0.066 then
			lastSync = now
			fishingSyncRemote:FireServer(localBar)
		end
		local fish = clientFishPos(elapsed, seed)
		local trackWidth = reelTrack.AbsoluteSize.X
		local half = Config.Fishing.ReelBarHalf
		catchBar.Size = UDim2.fromOffset(trackWidth * half * 2, 26)
		catchBar.Position = UDim2.fromOffset((localBar - half) * trackWidth, 0)
		local overlap = math.abs(localBar - fish) <= half
		catchBar.BackgroundColor3 = overlap and CYAN or Color3.new(1, 1, 1)
		fishMarker.Position = UDim2.fromOffset(fish * trackWidth - 8, 5)
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

-- GRAB/DROP button state: DROP while carrying; otherwise GRAB
-- when the center dot rests on a free draggable item. Any part of
-- an item counts (a fish is five parts) -- resolve to the part
-- the server marked Draggable, and outline the whole item so
-- it's obvious WHICH one will be grabbed.
local grabHighlight = Instance.new("Highlight")
grabHighlight.Name = "GrabHighlight"
grabHighlight.FillColor = Color3.fromRGB(234, 160, 0)
grabHighlight.FillTransparency = 0.82
grabHighlight.OutlineColor = Color3.new(1, 1, 1)
grabHighlight.OutlineTransparency = 0.1
grabHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

local function draggablePartOf(instance)
	if not instance then
		return nil
	end
	if instance:IsA("BasePart") and instance:GetAttribute("Draggable") == true then
		return instance
	end
	local model = instance.Parent
	if model and model:GetAttribute("Draggable") == true then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d:GetAttribute("Draggable") == true then
				return d
			end
		end
		return model:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end
function myDragPartRef()
	return myDragPart
end
local grabParams = RaycastParams.new()
grabParams.FilterType = Enum.RaycastFilterType.Exclude
grabParams.IgnoreWater = true
local lastGrabCheck = 0
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	if now - lastGrabCheck < 0.08 then
		return
	end
	lastGrabCheck = now
	if myDragPart then
		grabTarget = nil
		grabButton.Text = "DROP"
		grabButton.Visible = true
		grabHighlight.Parent = nil
		return
	end
	local camera = workspace.CurrentCamera
	local character = player.Character
	if not camera or not character then
		grabButton.Visible = false
		return
	end
	grabParams.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 14, grabParams)
	local part = draggablePartOf(hit and hit.Instance)
	if not part then
		-- Forgiving probe: thin items (a flat fish on the ice)
		-- slip past a pixel-perfect ray and the grab feels stuck.
		-- Anything draggable passing within ~1.9 studs of the
		-- aim line counts.
		local origin = camera.CFrame.Position
		local dir = camera.CFrame.LookVector
		local bestT = math.huge
		local fishFolderNow = workspace:FindFirstChild("Fish")
		for _, folder in ipairs({ logsFolder, fishFolderNow }) do
			if folder then
				for _, model in ipairs(folder:GetChildren()) do
					local anyPart = model:IsA("BasePart") and model or model:FindFirstChildWhichIsA("BasePart", true)
					local candidate = anyPart and draggablePartOf(anyPart)
					if candidate and candidate:GetAttribute("DraggedBy") == nil then
						local rel = candidate.Position - origin
						local t = rel:Dot(dir)
						if t > 1.5 and t < 14 and t < bestT then
							local closest = origin + dir * t
							if (candidate.Position - closest).Magnitude <= 1.9 then
								part = candidate
								bestT = t
							end
						end
					end
				end
			end
		end
	end
	if part and part:GetAttribute("DraggedBy") == nil then
		grabTarget = part
		grabButton.Text = "GRAB"
		grabButton.Visible = true
		local model = part.Parent
		grabHighlight.Parent = (model and model:IsA("Model")) and model or part
	else
		grabTarget = nil
		grabButton.Visible = false
		grabHighlight.Parent = nil
	end
end)
-- Fish live in their own folder but drag exactly like logs; the
-- tracker must watch them too or a caught fish never moves.
local fishFolder = workspace:WaitForChild("Fish")
for _, fish in ipairs(fishFolder:GetChildren()) do
	trackLog(fish)
end
fishFolder.ChildAdded:Connect(trackLog)

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
	dragDot.Visible = true -- the dot is always on: it is your aim
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

-- Wind life (client-only dressing): blowing snow around the
-- camera plus trees and grass tufts rocking in the gusts. The
-- server publishes WindDir / WindStrength on ReplicatedStorage.
do
	local windPart = Instance.new("Part")
	windPart.Name = "WindSnowVolume"
	windPart.Size = Vector3.new(48, 16, 48)
	windPart.Transparency = 1
	windPart.CanCollide = false
	windPart.CanQuery = false
	windPart.Anchored = true
	windPart.Parent = workspace
	local snow = Instance.new("ParticleEmitter")
	snow.Name = "BlowingSnow"
	snow.Shape = Enum.ParticleEmitterShape.Box
	snow.Color = ColorSequence.new(Color3.fromRGB(236, 242, 250))
	snow.LightEmission = 0.25
	snow.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	snow.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	snow.Lifetime = NumberRange.new(1.2, 2.2)
	snow.Speed = NumberRange.new(1, 4)
	snow.Drag = 0.4
	snow.Rate = 0
	snow.Parent = windPart

	local swayTargets = {}
	local function collectSway()
		for _, folderName in ipairs({ "Trees", "Tufts" }) do
			local folder = workspace:FindFirstChild(folderName)
			if folder then
				for _, model in ipairs(folder:GetChildren()) do
					if (model:IsA("Model") or model:IsA("BasePart")) and not model:GetAttribute("SwayTracked") then
						model:SetAttribute("SwayTracked", true)
						local cf, size
						if model:IsA("Model") then
							cf, size = model:GetBoundingBox()
						else
							cf, size = model.CFrame, model.Size
						end
						table.insert(swayTargets, {
							Model = model,
							Base = model:GetPivot(),
							Ground = Vector3.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z),
							Amp = folderName == "Tufts" and 2.3 or 1,
						})
					end
				end
			end
		end
	end

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if camera then
			windPart.CFrame = CFrame.new(camera.CFrame.Position)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.12)
			local dir = ReplicatedStorage:GetAttribute("WindDir") or 0.8
			local strength = ReplicatedStorage:GetAttribute("WindStrength") or 0.2
			local windVec = Vector3.new(math.sin(dir), 0, math.cos(dir))
			snow.Rate = 30 + 300 * strength
			snow.Acceleration = windVec * (10 + 34 * strength) + Vector3.new(0, -3, 0)
			collectSway()
			local camera = workspace.CurrentCamera
			if camera then
				local camPos = camera.CFrame.Position
				local axis = Vector3.new(windVec.Z, 0, -windVec.X)
				local now = os.clock()
				local swaySpeed = 1.2 + strength * 2.4
				for i = #swayTargets, 1, -1 do
					local target = swayTargets[i]
					if not target.Model.Parent then
						table.remove(swayTargets, i)
					elseif (target.Ground - camPos).Magnitude < 230 then
						local phase = (target.Ground.X * 0.37 + target.Ground.Z * 0.53) % (math.pi * 2)
						local theta = math.sin(now * swaySpeed + phase) * (0.012 + 0.03 * strength) * target.Amp
						local rotated = CFrame.new(target.Ground)
							* CFrame.fromAxisAngle(axis, theta)
							* CFrame.new(-target.Ground)
						target.Model:PivotTo(rotated * target.Base)
					end
				end
			end
		end
	end)
end

-- Aurora (client dressing): three neon ribbons high overhead
-- that fade in at night and drift with slow sine undulation.
do
	local ribbons = {}
	local ribbonColors = {
		Color3.fromRGB(92, 255, 172),
		Color3.fromRGB(84, 214, 255),
		Color3.fromRGB(176, 128, 255),
	}
	for i = 1, 3 do
		local ribbon = Instance.new("Part")
		ribbon.Name = "AuroraRibbon" .. i
		ribbon.Size = Vector3.new(300 + i * 60, 22 + i * 6, 1)
		ribbon.Color = ribbonColors[i]
		ribbon.Material = Enum.Material.Neon
		ribbon.Transparency = 1
		ribbon.CanCollide = false
		ribbon.CanQuery = false
		ribbon.Anchored = true
		ribbon.Parent = workspace
		ribbons[i] = ribbon
	end

	local fade = 0
	RunService.RenderStepped:Connect(function(dt)
		local isNight = ReplicatedStorage:GetAttribute("Phase") == "Night"
		fade = math.clamp(fade + (isNight and dt * 0.25 or -dt * 0.25), 0, 1)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local camPos = camera.CFrame.Position
		local now = os.clock()
		for i, ribbon in ipairs(ribbons) do
			local sway = math.sin(now * 0.22 + i * 1.7) * 14
			local tilt = math.sin(now * 0.16 + i * 2.3) * 0.07
			ribbon.CFrame = CFrame.new(
				camPos.X + sway * i,
				135 + i * 16,
				camPos.Z - 70 - i * 38
			) * CFrame.Angles(0, math.sin(now * 0.05 + i) * 0.25, tilt)
			ribbon.Transparency = 1 - fade * (0.42 + 0.13 * math.sin(now * 0.4 + i * 2.1))
		end
	end)
end
