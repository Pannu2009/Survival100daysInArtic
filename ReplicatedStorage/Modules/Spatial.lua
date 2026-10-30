local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local Spatial = {}
function Spatial.PartsInRadius(position, radius, filterDescendants)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = filterDescendants or {}
	return Workspace:GetPartBoundsInRadius(position, radius, params)
end
function Spatial.PartsInBox(cframe, size, filterDescendants)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = filterDescendants or {}
	return Workspace:GetPartBoundsInBox(cframe, size, params)
end
function Spatial.TaggedNear(tag, position, radius)
	local out = {}
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		local part = nil
		if instance:IsA("BasePart") then
			part = instance
		elseif instance:IsA("Model") then
			part = instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
		end
		if part and (part.Position - position).Magnitude <= radius then
			table.insert(out, instance)
		end
	end
	return out
end
function Spatial.NearestTagged(tag, position, maxDistance)
	local best, bestDist = nil, maxDistance or math.huge
	for _, instance in ipairs(Spatial.TaggedNear(tag, position, maxDistance or math.huge)) do
		local part = instance:IsA("BasePart") and instance or instance:FindFirstChildWhichIsA("BasePart", true)
		if part then
			local dist = (part.Position - position).Magnitude
			if dist < bestDist then
				best, bestDist = instance, dist
			end
		end
	end
	return best, bestDist
end
return Spatial
