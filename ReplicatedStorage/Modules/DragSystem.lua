local DragSystem = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CONFIG = {
	Attribute = "Draggable",
	RemoteName = "DragRemote",
	MaxReach = 16,
	MaxTargetDistance = 12,
	MaxTargetSpeed = 45,
	DeviationTolerance = 8,
	UpdateRate = 1 / 20,
	BeamColor = Color3.fromRGB(255, 205, 125),
	HighlightColor = Color3.fromRGB(255, 190, 90),
	OutlineColor = Color3.fromRGB(255, 235, 190),
	BeamWidth0 = 0.10,
	BeamWidth1 = 0.06,
}
DragSystem.OnStopped = nil
local remote
local serverDrags = {}
local playerDrags = {}
local clientDrags = {}
local visuals = {}
local initializedServer = false
local initializedClient = false
local function getRoot(player)
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end
local function validItem(item)
	return typeof(item) == "Instance"
		and item:IsA("BasePart")
		and item:IsDescendantOf(workspace)
		and item:GetAttribute(CONFIG.Attribute) == true
end
local function isBurning(item)
	local model = item and item.Parent
	return model ~= nil and model:GetAttribute("Burning") == true
end
local function showVisual(item)
	if visuals[item] or not item:IsA("BasePart") then
		return
	end
	local startAttachment = Instance.new("Attachment")
	startAttachment.Name = "LocalDragStart"
	startAttachment.Parent = item
	local endAttachment = Instance.new("Attachment")
	endAttachment.Name = "LocalDragEnd"
	endAttachment.Parent = workspace.Terrain
	local beam = Instance.new("Beam")
	beam.Name = "LocalDragBeam"
	beam.Attachment0 = startAttachment
	beam.Attachment1 = endAttachment
	beam.Color = ColorSequence.new(CONFIG.BeamColor)
	beam.Width0 = CONFIG.BeamWidth0
	beam.Width1 = CONFIG.BeamWidth1
	beam.FaceCamera = true
	beam.LightEmission = 0.5
	beam.Parent = item
	local highlight = Instance.new("Highlight")
	highlight.Name = "LocalDragHighlight"
	highlight.Adornee = item
	highlight.FillColor = CONFIG.HighlightColor
	highlight.OutlineColor = CONFIG.OutlineColor
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = workspace
	TweenService:Create(
		highlight,
		TweenInfo.new(0.15),
		{FillTransparency = 0.75, OutlineTransparency = 0.05}
	):Play()
	visuals[item] = {
		Start = startAttachment,
		Finish = endAttachment,
		Beam = beam,
		Highlight = highlight,
	}
end
local function hideVisual(item)
	local v = visuals[item]
	if not v then return end
	visuals[item] = nil
	TweenService:Create(
		v.Highlight,
		TweenInfo.new(0.12),
		{FillTransparency = 1, OutlineTransparency = 1}
	):Play()
	task.delay(0.15, function()
		for _, object in pairs(v) do
			if object and object.Parent then
				object:Destroy()
			end
		end
	end)
end
local function refreshVisual(item)
	local draggedBy = item:GetAttribute("DraggedBy")
	if typeof(draggedBy) == "number" then
		showVisual(item)
	else
		hideVisual(item)
	end
end
function DragSystem.Start(player, item)
	assert(RunService:IsServer(), "Start is server-only")
	if not validItem(item) or isBurning(item) or serverDrags[item] or playerDrags[player] then
		return false
	end
	local root = getRoot(player)
	if not root or (item.Position - root.Position).Magnitude > CONFIG.MaxReach then
		return false
	end
	item.Anchored = false
	local canSet, reason = item:CanSetNetworkOwnership()
	if not canSet then
		warn("Cannot assign drag ownership:", reason)
		return false
	end
	local state = {
		Player = player,
		Position = item.Position,
		LastUpdate = os.clock(),
	}
	serverDrags[item] = state
	playerDrags[player] = item
	local success = pcall(function()
		item:SetNetworkOwner(player)
	end)
	if not success then
		serverDrags[item] = nil
		playerDrags[player] = nil
		return false
	end
	item:SetAttribute("DraggedBy", player.UserId)
	return true
end
function DragSystem.Update(player, item, targetPosition)
	assert(RunService:IsServer(), "Update is server-only")
	local state = serverDrags[item]
	if not state or state.Player ~= player then
		return false
	end
	if not validItem(item) or typeof(targetPosition) ~= "Vector3"
		or targetPosition.X ~= targetPosition.X
		or targetPosition.Y ~= targetPosition.Y
		or targetPosition.Z ~= targetPosition.Z
	then
		DragSystem.Stop(player, item)
		return false
	end
	local root = getRoot(player)
	if not root then
		DragSystem.Stop(player, item)
		return false
	end
	local now = os.clock()
	local elapsed = math.max(now - state.LastUpdate, 0.001)
	if (item.Position - root.Position).Magnitude > CONFIG.MaxReach + 3 then
		DragSystem.Stop(player, item)
		return false
	end
	local offset = targetPosition - root.Position
	if offset.Magnitude > CONFIG.MaxTargetDistance then
		targetPosition = root.Position
			+ offset.Unit * CONFIG.MaxTargetDistance
	end
	local delta = targetPosition - state.Position
	local maxStep = CONFIG.MaxTargetSpeed * elapsed
	if delta.Magnitude > maxStep + 1 then
		targetPosition = state.Position + delta.Unit * (maxStep + 1)
	end
	state.LastUpdate = now
	state.Position = targetPosition
	item:SetAttribute("DragTarget", targetPosition)
	return true
