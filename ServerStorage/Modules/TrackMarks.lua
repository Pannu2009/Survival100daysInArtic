-- TrackMarks: pressed snow, done by dipping the terrain itself.
-- Each mark lowers the top voxel occupancy of the snow columns it
-- covers; the true original voxel is remembered the first time a
-- cell is pressed, and restored a few seconds later — but only if
-- nothing else changed that voxel meanwhile (a shovel dig wins).
-- Terrain is 4-stud voxels, so dips read as soft trenches, not
-- crisp outlines. Depth does not stack: a re-press takes the
-- deeper of the two and extends the restore timer.
local TrackMarks = {}

local RESOLUTION = 4
local MAX_CELLS = 1500

local world = nil
local cells = {}
local cellCount = 0

function TrackMarks.Init(w)
	world = w
end

local function cellKey(vx, vy, vz)
	return vx .. "," .. vy .. "," .. vz
end

local function voxelRegion(minVx, minVy, minVz, maxVx, maxVy, maxVz)
	local min = Vector3.new(minVx * RESOLUTION, minVy * RESOLUTION, minVz * RESOLUTION)
	local max = Vector3.new((maxVx + 1) * RESOLUTION, (maxVy + 1) * RESOLUTION, (maxVz + 1) * RESOLUTION)
	return Region3.new(min, max):ExpandToGrid(RESOLUTION)
end

-- Lower one snow column's surface. Returns the key of the stored
-- cell when a voxel was actually pressed.
local function pressColumn(vx, vz, surfaceY, dip, expiresAt)
	local centerVy = math.floor(surfaceY / RESOLUTION)
	local region = voxelRegion(vx, centerVy - 1, vz, vx, centerVy + 1, vz)
	local ok, materials, occupancies = pcall(function()
		return workspace.Terrain:ReadVoxels(region, RESOLUTION)
	end)

	if not ok then
		warn("[TrackMarks] ReadVoxels failed:", materials)
		return
	end

	-- Find the topmost solid voxel in this column.
	local topY = nil
	for yi = 3, 1, -1 do
		if materials[1][yi][1] ~= Enum.Material.Air and occupancies[1][yi][1] > 0 then
			topY = yi
			break
		end
	end
	if not topY then
		return
	end
	if materials[1][topY][1] ~= Enum.Material.Snow then
		return
	end

	local vy = (centerVy - 1) + (topY - 1)
	local key = cellKey(vx, vy, vz)
	local cell = cells[key]
	local baselineOcc = occupancies[1][topY][1]
	local baselineMat = materials[1][topY][1]
	if cell then
		-- Already pressed: the stored baseline is the true original.
		baselineOcc = cell.BaselineOcc
		baselineMat = cell.BaselineMat
	end

	local targetOcc = math.max(0.08, baselineOcc - dip)
	if cell and cell.WrittenOcc <= targetOcc then
		targetOcc = cell.WrittenOcc
	end

	occupancies[1][topY][1] = targetOcc
	local wrote = pcall(function()
		workspace.Terrain:WriteVoxels(region, RESOLUTION, materials, occupancies)
	end)
	if not wrote then
		warn("[TrackMarks] WriteVoxels failed for cell", key)
		return
	end

	if not cell then
		cellCount += 1
		cells[key] = {
			VX = vx,
			VY = vy,
			VZ = vz,
			BaselineOcc = baselineOcc,
			BaselineMat = baselineMat,
			WrittenOcc = targetOcc,
			ExpiresAt = expiresAt,
		}
	else
		cell.WrittenOcc = targetOcc
		cell.ExpiresAt = math.max(cell.ExpiresAt, expiresAt)
	end
end

-- position: world XZ source (Y ignored, the snow surface is found
-- by raycast). yaw: facing of the mark. depth01: 0 = light press,
-- 1 = deepest. life: seconds before the snow pops back.
function TrackMarks.Spawn(position, yaw, length, width, depth01, life)
	if not world then
		return
	end
	local hit = world:TerrainRaycastDown(position.X, position.Z)
	if not hit or hit.Material ~= Enum.Material.Snow then
		return
	end
	if cellCount > MAX_CELLS then
		return
	end

	local dip = 0.12 + 0.33 * math.clamp(depth01, 0, 1)
	local expiresAt = os.clock() + life

	-- Columns whose centers fall inside the rotated mark rectangle.
	local halfL = length / 2 + 1
	local halfW = width / 2 + 1
	local radius = math.max(halfL, halfW)
	local sinYaw = math.sin(yaw)
	local cosYaw = math.cos(yaw)
	local minVx = math.floor((position.X - radius) / RESOLUTION)
	local maxVx = math.floor((position.X + radius) / RESOLUTION)
	local minVz = math.floor((position.Z - radius) / RESOLUTION)
	local maxVz = math.floor((position.Z + radius) / RESOLUTION)
	for vx = minVx, maxVx do
		for vz = minVz, maxVz do
			local cx = (vx + 0.5) * RESOLUTION
			local cz = (vz + 0.5) * RESOLUTION
			local dx = cx - position.X
			local dz = cz - position.Z
			local localX = dx * cosYaw - dz * sinYaw
			local localZ = dx * sinYaw + dz * cosYaw
			if math.abs(localX) <= halfW and math.abs(localZ) <= halfL then
				pressColumn(vx, vz, hit.Position.Y, dip, expiresAt)
			end
		end
	end
end

local function restoreCell(cell)
	local region = voxelRegion(cell.VX, cell.VY, cell.VZ, cell.VX, cell.VY, cell.VZ)
	local ok, materials, occupancies = pcall(function()
		return workspace.Terrain:ReadVoxels(region, RESOLUTION)
	end)
	if not ok or not materials then
		return
	end
	-- Restore only if the voxel still holds exactly what we wrote;
	-- if a player dug or built there meanwhile, their edit wins.
	if materials[1][1][1] == cell.BaselineMat
		and math.abs(occupancies[1][1][1] - cell.WrittenOcc) < 0.02
	then
		materials[1][1][1] = cell.BaselineMat
		occupancies[1][1][1] = cell.BaselineOcc
		pcall(function()
			workspace.Terrain:WriteVoxels(region, RESOLUTION, materials, occupancies)
		end)
	end
end

function TrackMarks.Update(_dt)
	local now = os.clock()
	local expired = {}
	for key, cell in pairs(cells) do
		if now >= cell.ExpiresAt then
			table.insert(expired, key)
		end
	end
	for _, key in ipairs(expired) do
		local cell = cells[key]
		cells[key] = nil
		cellCount -= 1
		if cell then
			restoreCell(cell)
		end
	end
end

return TrackMarks
