local M = {}
local function part(parent, name, size, cf, color, material, transparency)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	p.Color, p.Material = color, material
	p.Transparency = transparency or 0
	p.Anchored = true
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.CastShadow = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function crystalCluster(parent, rng, x, y, z, scale)
	for i = 1, 4 do
		local h = rng:NextNumber(3.5, 8) * scale
		local a = (i - 1) * math.pi / 2 + rng:NextNumber(-0.25, 0.25)
		local offset = Vector3.new(math.cos(a) * rng:NextNumber(1, 2.5), 0, math.sin(a) * rng:NextNumber(1, 2.5))
		local shard = part(parent, "TranslucentBlueIceShard", Vector3.new(0.8 * scale, h, 0.9 * scale),
			CFrame.new(x + offset.X, y + h / 2, z + offset.Z) * CFrame.Angles(0, a, rng:NextNumber(-0.12, 0.12)),
			Color3.fromRGB(115, 190, 220), Enum.Material.Glass, 0.28)
		shard.Reflectance = 0.08
	end
end
function M.Build(layout, groundY)
	assert(type(layout) == "table" and type(groundY) == "function", "layout and groundY callback required")
	local old = workspace:FindFirstChild("VisualAccents")
	if old then old:Destroy() end
	local root = Instance.new("Folder")
	root.Name = "VisualAccents"
	root.Parent = workspace
	local rng = Random.new(81821 + (#tostring(layout.SeedString or "arctic") * 113))
	local accents = Instance.new("Folder")
	accents.Name = "LandmarkAccents"
	accents.Parent = root
	local ice = Instance.new("Folder")
	ice.Name = "GlacierCrystalFields"
	ice.Parent = root
	for _, lm in ipairs(layout.Landmarks or {}) do
		local x, z = lm.Position.X, lm.Position.Z
		local ok, y = pcall(groundY, x, z)
		if not ok or type(y) ~= "number" then y = 0 end
		if lm.Id == "ResearchOutpost" then
			for side = -1, 1, 2 do
				part(accents, "OutpostCornerReinforcement", Vector3.new(0.45, 9, 0.45), CFrame.new(x + side * 17.1, y + 4.5, z - 12.6), Color3.fromRGB(113, 128, 141), Enum.Material.DiamondPlate)
			end
			part(accents, "OutpostRoofVent", Vector3.new(2.2, 1.8, 2.2), CFrame.new(x - 10, y + 16, z - 7), Color3.fromRGB(105, 119, 130), Enum.Material.Metal)
		elseif lm.Id == "RadioTower" then
			for i = 1, 3 do
				local a = i * math.pi * 2 / 3
				part(accents, "TowerGuyWireAnchor", Vector3.new(0.35, 0.35, 0.35), CFrame.new(x + math.cos(a) * 13, y + 1, z + math.sin(a) * 13), Color3.fromRGB(169, 184, 194), Enum.Material.Metal)
			end
		elseif lm.Id == "Shipwreck" then
			for i = 1, 5 do
				local dx = -15 + i * 6
				part(accents, "HullIceRidge", Vector3.new(3.5, 0.7, 2.2), CFrame.new(x + dx, y + 5.2, z + (i % 2 == 0 and 5 or -5)) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), Color3.fromRGB(163, 207, 225), Enum.Material.Ice, 0.12)
			end
		end
	end
	local glacier = nil
	for _, lm in ipairs(layout.Landmarks or {}) do if lm.Id == "IceCave" then glacier = lm.Position break end end
	if glacier then
		for i = 1, 18 do
			local a = rng:NextNumber(0, math.pi * 2)
			local d = rng:NextNumber(24, 115)
			local x, z = glacier.X + math.cos(a) * d, glacier.Z + math.sin(a) * d
			local ok, y = pcall(groundY, x, z)
			if ok and type(y) == "number" then crystalCluster(ice, rng, x, y, z, rng:NextNumber(0.65, 1.25)) end
		end
	end
	root:SetAttribute("Milestone", 8)
	root:SetAttribute("LightingModified", false)
	print("[Arctic] Milestone 8 visual accents built")
	return root
end
return M
