local ArcticLayout = require(script.Parent:WaitForChild("ArcticLayout"))
local R = {}
function R.GetRegionAt(pos)
	local p = Vector2.new(pos.X, pos.Z)
	local best = nil
	local bd = math.huge
	for _, region in ipairs(ArcticLayout.Regions) do
		local d = (p - region.Center).Magnitude
		if d <= region.Radius and d < bd then
			best = region
			bd = d
		end
	end
	return best
end
function R.GetAll()
	return ArcticLayout.Regions
end
return R
