-- TrackMarks: pressed-snow marks — sled runner lines and footprints.
-- A mark is a thin flat part laid on the snow surface; deeper marks
-- (heavier sled) render darker and less transparent. Each mark
-- fades out over its life and is destroyed. Spawning is snow-only.
local TrackMarks = {}

local MAX_MARKS = 400
local LIGHT = Color3.fromRGB(208, 224, 238)
local DEEP = Color3.fromRGB(148, 172, 198)

local world = nil
local folder = nil
local marks = {}

function TrackMarks.Init(w)
	world = w
	folder = Instance.new("Folder")
	folder.Name = "TrackMarks"
	folder.Parent = workspace
end

-- position: world XZ source (Y ignored, the snow surface is found
-- by raycast). yaw: facing of the mark. depth01: 0 = light press,
-- 1 = deepest. life: seconds before the mark is fully gone.
function TrackMarks.Spawn(position, yaw, length, width, depth01, life)
	if not world or not folder then
		return
	end
	local hit = world:TerrainRaycastDown(position.X, position.Z)
	if not hit or hit.Material ~= Enum.Material.Snow then
		return
	end
	depth01 = math.clamp(depth01, 0, 1)

	local part = Instance.new("Part")
	part.Name = "Track"
	part.Size = Vector3.new(width, 0.08, length)
	part.CFrame = CFrame.new(position.X, hit.Position.Y + 0.05, position.Z)
		* CFrame.Angles(0, yaw, 0)
	part.Color = LIGHT:Lerp(DEEP, depth01)
	part.Transparency = 0.6 - 0.35 * depth01
	part.Material = Enum.Material.Snow
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = folder

	table.insert(marks, {
		Part = part,
		Age = 0,
		Life = life,
		StartTransparency = part.Transparency,
	})
	if #marks > MAX_MARKS then
		local oldest = table.remove(marks, 1)
		if oldest.Part.Parent then
			oldest.Part:Destroy()
		end
	end
end

function TrackMarks.Update(dt)
	for i = #marks, 1, -1 do
		local mark = marks[i]
		mark.Age += dt
		local t = mark.Age / mark.Life
		if t >= 1 or not mark.Part.Parent then
			if mark.Part.Parent then
				mark.Part:Destroy()
			end
			table.remove(marks, i)
		else
			mark.Part.Transparency = mark.StartTransparency + (1 - mark.StartTransparency) * t
		end
	end
end

return TrackMarks
