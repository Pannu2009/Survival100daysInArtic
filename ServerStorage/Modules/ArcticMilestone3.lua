
local Milestone3 = {}

local function hashSeed(text)
	local n = 23
	for i = 1, #text do
		n = (n * 37 + string.byte(text, i)) % 2147483647
	end
	return n
end

local function distance2(x1, z1, x2, z2)
	local dx, dz = x1 - x2, z1 - z2
	return dx * dx + dz * dz
end

local function pointSegmentDistance2(px, pz, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local len2 = dx * dx + dz * dz
	if len2 < 0.001 then
		return distance2(px, pz, ax, az)
	end
	local t = math.clamp(((px - ax) * dx + (pz - az) * dz) / len2, 0, 1)
	local qx, qz = ax + t * dx, az + t * dz
	return distance2(px, pz, qx, qz)
end

local function part(parent, name, size, cf, color, material, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Transparency = transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function excluded(layout, x, z)
	if x * x + z * z < 85 * 85 then return true end

	local lake = layout.Lake
	if lake and distance2(x, z, lake.X, lake.Z) < (lake.Radius + 28)^2 then
		return true
	end

	local mountain = layout.Mountain
	if mountain and distance2(x, z, mountain.X, mountain.Z) < (mountain.Radius * 0.76)^2 then
		return true
	end

	for _, landmark in ipairs(layout.Landmarks or {}) do
		local pos = landmark.Position
		if pos and distance2(x, z, pos.X, pos.Z) < 82^2 then
			return true
		end
	end

	for i = 1, #(layout.River or {}) - 1 do
		local a, b = layout.River[i], layout.River[i + 1]
		if pointSegmentDistance2(x, z, a.X, a.Y, b.X, b.Y) < 34^2 then
			return true
		end
	end
	return false
end

local function makeRock(parent, rng, x, y, z, scale)
	local sx = rng:NextNumber(2.2, 6.8) * scale
	local sy = rng:NextNumber(1.2, 3.8) * scale
	local sz = rng:NextNumber(2.0, 6.0) * scale
	local color = Color3.fromRGB(
		rng:NextInteger(91, 119),
		rng:NextInteger(104, 132),
		rng:NextInteger(119, 148)
	)
	local rock = part(
		parent, "SnowboundBoulder", Vector3.new(sx, sy, sz),
		CFrame.new(x, y + sy * 0.38, z)
			* CFrame.Angles(rng:NextNumber(-0.22, 0.22), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.18, 0.18)),
		color, Enum.Material.Slate
	)
	rock.Shape = Enum.PartType.Block
	rock.Reflectance = 0.025

	if rng:NextNumber() < 0.72 then
		local capSize = Vector3.new(sx * rng:NextNumber(0.48, 0.78), math.max(0.25, sy * 0.18), sz * rng:NextNumber(0.45, 0.76))
		part(parent, "BoulderSnowCap", capSize,
			rock.CFrame * CFrame.new(0, sy * 0.47, 0),
			Color3.fromRGB(224, 235, 244), Enum.Material.Snow)
	end
end

local function makeShrub(parent, rng, x, y, z)
	local model = Instance.new("Model")
	model.Name = "ArcticLowShrub"
	model.Parent = parent
	local count = rng:NextInteger(3, 5)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + rng:NextNumber(-0.5, 0.5)
		local length = rng:NextNumber(1.4, 2.8)
		local height = rng:NextNumber(0.65, 1.35)
		local dx, dz = math.cos(angle) * length * 0.35, math.sin(angle) * length * 0.35
		local branch = part(model, "FrostedTwig", Vector3.new(0.16, height, length),
			CFrame.new(x + dx, y + height * 0.42, z + dz)
				* CFrame.Angles(rng:NextNumber(-0.18, 0.18), angle, rng:NextNumber(-0.28, 0.28)),
			Color3.fromRGB(86, 99, 91), Enum.Material.Wood)
		branch.CastShadow = false
		if i % 2 == 0 then
			part(model, "Frost", Vector3.new(0.2, 0.18, length * 0.52),
				branch.CFrame * CFrame.new(0, height * 0.35, 0),
				Color3.fromRGB(205, 222, 232), Enum.Material.Snow)
		end
	end
end

local function makeDrift(parent, rng, x, y, z)
	local sx = rng:NextNumber(5, 12)
	local sy = rng:NextNumber(0.45, 1.15)
	local sz = rng:NextNumber(3, 8)
	local drift = part(parent, "WindCarvedSnowDrift", Vector3.new(sx, sy, sz),
		CFrame.new(x, y + sy * 0.35, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.06, 0.06)),
		Color3.fromRGB(222, 233, 242), Enum.Material.Snow, 0.04)
	drift.Shape = Enum.PartType.Block
end

function Milestone3.Build(layout, groundY)
	assert(type(layout) == "table", "layout table is required")
	assert(type(groundY) == "function", "groundY callback is required")

	local old = workspace:FindFirstChild("ArcticMilestone3")
	if old then old:Destroy() end

	local root = Instance.new("Folder")
	root.Name = "ArcticMilestone3"
	root.Parent = workspace

	local rocks = Instance.new("Folder")
	rocks.Name = "Rocks"
	rocks.Parent = root
	local shrubs = Instance.new("Folder")
	shrubs.Name = "LowVegetation"
	shrubs.Parent = root
	local snow = Instance.new("Folder")
	snow.Name = "SnowDetails"
	snow.Parent = root

	local rng = Random.new(hashSeed(layout.SeedString or "arctic-wilderness") + 303)
	local radius = math.max(400, (layout.WorldRadius or 1850) - 90)
	local placedRocks, placedShrubs, placedDrifts = 0, 0, 0

	for _, tree in ipairs(layout.Trees or {}) do
		if rng:NextNumber() < 0.38 then
			local angle = rng:NextNumber(0, math.pi * 2)
			local offset = rng:NextNumber(5, 17)
			local x = tree.X + math.cos(angle) * offset
			local z = tree.Z + math.sin(angle) * offset
			if not excluded(layout, x, z) then
				makeShrub(shrubs, rng, x, groundY(x, z), z)
				placedShrubs += 1
			end
		end
	end

	for _ = 1, 185 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = math.sqrt(rng:NextNumber(0, 1)) * radius
		local x, z = math.cos(angle) * dist, math.sin(angle) * dist
		if not excluded(layout, x, z) then
			makeRock(rocks, rng, x, groundY(x, z), z, rng:NextNumber(0.7, 1.35))
			placedRocks += 1
		end
	end

	for _ = 1, 150 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = math.sqrt(rng:NextNumber(0, 1)) * radius
		local x, z = math.cos(angle) * dist, math.sin(angle) * dist
		if not excluded(layout, x, z) then
			makeDrift(snow, rng, x, groundY(x, z), z)
			placedDrifts += 1
		end
	end

	root:SetAttribute("RockGroups", placedRocks)
	root:SetAttribute("Shrubs", placedShrubs)
	root:SetAttribute("SnowDrifts", placedDrifts)
	print(("[Arctic] Milestone 3 visuals built: %d rock groups, %d shrubs, %d snow drifts")
		:format(placedRocks, placedShrubs, placedDrifts))

	return {
		Folder = root,
		Rocks = placedRocks,
		Shrubs = placedShrubs,
		SnowDrifts = placedDrifts,
	}
end

return Milestone3
