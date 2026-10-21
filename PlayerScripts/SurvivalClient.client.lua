local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local setSprinting = remotes:WaitForChild("SetSprinting")

local AUBERGINE = Color3.fromHex("3A0F34")
local SILVER = Color3.fromHex("DDE3E7")
local MARIGOLD = Color3.fromHex("EAA000")

local gui = Instance.new("ScreenGui")
gui.Name = "SurvivalHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

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

local dayLabel = makeLabel(topPanel, "DAY 1", UDim2.new(1, -16, 0, 26), UDim2.fromOffset(8, 6), SILVER, 22)
local phaseLabel = makeLabel(topPanel, "Day", UDim2.new(0.5, -8, 0, 20), UDim2.fromOffset(8, 36), SILVER, 15)
local tempLabel = makeLabel(topPanel, "-12C", UDim2.new(0.5, -8, 0, 20), UDim2.new(0.5, 0, 0, 36), MARIGOLD, 15)
local multLabel = makeLabel(topPanel, "x1", UDim2.new(0.5, -8, 0, 20), UDim2.fromOffset(8, 58), MARIGOLD, 15)
local woodLabel = makeLabel(topPanel, "Wood: 0", UDim2.new(0.5, -8, 0, 20), UDim2.new(0.5, 0, 0, 58), SILVER, 15)
local fuelLabel = makeLabel(topPanel, "Fire: 0s", UDim2.new(1, -16, 0, 18), UDim2.fromOffset(8, 80), SILVER, 13)
local seedLabel = makeLabel(topPanel, "Seed: ------", UDim2.new(1, -16, 0, 18), UDim2.fromOffset(8, 100), SILVER, 13)
local sickLabel = makeLabel(topPanel, "SICK", UDim2.new(0, 60, 0, 20), UDim2.new(1, -66, 0, 6), MARIGOLD, 16)
sickLabel.TextXAlignment = Enum.TextXAlignment.Right
sickLabel.Visible = false

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
	if input.KeyCode == Enum.KeyCode.LeftShift then
		setSprint(true)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		setSprint(false)
	end
end)

local function refreshWorld()
	dayLabel.Text = "DAY " .. tostring(ReplicatedStorage:GetAttribute("Day") or 1)
	phaseLabel.Text = tostring(ReplicatedStorage:GetAttribute("Phase") or "Day")
	tempLabel.Text = tostring(ReplicatedStorage:GetAttribute("AmbientTempC") or 0) .. "C"
	multLabel.Text = "x" .. tostring(ReplicatedStorage:GetAttribute("Multiplier") or 1)
	fuelLabel.Text = "Fire: " .. tostring(ReplicatedStorage:GetAttribute("CampfireFuel") or 0) .. "s"
	seedLabel.Text = "Seed: " .. tostring(ReplicatedStorage:GetAttribute("WorldSeed") or "------")
end

local function setBar(fill, value)
	local fraction = math.clamp((value or 100) / 100, 0, 1)
	fill.Size = UDim2.fromScale(fraction, 1)
end

local function refreshPlayer()
	setBar(healthFill, player:GetAttribute("Health"))
	setBar(warmthFill, player:GetAttribute("Warmth"))
	setBar(hungerFill, player:GetAttribute("Hunger"))
	woodLabel.Text = "Wood: " .. tostring(player:GetAttribute("Wood") or 0)
	sickLabel.Visible = player:GetAttribute("IsSick") == true
end

ReplicatedStorage.AttributeChanged:Connect(refreshWorld)
player.AttributeChanged:Connect(refreshPlayer)
refreshWorld()
refreshPlayer()
