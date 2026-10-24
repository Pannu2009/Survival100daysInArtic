-- TrackMarks: pressed-snow marks, HYBRID. Two layers per mark:
-- (1) a thin visual piece hugging the snow -- two-lobe boot prints
-- for feet, narrow pitched segments for sled runners -- giving the
-- crisp shape; (2) a shallow single-column terrain dip under it
-- giving real pressed depth (never a patch: exactly one 4-stud
-- cell, whose true original voxel is restored when the mark dies,
-- unless a shovel dig changed it meanwhile -- the dig wins).
local TrackMarks = {}

local MAX_MARKS = 320
local PRESSED_COLOR = Color3.fromRGB(169, 184, 201)

local RESOLUTION = 4
local MAX_CELLS = 1500

local world = nil
local folder = nil
local marks = {}
local cells = {}
local cellCount = 0

-- Packed trails: every pressed cell stays "packed" for a while
-- after the visible mark fades. The sled reads this back -- your
-- own routes pack down and handle faster than virgin powder.
local PACKED_LIFE = 90
local MAX_PACKED = 4000
local packedCells = {}
local packedCount = 0

function TrackMarks.Init(w)
	world = w
	folder = workspace:FindFirstChild("TrackMarks")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "TrackMarks"
		folder.Parent = workspace
	end
end

local function snowHit(x, z)
	if not world then
		return nil
	end
	local hit = world:TerrainRaycastDown(x, z)
	if not hit or hit.Material ~= Enum.Material.Snow then
		return nil
	end
	return hit
end

-- Voxel press layer (single column only).

local function cellKey(vx, vy, vz)
	return vx .. "," .. vy .. "," .. vz
end

local function voxelRegion(minVx, minVy, minVz, maxVx, maxVy, maxVz)
	local min = Vector3.new(minVx * RESOLUTION, minVy * RESOLUTION, minVz * RESOLUTION)
	local max = Vector3.new((maxVx + 1) * RESOLUTION, (maxVy + 1) * RESOLUTION, (maxVz + 1) * RESOLUTION)
	return Region3.new(min, max):ExpandToGrid(RESOLUTION)
end

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

local function pressAtPoint(position, depth01, life)
	local hit = snowHit(position.X, position.Z)
	if not hit then
		return
	end
	if cellCount > MAX_CELLS then
		return
	end
	local dip = 0.12 + 0.33 * math.clamp(depth01, 0, 1)
	local vx = math.floor(position.X / RESOLUTION)
	local vz = math.floor(position.Z / RESOLUTION)
	pressColumn(vx, vz, hit.Position.Y, dip, os.clock() + life)
	local pkey = vx .. "," .. vz
	if packedCells[pkey] then
		packedCells[pkey] = os.clock() + PACKED_LIFE
	elseif packedCount < MAX_PACKED then
		-- Only stored cells may count: a cell rejected at the cap
		-- used to inflate the counter anyway, and nothing ever
		-- decremented for it -- packed trails silently died for
		-- the rest of the session.
		packedCount += 1
		packedCells[pkey] = os.clock() + PACKED_LIFE
	end
end

-- Is this point on snow that traffic has already packed down?
function TrackMarks.IsPacked(x, z)
	local vx = math.floor(x / RESOLUTION)
	local vz = math.floor(z / RESOLUTION)
	local expires = packedCells[vx .. "," .. vz]
	return expires ~= nil and expires > os.clock()
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

-- Visual layer.

local function newMarkPart(size)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Snow
	part.Color = PRESSED_COLOR
	part.Size = size
	part.Parent = folder
	return part
end

local function addMark(parts, baseTransparency, life)
	if #marks >= MAX_MARKS then
		local oldest = table.remove(marks, 1)
		for _, part in ipairs(oldest.Parts) do
			part:Destroy()
		end
	end
	for _, part in ipairs(parts) do
		part.Transparency = baseTransparency
	end
	table.insert(marks, {
		Parts = parts,
		Age = 0,
		Life = life,
		Base = baseTransparency,
	})
end

-- Boot print at a foot position, rotated to the movement yaw:
-- two lobes (toe + heel) for the shape, one pressed cell under it.
function TrackMarks.SpawnFoot(position, yaw, life)
	local hit = snowHit(position.X, position.Z)
	if not hit then
		return
	end
	local cf = CFrame.new(Vector3.new(position.X, hit.Position.Y + 0.04, position.Z))
		* CFrame.Angles(0, yaw, 0)
	local toe = newMarkPart(Vector3.new(0.8, 0.05, 0.95))
	toe.CFrame = cf * CFrame.new(0, 0, 0.3)
	local heel = newMarkPart(Vector3.new(0.68, 0.05, 0.5))
	heel.CFrame = cf * CFrame.new(0, 0, -0.5)
	addMark({ toe, heel }, 0.35, life)
	pressAtPoint(position, 0.35, life)
end

-- One runner trail segment from `from` to `to`, pitched so it hugs
-- the terrain slope, plus a pressed cell under the new end point.
-- Heavier cargo (depth01) presses a darker mark and a deeper dip.
function TrackMarks.SpawnSegment(from, to, depth01, life)
	local hitA = snowHit(from.X, from.Z)
	local hitB = snowHit(to.X, to.Z)
	if not hitA or not hitB then
		return
	end
	local a = Vector3.new(from.X, hitA.Position.Y + 0.04, from.Z)
	local b = Vector3.new(to.X, hitB.Position.Y + 0.04, to.Z)
	local length = (b - a).Magnitude
	if length < 0.1 then
		return
	end
	local part = newMarkPart(Vector3.new(0.55, 0.05, length + 0.25))
	part.CFrame = CFrame.lookAt((a + b) / 2, b)
	addMark({ part }, 0.5 - 0.3 * math.clamp(depth01, 0, 1), life)
	pressAtPoint(to, depth01, life)
end

function TrackMarks.Update(dt)
	for i = #marks, 1, -1 do
		local mark = marks[i]
		mark.Age += dt
		local t = mark.Age / mark.Life
		if t >= 1 then
			for _, part in ipairs(mark.Parts) do
				part:Destroy()
			end
			table.remove(marks, i)
		else
			local transparency = mark.Base + (1 - mark.Base) * t
			for _, part in ipairs(mark.Parts) do
				part.Transparency = transparency
			end
		end
	end

	local now = os.clock()
	for pkey, expires in pairs(packedCells) do
		if now >= expires then
			packedCells[pkey] = nil
			packedCount -= 1
		end
	end
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