end
function DragSystem.Stop(player, item)
	assert(RunService:IsServer(), "Stop is server-only")
	local state = serverDrags[item]
	if not state or (player and state.Player ~= player) then
		return false
	end
	serverDrags[item] = nil
	if playerDrags[state.Player] == item then
		playerDrags[state.Player] = nil
	end
	if item and item.Parent then
		item:SetAttribute("DraggedBy", nil)
		item:SetAttribute("DragTarget", nil)
		item:SetAttribute("LastDragger", state.Player.UserId)
		local model = item.Parent
		if model and model:IsA("Model") then
			model:SetAttribute("LastDragger", state.Player.UserId)
		end
		pcall(function()
			item:SetNetworkOwnershipAuto()
		end)
		item.Anchored = false
		item.AssemblyLinearVelocity = Vector3.zero
		item.AssemblyAngularVelocity = Vector3.zero
		if DragSystem.OnStopped then
			DragSystem.OnStopped(item)
		end
	end
	return true
end
function DragSystem.ForceStop(item)
	assert(RunService:IsServer(), "ForceStop is server-only")
	local state = serverDrags[item]
	if not state then
		return false
	end
	return DragSystem.Stop(state.Player, item)
end
function DragSystem.StopPlayer(player)
	assert(RunService:IsServer(), "StopPlayer is server-only")
	local item = playerDrags[player]
	if item then
		DragSystem.Stop(player, item)
	end
end
function DragSystem.SendUpdate(item, targetPosition)
	assert(RunService:IsClient(), "SendUpdate is client-only")
	if remote then
		remote:FireServer("Update", item, targetPosition)
	end
end
function DragSystem.GetPlayerItem(player)
	if RunService:IsServer() then
		return playerDrags[player]
	end
	return clientDrags[player]
end
function DragSystem.InitServer()
	assert(RunService:IsServer(), "InitServer must run on server")
	if initializedServer then return end
	initializedServer = true
	remote = ReplicatedStorage:FindFirstChild(CONFIG.RemoteName)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = CONFIG.RemoteName
		remote.Parent = ReplicatedStorage
	end
	remote.OnServerEvent:Connect(function(player, action, item, position)
		if action == "Start" then
			DragSystem.Start(player, item)
		elseif action == "Update" then
			DragSystem.Update(player, item, position)
		elseif action == "Stop" then
			DragSystem.Stop(player, item)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		DragSystem.StopPlayer(player)
	end)
	local function watchPlayer(player)
		player.CharacterRemoving:Connect(function()
			DragSystem.StopPlayer(player)
		end)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	RunService.Heartbeat:Connect(function()
		for item, state in pairs(serverDrags) do
			local root = getRoot(state.Player)
			if not root or not item.Parent then
				DragSystem.Stop(state.Player, item)
				continue
			end
			if (item.Position - root.Position).Magnitude > CONFIG.MaxReach + 4 then
				DragSystem.Stop(state.Player, item)
				continue
			end
			if item.AssemblyLinearVelocity.Magnitude > CONFIG.MaxTargetSpeed + 15 then
				DragSystem.Stop(state.Player, item)
				continue
			end
			local now = os.clock()
			if state.LastItemPos then
				local moved = (item.Position - state.LastItemPos).Magnitude
				local rate = moved / math.max(now - (state.LastItemAt or now), 0.001)
				if rate > CONFIG.MaxTargetSpeed + 25 then
					DragSystem.Stop(state.Player, item)
					continue
				end
			end
			state.LastItemPos = item.Position
			state.LastItemAt = now
			if (item.Position - state.Position).Magnitude > CONFIG.DeviationTolerance then
				state.Position = item.Position
			end
		end
	end)
end
function DragSystem.InitClient()
	assert(RunService:IsClient(), "InitClient must run on client")
	if initializedClient then return end
	initializedClient = true
	remote = ReplicatedStorage:WaitForChild(CONFIG.RemoteName)
	RunService.RenderStepped:Connect(function()
		for item, v in pairs(visuals) do
			if not item.Parent then
				hideVisual(item)
				continue
			end
			local target = item:GetAttribute("DragTarget")
			if typeof(target) ~= "Vector3" then
				local draggedBy = item:GetAttribute("DraggedBy")
				local dragger = typeof(draggedBy) == "number"
					and Players:GetPlayerByUserId(draggedBy)
				local draggerRoot = dragger and getRoot(dragger)
				target = draggerRoot and draggerRoot.Position or item.Position
			end
			v.Finish.WorldPosition = target
			local distance = (item.Position - v.Finish.WorldPosition).Magnitude
			local growth = math.clamp(distance * 0.0015, 0, 0.12)
			v.Beam.Width0 = CONFIG.BeamWidth0 + growth
			v.Beam.Width1 = CONFIG.BeamWidth1 + growth
		end
	end)
	local function watchItem(item)
		if not item:IsA("BasePart") then return end
		item:GetAttributeChangedSignal("DraggedBy"):Connect(function()
			refreshVisual(item)
		end)
		refreshVisual(item)
	end
	for _, item in ipairs(workspace:GetDescendants()) do
		watchItem(item)
	end
	workspace.DescendantAdded:Connect(watchItem)
end
return DragSystem
