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

-- Aegis guards the game's remotes in AUDIT mode: it validates,
-- rate-limits and reports to the Discord webhook, but never
-- kicks -- enforcement comes after a tuning pass on real flags.
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
	seedString = randomSeed()
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
	clock:Update(dt)
	world:TickFire(dt)
	gameplay:Update(dt)
	sleds:Update(dt)
	world:UpdateState(clock, temperature)
end
