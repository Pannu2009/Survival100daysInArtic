-- TrackMarks: pressed-snow visuals. Terrain dips turned out to be
-- whole 4-stud cells sinking (the voxel grid limit), so marks are
-- thin visual pieces hugging the snow instead: two-lobe boot prints
-- for feet, narrow pitched segments for sled runners. Everything
-- fades out over its life and destroys itself; the terrain itself
-- is never touched.
local TrackMarks = {}

local MAX_MARKS = 320
local PRESSED_COLOR = Color3.fromRGB(169, 184, 201)

local world = nil
local folder = nil
local marks = {}

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

-- Boot print at a foot position, rotated to the movement yaw.
-- Two lobes (toe + heel) fake the boot shape on the snow surface.
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
end

-- One runner trail segment from `from` to `to`, pitched so it hugs
-- the terrain slope. Heavier cargo (depth01) presses a darker mark.
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
end

return TrackMarks
