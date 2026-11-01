local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local M = {}
local started = false
local function announce(gameplay, message)
	for _, player in ipairs(Players:GetPlayers()) do
		gameplay:Notify(player, message)
	end
end
function M.Start(gameplay, world, layout)
	if started then return false end
	assert(gameplay and world and layout, "Milestone6 requires gameplay, world and layout")
	started = true
	local service = require(ServerStorage:WaitForChild("Modules"):WaitForChild("LandslideService"))
	local rng = Random.new((tonumber(string.byte(tostring(layout.SeedString or "A"), 1)) or 65) * 7919)
	local eventFolder = workspace:FindFirstChild("ArcticMilestone6") or Instance.new("Folder")
	eventFolder.Name = "ArcticMilestone6"
	eventFolder.Parent = workspace
	ReplicatedStorage:SetAttribute("ArcticEvent", "None")
	task.spawn(function()
		while true do
			task.wait(rng:NextInteger(210, 330))
			local weather = gameplay.Temperature and gameplay.Temperature:GetWeather() or "Clear"
			if weather == "Blizzard" then
				ReplicatedStorage:SetAttribute("ArcticEvent", "Whiteout")
				announce(gameplay, "WHITEOUT: Visibility is poor. Take shelter or wait for conditions to ease.")
				task.wait(35)
				ReplicatedStorage:SetAttribute("ArcticEvent", "None")
			elseif weather == "Storm" then
				ReplicatedStorage:SetAttribute("ArcticEvent", "GustFront")
				announce(gameplay, "WIND GUST: A strong front is crossing the wilderness.")
				task.wait(22)
				ReplicatedStorage:SetAttribute("ArcticEvent", "None")
			else
				local sites = service.GetSites()
				if #sites > 0 and service.Trigger(rng:NextInteger(1, #sites), function(message)
					announce(gameplay, message)
				end) then
					ReplicatedStorage:SetAttribute("ArcticEvent", "Landslide")
					task.delay(95, function()
						if ReplicatedStorage:GetAttribute("ArcticEvent") == "Landslide" then
							ReplicatedStorage:SetAttribute("ArcticEvent", "None")
						end
					end)
				end
			end
		end
	end)
	print("[Arctic] Milestone 6 environmental events started")
	return true
end
return M
