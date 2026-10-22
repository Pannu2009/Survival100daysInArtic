local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local StarterGui = game:GetService("StarterGui")
task.spawn(function()
	for _ = 1, 20 do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
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


local topPanel = Instance.new("Frame")
topPanel.Name = "TopPanel"
topPanel.Size = UDim2.fromOffset(216, 128)
topPanel.Position = UDim2.fromOffset(12, 12)
topPanel.BackgroundColor3 = AUBERGINE
topPanel.BackgroundTransparency = 0.25
topPanel.BorderSizePixel = 0
topPanel.Parent = gui

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 10)
topCorner.Parent = topPanel
addStroke(topPanel, SILVER, 1, 0.55)

local dayLabel = makeLabel(topPanel, "DAY 1", UDim2.new(1, -16, 0, 26), UDim2.fromOffset(8, 6), SILVER, 22)
local phaseLabel = makeLabel(topPanel, "Day", UDim2.new(0.5, -8, 0, 20), UDim2.fromOffset(8, 36), SILVER, 15)
local tempLabel = makeLabel(topPanel, "-12C", UDim2.new(0.5, -8, 0, 20), UDim2.new(0.5, 0, 0, 36), MARIGOLD, 15)
local multLabel = makeLabel(topPanel, "x1", UDim2.new(0.5, -8, 0, 20), UDim2.fromOffset(8, 58), MARIGOLD, 15)
local lighterLabel = makeLabel(topPanel, "Lighter: 100", UDim2.new(0.5, -8, 0, 20), UDim2.new(0.5, 0, 0, 58), SILVER, 15)
local fuelLabel = makeLabel(topPanel, "Fires lit: 0", UDim2.new(1, -16, 0, 18), UDim2.fromOffset(8, 80), SILVER, 13)
local seedLabel = makeLabel(topPanel, "Seed: ------", UDim2.new(1, -16, 0, 18), UDim2.fromOffset(8, 100), SILVER, 13)
local sickLabel = makeLabel(topPanel, "SICK", UDim2.new(0, 60, 0, 20), UDim2.new(1, -66, 0, 6), MARIGOLD, 16)
sickLabel.TextXAlignment = Enum.TextXAlignment.Right
sickLabel.Visible = false

-- Day 1 objective banner (top center).
local objectivePanel = Instance.new("Frame")
objectivePanel.Name = "ObjectivePanel"
objectivePanel.Size = UDim2.fromOffset(330, 30)
objectivePanel.Position = UDim2.new(0.5, -165, 0, 10)
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
	"Base ready - keep the fire fed",
}

local barPanel = Instance.new("Frame")
barPanel.Name = "BarPanel"
barPanel.Size = UDim2.fromOffset(216, 104)
barPanel.Position = UDim2.new(0, 12, 1, -116)
barPanel.BackgroundColor3 = AUBERGINE
barPanel.BackgroundTransparency = 0.25
barPanel.BorderSizePixel = 0
barPanel.Parent = gui

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 10)
barCorner.Parent = barPanel

local function makeBar(rowY, name)
	makeLabel(barPanel, name, UDim2.fromOffset(58, 16), UDim2.fromOffset(8, rowY), SILVER, 12)
	local track = Instance.new("Frame")
	track.Size = UDim2.fromOffset(140, 12)
	track.Position = UDim2.fromOffset(66, rowY + 2)
	track.BackgroundColor3 = SILVER
	track.BackgroundTransparency = 0.6
	track.BorderSizePixel = 0
	track.Parent = barPanel
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

local healthFill = makeBar(10, "Health")
local warmthFill = makeBar(40, "Warmth")
local hungerFill = makeBar(70, "Hunger")

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
buildMenu.Size = UDim2.fromOffset(250, 148)
buildMenu.Position = UDim2.new(0.5, -125, 0.5, -74)
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
campfireBuildButton.Size = UDim2.new(1, -24, 0, 46)
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

local buildCloseButton = Instance.new("TextButton")
buildCloseButton.Size = UDim2.new(1, -24, 0, 34)
buildCloseButton.Position = UDim2.fromOffset(12, 98)
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

local slotFrames = {}
local slotLabels = {}
local slotHints = {}
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

local function makeSlot(index, name, isTool)
	local slot
	if isTool then
		slot = Instance.new("TextButton")
		slot.Text = ""
		slot.AutoButtonColor = false
	else
		slot = Instance.new("Frame")
	end
	slot.Size = UDim2.fromOffset(68, 44)
	slot.Position = UDim2.fromOffset(6 + (index - 1) * 74, 6)
	slot.BackgroundColor3 = SILVER
	slot.BackgroundTransparency = 0.75
	slot.BorderSizePixel = 0
	slot.Parent = hotbar
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = slot
	addStroke(slot, AUBERGINE, 1, 0.6)
	local label = makeLabel(slot, name, UDim2.new(1, -8, 0, 18), UDim2.fromOffset(4, 4), SILVER, 12)
	label.TextXAlignment = Enum.TextXAlignment.Center
	local value = makeLabel(slot, "", UDim2.new(1, -8, 0, 18), UDim2.fromOffset(4, 24), MARIGOLD, 13)
	value.TextXAlignment = Enum.TextXAlignment.Center
	local hint = makeLabel(slot, "", UDim2.fromOffset(24, 14), UDim2.fromOffset(3, 2), AUBERGINE, 11)
	slotFrames[name] = slot
	slotLabels[name] = value
	slotHints[name] = hint
	if isTool then
		slot.Activated:Connect(function()
			toggleTool(name)
		end)
	end
