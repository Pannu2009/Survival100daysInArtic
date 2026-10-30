-- Spatial: engine spatial queries instead of looping
-- every object in the world to check a distance.
--
-- Old way (slow, grows with the world):
--   for _, wolf in ipairs(allWolves) do
--     if (wolf.Position - pos).Magnitude < 25 then ...
--
-- New way (the engine does it in native code):
--   Spatial.PartsInRadius(pos, 25, { wolfRootPart })
--
-- Use it for: fire warmth, wolf detection, cooking
-- range, loot pickup, campfire radius. Never for
-- coins, items, or kills -- those are still decided
-- on the server from server state, not from a query.
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Spatial = {}

-- All BaseParts inside a sphere. OverlapParams let
-- callers filter to a folder (e.g. only wolf roots).
function Spatial.PartsInRadius(position, radius, filterDescendants)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = filterDescendants or {}
	return Workspace:GetPartBoundsInRadius(position, radius, params)
end

-- All BaseParts inside a box (useful for shelters,
-- sheds, and the queue box, where a sphere is wrong).
function Spatial.PartsInBox(cframe, size, filterDescendants)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = filterDescendants or {}
	return Workspace:GetPartBoundsInBox(cframe, size, params)
end

-- Tagged instances near a point, by CollectionService
-- tag. Tags are set at creation (WorldBuilder fires
-- and trees, Animals wolves). This is the cheap
-- "what fires/wolves are near me?" lookup.
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

-- Nearest tagged instance to a point, or nil.
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
