-- DragModulev1.2
-- Standalone drag effects module.
-- warning from dakait {{ make u
Sure draggabke utem uses a tag ir attribute}}

local DragModule = {}

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local CONFIG = {
	Attribute = "Draggable",

	HighlightFill = Color3.fromRGB(255, 190, 95),
	HighlightOutline = Color3.fromRGB(255, 229, 180),
	FillTransparency = 0.78,
	OutlineTransparency = 0.05,

	HighlightIn = 0.15,
	HighlightOut = 0.12,

	BeamColor = Color3.fromRGB(255, 210, 140),
	BeamTransparency = 0.12,
	BeamWidth0 = 0.10,
	BeamWidth1 = 0.06,
	BeamWidthGrowth = 0.0015,
	MaxWidthGrowth = 0.12,

	BeamFaceCamera = true,
}

local active = {}

local function getPart(item)
	if item:IsA("BasePart") then
		return item
	end

	if item:IsA("Model") then
		return item.PrimaryPart
			or item:FindFirstChildWhichIsA("BasePart", true)
	end

	return nil
end

function DragModule.IsDraggable(item)
	return item ~= nil
		and item:GetAttribute(CONFIG.Attribute) == true
		and getPart(item) ~= nil
end

-- Call once when a drag begins.
-- targetAttachment: optional Attachment controlled by your controller.
function DragModule.Start(item, targetAttachment)
	if not DragModule.IsDraggable(item) then
		return nil, "Item is not draggable"
	end

	if active[item] then
		DragModule.Stop(item)
	end

	local part = getPart(item)
	local beamStart = Instance.new("Attachment")
	beamStart.Name = "DragBeamStart"
	beamStart.Parent = part

	local beamEnd = Instance.new("Attachment")
	beamEnd.Name = "DragBeamEnd"
	beamEnd.Parent = workspace.Terrain

	local beam = Instance.new("Beam")
	beam.Name = "DragBeam"
	beam.Attachment0 = beamStart
	beam.Attachment1 = beamEnd
	beam.Color = ColorSequence.new(CONFIG.BeamColor)
	beam.Transparency = NumberSequence.new(CONFIG.BeamTransparency)
	beam.Width0 = CONFIG.BeamWidth0
	beam.Width1 = CONFIG.BeamWidth1
	beam.FaceCamera = CONFIG.BeamFaceCamera
	beam.LightEmission = 0.5
	beam.Enabled = false
	beam.Parent = part

	local highlight = Instance.new("Highlight")
	highlight.Name = "DragHighlight"
	highlight.Adornee = item
	highlight.FillColor = CONFIG.HighlightFill
	highlight.OutlineColor = CONFIG.HighlightOutline
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = workspace

	local state = {
		Item = item,
		Part = part,
		Beam = beam,
		StartAttachment = beamStart,
		EndAttachment = beamEnd,
		Highlight = highlight,
		TargetAttachment = targetAttachment,
		TargetPosition = part.Position,
		Connections = {},
	}

	active[item] = state

	TweenService:Create(
		highlight,
		TweenInfo.new(CONFIG.HighlightIn),
		{
			FillTransparency = CONFIG.FillTransparency,
			OutlineTransparency = CONFIG.OutlineTransparency,
		}
	):Play()

	beam.Enabled = true

	-- Track the target and smoothly scale the tether.
	state.Connections[#state.Connections + 1] =
		RunService.RenderStepped:Connect(function()
			if not active[item] or not part.Parent then
				DragModule.Stop(item)
				return
			end

			if state.TargetAttachment
				and state.TargetAttachment.Parent then
				state.TargetPosition =
					state.TargetAttachment.WorldPosition
			end

			beamEnd.WorldPosition = state.TargetPosition

			local distance =
				(part.Position - state.TargetPosition).Magnitude

			local growth = math.clamp(
				distance * CONFIG.BeamWidthGrowth,
				0,
				CONFIG.MaxWidthGrowth
			)

			beam.Width0 = CONFIG.BeamWidth0 + growth
			beam.Width1 = CONFIG.BeamWidth1 + growth
		end)

	return state
end

-- Call whenever your controller moves the drag target.
function DragModule.Update(item, worldPosition)
	local state = active[item]
	if not state then
		return false
	end

	state.TargetPosition = worldPosition
	return true
end

-- Call when the item is released.
function DragModule.Stop(item)
	local state = active[item]
	if not state then
		return
	end

	active[item] = nil

	for _, connection in ipairs(state.Connections) do
		connection:Disconnect()
	end

	if state.Beam then
		state.Beam.Enabled = false
		state.Beam:Destroy()
	end

	if state.StartAttachment then
		state.StartAttachment:Destroy()
	end

	if state.EndAttachment then
		state.EndAttachment:Destroy()
	end

	if state.Highlight then
		local highlight = state.Highlight

		TweenService:Create(
			highlight,
			TweenInfo.new(CONFIG.HighlightOut),
			{
				FillTransparency = 1,
				OutlineTransparency = 1,
			}
		):Play()

		task.delay(CONFIG.HighlightOut, function()
			if highlight.Parent then
				highlight:Destroy()
			end
		end)
	end
end

function DragModule.StopAll()
	local items = {}

	for item in pairs(active) do
		items[#items + 1] = item
	end

	for _, item in ipairs(items) do
		DragModule.Stop(item)
	end
end

function DragModule.GetActive(item)
	return active[item]
end

return DragModule
