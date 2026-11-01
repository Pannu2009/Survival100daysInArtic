local ServerStorage = game:GetService("ServerStorage")
local S = {}
local busy = false
local sites = {
	{ Name = "HighlandPass", Position = Vector3.new(650, 70, -900), Radius = 90 },
	{ Name = "GlacierTrail", Position = Vector3.new(1120, 55, -1150), Radius = 75 },
}
function S.GetSites()
	return sites
end
function S.Trigger(index, notifyFn)
	if busy or not sites[index] then
		return false
	end
	busy = true
	local site = sites[index]
	if notifyFn then
		notifyFn("Mountain warning: unstable snow near " .. site.Name .. "!")
	end
	task.delay(5, function()
		local ground = 0
		local hit = workspace:Raycast(Vector3.new(site.Position.X, 500, site.Position.Z), Vector3.new(0, -1000, 0))
		if hit then
			ground = hit.Position.Y
		end
		local assets = ServerStorage:FindFirstChild("ArcticAssets")
		local debrisTemplate = assets and assets:FindFirstChild("LandslideDebris")
		if debrisTemplate then
			local debris = debrisTemplate:Clone()
			debris:PivotTo(CFrame.new(site.Position.X, ground + 2, site.Position.Z))
			debris.Parent = workspace
			task.delay(90, function()
				if debris.Parent then
					debris:Destroy()
				end
			end)
		end
		local wall = Instance.new("Part")
		wall.Name = "TemporaryLandslideBlocker"
		wall.Anchored = true
		wall.Size = Vector3.new(site.Radius * 1.5, 12, 18)
		wall.Material = Enum.Material.Snow
		wall.Color = Color3.fromRGB(205, 215, 225)
		wall.CFrame = CFrame.new(site.Position.X, ground + 6, site.Position.Z)
		wall.Parent = workspace
		task.delay(90, function()
			if wall.Parent then
				wall:Destroy()
			end
			busy = false
		end)
	end)
	return true
end
return S
