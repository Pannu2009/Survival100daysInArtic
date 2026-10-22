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
local SledService = require(ServerModules:WaitForChild("SledService"))

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
