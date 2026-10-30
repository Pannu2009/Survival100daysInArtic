local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local SharedModules = ReplicatedStorage:WaitForChild("Modules")
local ServerModules = ServerStorage:WaitForChild("Modules")
local Config = require(SharedModules:WaitForChild("Config"))
local DayNightClock = require(ServerModules:WaitForChild("DayNightClock"))
local Temperature = require(ServerModules:WaitForChild("Temperature"))
local WorldGen = require(ServerModules:WaitForChild("WorldGen"))
local WorldBuilder = require(ServerModules:WaitForChild("WorldBuilder"))
local Gameplay = require(ServerModules:WaitForChild("Gameplay"))
local Aegis = require(ServerModules:WaitForChild("Aegis"))
local ServerMode = require(ServerModules:WaitForChild("ServerMode"))
local serverMode = ServerMode.Detect()
ReplicatedStorage:SetAttribute("ServerMode", serverMode)
print("[Arctic] Server mode: " .. serverMode)
pcall(function()
	local StarterPlayer = game:GetService("StarterPlayer")
	StarterPlayer.CameraMode = serverMode == "Lobby"
		and Enum.CameraMode.Classic
		or Enum.CameraMode.LockFirstPerson
end)
local function setCameraMode(player)
	local mode = serverMode == "Lobby"
		and Enum.DevComputerCameraMode.Classic
		or Enum.DevComputerCameraMode.LockFirstPerson
	pcall(function()
		player.DevComputerCameraMode = mode
	end)
	pcall(function()
		player.DevTouchCameraMode = serverMode == "Lobby"
			and Enum.DevTouchCameraMode.Classic
			or Enum.DevTouchCameraMode.LockFirstPerson
	end)
end
game:GetService("Players").PlayerAdded:Connect(setCameraMode)
for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
	setCameraMode(player)
end
pcall(function()
	workspace.StreamingEnabled = false
end)
if serverMode == "Lobby" then
	print("[Arctic] Lobby server: world generation skipped")
	local LobbyTag = require(ServerModules:WaitForChild("LobbyTag"))
	LobbyTag.Start()
	local Queue = require(ServerModules:WaitForChild("Queue"))
	Queue.Start()
	return
end
pcall(function()
	workspace.StreamingEnabled = true
	workspace.StreamingTargetRadius = 384
	workspace.StreamingMinRadius = 64
end)
local queueFolder = workspace:FindFirstChild("QueueFolder")
if queueFolder then
	queueFolder:Destroy()
	print("[Arctic] Game server: QueueFolder removed")
end
Aegis.init({
	auditOnly = true,
	kickOnDetect = false,
	discordWebhook = "https://discord.com/api/webhooks/1465179301170122835/-yg6mbzS083VRRLvDvRWzDJZJW2aXCHH5l8fxTzU6_FYlUY4W3LDA-Rt2k_B-yWnoU0vEW",
})
local SledService = require(ServerModules:WaitForChild("SledService"))
local DragSystem = require(SharedModules:WaitForChild("DragSystem"))
local function randomSeed()
	local letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	local parts = {}
	for i = 1, 6 do
		local n = math.random(1, #letters)
		parts[i] = letters:sub(n, n)
	end
	return table.concat(parts)
end
local clock = DayNightClock.new()
local temperature = Temperature.new()
local seedString = Config.World.DevSeed
if seedString == "" then
	local PlayersService = game:GetService("Players")
	local firstPlayer = PlayersService:GetPlayers()[1]
	for _ = 1, 12 do
		if firstPlayer then break end
		task.wait(0.25)
		firstPlayer = PlayersService:GetPlayers()[1]
	end
	if firstPlayer then
		local ok, joinData = pcall(function()
			return firstPlayer:GetJoinData()
		end)
		local teleportData = ok and joinData and joinData.TeleportData or nil
		if teleportData and teleportData.seed then
			seedString = teleportData.seed
			print("[Arctic] Party seed from TeleportData: " .. seedString)
		elseif teleportData and teleportData.partyKey then
			local CrossServer = require(ServerModules:WaitForChild("CrossServer"))
			local party = CrossServer.GetParty(teleportData.partyKey)
			if party and party.Seed then
				seedString = party.Seed
				print("[Arctic] Party seed from MemoryStore: " .. seedString)
			end
		end
	end
	if seedString == "" then
		seedString = randomSeed()
	end
end
local layout = WorldGen.Generate(seedString)
local world = WorldBuilder.new(layout)
world:Build()
ReplicatedStorage:SetAttribute("WorldSeed", layout.SeedString)
print("[Arctic] World seed: " .. layout.SeedString)
local gameplay = Gameplay.new(world, clock, temperature)
gameplay:Start()
DragSystem.InitServer()
local sleds = SledService.new(world, gameplay)
sleds:Start()
gameplay.Sleds = sleds
world:UpdateState(clock, temperature)
while true do
	local dt = task.wait(0.25)
	local ok, err = pcall(function()
		clock:Update(dt)
		world:TickFire(dt)
		gameplay:Update(dt)
		sleds:Update(dt)
		world:UpdateState(clock, temperature)
	end)
	if not ok then
		warn("[Arctic] Main loop error, continuing:", err)
	end
end
