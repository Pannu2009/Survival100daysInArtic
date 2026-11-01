local Players = game:GetService("Players")
local Treasury = require(script.Parent:WaitForChild("Treasury"))
local D = {}
function D.Init(gameplay, layout)
	local landmarks = layout and layout.Landmarks or {}
	if #landmarks == 0 then
		return
	end
	task.spawn(function()
		while true do
			task.wait(3)
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root then
					local profile = Treasury.GetProfile(player)
					profile.Discoveries = profile.Discoveries or {}
					for _, landmark in ipairs(landmarks) do
						if not profile.Discoveries[landmark.Id] then
							local dx = root.Position.X - landmark.Position.X
							local dz = root.Position.Z - landmark.Position.Z
							if dx * dx + dz * dz <= 45 * 45 then
								profile.Discoveries[landmark.Id] = true
								Treasury.Save(player)
								if gameplay and gameplay.Notify then
									gameplay:Notify(player, "Discovered: " .. landmark.Name)
								end
							end
						end
					end
				end
			end
		end
	end)
end
return D