end
makeSlot(1, "Axe", true)
makeSlot(2, "Shovel", true)
makeSlot(3, "Blueprint", true)
makeSlot(4, "Lighter", true)

local function refreshHotbar()
	local character = player.Character
	for _, toolName in ipairs({ "Axe", "Shovel", "Blueprint", "Lighter" }) do
		local equipped = character and character:FindFirstChild(toolName) ~= nil
		local slot = slotFrames[toolName]
		if slot then
			slot.BackgroundColor3 = equipped and MARIGOLD or SILVER
			slot.BackgroundTransparency = equipped and 0 or 0.75
		end
		slotLabels[toolName].Text = equipped and "in hand" or ""
	end
end

local function hookCharacter(character)
	character.ChildAdded:Connect(refreshHotbar)
	character.ChildRemoved:Connect(refreshHotbar)
	refreshHotbar()
end
if player.Character then
	hookCharacter(player.Character)
end
player.CharacterAdded:Connect(hookCharacter)

-- Platform control modes: the HUD and bindings follow the input the
-- player is actually using and switch live when it changes (touch
-- buttons on mobile, keys on PC, gamepad buttons on console).
local inputMode = "Keyboard"
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
	if slotHints["Axe"] then
		slotHints["Axe"].Text = inputMode == "Keyboard" and "1" or inputMode == "Gamepad" and "◀" or ""
	end
	if slotHints["Shovel"] then
		slotHints["Shovel"].Text = inputMode == "Keyboard" and "2" or inputMode == "Gamepad" and "▶" or ""
	end
	if slotHints["Blueprint"] then
		slotHints["Blueprint"].Text = inputMode == "Keyboard" and "3" or inputMode == "Gamepad" and "▲" or ""
	end
	if slotHints["Lighter"] then
		slotHints["Lighter"].Text = inputMode == "Keyboard" and "4" or inputMode == "Gamepad" and "▼" or ""
	end
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
		elseif input.KeyCode == Enum.KeyCode.One then
			toggleTool("Axe")
		elseif input.KeyCode == Enum.KeyCode.Two then
			toggleTool("Shovel")
		elseif input.KeyCode == Enum.KeyCode.Three then
			toggleTool("Blueprint")
		elseif input.KeyCode == Enum.KeyCode.Four then
			toggleTool("Lighter")
		elseif input.KeyCode == Enum.KeyCode.E then
			tryStore()
		elseif input.KeyCode == Enum.KeyCode.F then
			tryEat()
		end
	elseif inputMode == "Gamepad" then
		if input.KeyCode == Enum.KeyCode.ButtonL3 then
			setSprint(true)
		elseif input.KeyCode == Enum.KeyCode.DPadLeft then
			toggleTool("Axe")
		elseif input.KeyCode == Enum.KeyCode.DPadRight then
			toggleTool("Shovel")
		elseif input.KeyCode == Enum.KeyCode.DPadUp then
			toggleTool("Blueprint")
		elseif input.KeyCode == Enum.KeyCode.DPadDown then
			toggleTool("Lighter")
		elseif input.KeyCode == Enum.KeyCode.ButtonX then
			tryStore()
		elseif input.KeyCode == Enum.KeyCode.ButtonY then
			tryEat()
		end
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3 then
		setSprint(false)
	end
end)

local function refreshWorld()
	dayLabel.Text = "DAY " .. tostring(ReplicatedStorage:GetAttribute("Day") or 1)
	phaseLabel.Text = tostring(ReplicatedStorage:GetAttribute("Phase") or "Day")
	tempLabel.Text = tostring(ReplicatedStorage:GetAttribute("AmbientTempC") or 0) .. "C"
	multLabel.Text = "x" .. tostring(ReplicatedStorage:GetAttribute("Multiplier") or 1)
	fuelLabel.Text = "Fires lit: " .. tostring(ReplicatedStorage:GetAttribute("LitFires") or 0)
	seedLabel.Text = "Seed: " .. tostring(ReplicatedStorage:GetAttribute("WorldSeed") or "------")
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
	lighterLabel.Text = "Lighter: " .. tostring(player:GetAttribute("LighterFuel") or 0)
	objectiveLabel.Text = OBJECTIVES[player:GetAttribute("TutorialStep") or 1] or OBJECTIVES[1]
	sickLabel.Visible = player:GetAttribute("IsSick") == true
	refreshHotbar()
end

ReplicatedStorage.AttributeChanged:Connect(refreshWorld)
player.AttributeChanged:Connect(refreshPlayer)
refreshWorld()
refreshPlayer()

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
	if tool.Name ~= "Shovel" and tool.Name ~= "Lighter" then
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
		and (characterNow:FindFirstChild("Shovel") or characterNow:FindFirstChild("Lighter"))
	dragDot.Visible = myPart ~= nil or aimEquipped ~= nil
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
