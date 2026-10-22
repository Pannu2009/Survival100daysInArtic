local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local DragSystem = require(Modules:WaitForChild("DragSystem"))

local SledService = {}
SledService.__index = SledService

local function getLogPart(log)
	return log:FindFirstChild("Log", true) or log:FindFirstChildWhichIsA("BasePart", true)
end

local function lengthAxis(size)
	if size.Y >= size.X and size.Y >= size.Z then
		return Vector3.yAxis, size.Y
	elseif size.X >= size.Z then
		return Vector3.xAxis, size.X
	else
		return Vector3.zAxis, size.Z
	end
end

local function horizontalDir(v)
	local h = Vector3.new(v.X, 0, v.Z)
	if h.Magnitude < 0.01 then
		return Vector3.xAxis
	end
	return h.Unit
end

local function yawBetween(fromDir, toDir)
	local crossY = fromDir.Z * toDir.X - fromDir.X * toDir.Z
	local dot = fromDir.X * toDir.X + fromDir.Z * toDir.Z
	return math.atan2(crossY, dot)
end

function SledService.new(world, gameplay)
	local self = setmetatable({}, SledService)
	self.World = world
	self.Gameplay = gameplay
	self.Sled = nil
	self._rootPart = nil
	self._cargoPart = nil
	self._halfLength = 4
	self._cargo = {}
	self._cargoDims = {}
	self._slots = {}
	self._origSize = {}
	self._cargoWeight = 0
	self._footprint = Vector3.new(4, 2, 7)
	self._pulling = {}
	self._ropes = {}
	self._vel = Vector3.zero
	self._yaw = 0
	self._yawVel = 0
	self._orientOffset = CFrame.identity
	self._groundOffset = 0.5
	self._loadPrompt = nil
	self._unloadPrompt = nil
	self._pullPrompt = nil
	return self
end

local function layoutCargo(box, dimsList)
	local placements = {}
	local layers = {}
	for i, d in ipairs(dimsList) do
		if d.thick > box.across + 0.01 then
			return nil
		end
		local spot = nil
		for l = 1, #layers + 1 do
			local layer = layers[l]
			if not layer then
				local y = 0
				for j = 1, l - 1 do
					y += layers[j].height + 0.1
				end
				if y + d.thick > box.height + 0.01 then
					return nil
				end
				layer = { used = 0, height = 0, y = y }
				layers[l] = layer
			end
			local gap = layer.used > 0 and 0.12 or 0
			if layer.used + gap + d.thick <= box.across + 0.01 then
				spot = {
					across = -box.across / 2 + layer.used + gap + d.thick / 2,
					up = -box.height / 2 + layer.y + d.thick / 2,
				}
				layer.used += gap + d.thick
				if d.thick > layer.height then
					layer.height = d.thick
				end
				break
			end
		end
		if not spot then
			return nil
		end
		placements[i] = spot
	end
	return placements
end

function SledService:_pieceDims(logPart)
	local size = logPart.Size
	local axisVec, len = lengthAxis(size)
	local thick = 0
	for _, d in ipairs({ size.X, size.Y, size.Z }) do
		if d ~= len and d > thick then
			thick = d
		end
	end
	if thick == 0 then
		thick = math.min(size.X, size.Y, size.Z)
	end
	return { len = len, thick = thick, axisVec = axisVec }
end

function SledService:_cargoBox()
	local cargo = self._cargoPart
	if not cargo then
		return nil
	end
	local cs = cargo.Size
	return {
		along = math.max(cs.X, cs.Z),
		across = math.min(cs.X, cs.Z),
		height = cs.Y,
	}
end

function SledService:_relayout()
	local box = self:_cargoBox()
	self._slots = {}
	if not box then
		return
	end
	local dimsList = {}
	for i, piece in ipairs(self._cargo) do
		dimsList[i] = self._cargoDims[piece] or { thick = 1, len = 1 }
	end
	local layout = layoutCargo(box, dimsList)
	if layout then
		for i, piece in ipairs(self._cargo) do
			self._slots[piece] = layout[i]
		end
	end
end

local function playerRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function withinRange(root, position, range)
	local dx = root.Position.X - position.X
	local dz = root.Position.Z - position.Z
	return (dx * dx + dz * dz) <= range * range
end

function SledService:GetPullWeight(player)
	if self._pulling[player] then
		return Config.Sled.Weight + self._cargoWeight
	end
	return nil
end

function SledService:Start()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = assets and (assets:FindFirstChild("Sled") or assets:FindFirstChild("sled"))
	if not template then
		warn("[Arctic] Assets.Sled not found - no sled will spawn")
		return
	end

	local sled = template:Clone()
	sled.Name = "Sled"

	local cargo = sled:FindFirstChild("CargoZone", true)
		or sled:FindFirstChild("RedaPart", true)
		or sled:FindFirstChild("Cargo", true)

	local rootPart = nil
	local bestVolume = -1
	for _, part in ipairs(sled:GetDescendants()) do
		if part:IsA("BasePart") and part ~= cargo then
			local volume = part.Size.X * part.Size.Y * part.Size.Z
			if volume > bestVolume then
				bestVolume = volume
				rootPart = part
			end
		end
	end
	if not rootPart then
		rootPart = cargo
	end
	if not rootPart then
		warn("[Arctic] Sled model has no parts - skipping")
		sled:Destroy()
		return
	end

	for _, part in ipairs(sled:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	if cargo then
		cargo.Transparency = 1
		cargo.CanCollide = false
		cargo.CanQuery = false
	end
	sled.PrimaryPart = rootPart
	sled.Parent = workspace
	self.World:SnapPartToGround(sled, rootPart, 11, 6)

	self.Sled = sled
	self._rootPart = rootPart
	self._cargoPart = cargo
	local extents = sled:GetExtentsSize()
	self._halfLength = math.max(extents.X, extents.Z) / 2
	self._footprint = Vector3.new(extents.X * 0.92, extents.Y, extents.Z * 0.92)
	sled:SetAttribute("CargoWeight", 0)

	self._vel = Vector3.zero
	self._yawVel = 0
	local a0 = Vector3.xAxis
	if cargo then
		local cs = cargo.Size
		local axis = cs.X >= cs.Z and Vector3.xAxis or Vector3.zAxis
		a0 = horizontalDir(cargo.CFrame:VectorToWorldSpace(axis))
	end
	self._yaw = math.atan2(-a0.X, -a0.Z)
	local z0 = -a0
	local x0 = Vector3.yAxis:Cross(z0)
	if x0.Magnitude < 0.01 then
		x0 = Vector3.xAxis
	else
		x0 = x0.Unit
	end
	local y0 = z0:Cross(x0)
	local canon0 = CFrame.fromMatrix(Vector3.zero, x0, y0, z0)
	local spawnPivot = sled:GetPivot()
	self._orientOffset = canon0:Inverse() * (spawnPivot - spawnPivot.Position)
	self._groundOffset = spawnPivot.Position.Y - self.World:GroundY(spawnPivot.Position.X, spawnPivot.Position.Z)

	self:_makePrompts()

	Players.PlayerRemoving:Connect(function(player)
		self:_releasePull(player)
	end)

	local function watchPlayer(player)
		player.CharacterRemoving:Connect(function()
			if self._pulling[player] then
				self:_releasePull(player)
			end
		end)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	RunService.Heartbeat:Connect(function(dt)
		self:_stepSled(dt)
	end)

	print("[Arctic] Sled spawned near camp")
end

function SledService:_makePrompts()
	local sled = self.Sled
	local cargo = self._cargoPart
	local rootPart = self._rootPart

	local loadPrompt = Instance.new("ProximityPrompt")
	loadPrompt.ActionText = "Load piece"
	loadPrompt.ObjectText = "Sled cargo 0/" .. Config.Sled.MaxCargoWeight .. "kg"
	loadPrompt.HoldDuration = 0.3
	loadPrompt.MaxActivationDistance = 9
	loadPrompt.RequiresLineOfSight = false
	loadPrompt.Parent = cargo or rootPart
	loadPrompt.Triggered:Connect(function(player)
		self:_loadNearest(player)
	end)
	self._loadPrompt = loadPrompt

	local function makeAnchor(name, offset)
		local anchor = Instance.new("Part")
		anchor.Name = name
		anchor.Size = Vector3.new(0.5, 0.5, 0.5)
		anchor.Transparency = 1
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.Anchored = true
		anchor.CFrame = (cargo and cargo.CFrame or rootPart.CFrame) * CFrame.new(offset)
		anchor.Parent = sled
		return anchor
	end

	local cs = cargo and cargo.Size or Vector3.new(4, 2, 7)
	local alongIsX = cs.X >= cs.Z
	local halfAlong = (alongIsX and cs.X or cs.Z) / 2 + 0.6

	local frontOffset = alongIsX and Vector3.new(halfAlong, 0.5, 0) or Vector3.new(0, 0.5, halfAlong)
	local pullAnchor = makeAnchor("PullAnchor", frontOffset)
	local pullPrompt = Instance.new("ProximityPrompt")
	pullPrompt.ActionText = "Pull sled"
	pullPrompt.ObjectText = "Sled"
	pullPrompt.HoldDuration = 0.3
	pullPrompt.MaxActivationDistance = 16
	pullPrompt.RequiresLineOfSight = false
	pullPrompt.Parent = pullAnchor
	pullPrompt.Triggered:Connect(function(player)
		self:_togglePull(player)
	end)
	self._pullPrompt = pullPrompt

	local backOffset = alongIsX and Vector3.new(-halfAlong, 0.5, 0) or Vector3.new(0, 0.5, -halfAlong)
	local unloadAnchor = makeAnchor("UnloadAnchor", backOffset)
	local unloadPrompt = Instance.new("ProximityPrompt")
	unloadPrompt.ActionText = "Unload piece"
	unloadPrompt.ObjectText = "Sled"
	unloadPrompt.HoldDuration = 0.3
	unloadPrompt.MaxActivationDistance = 9
	unloadPrompt.RequiresLineOfSight = false
	unloadPrompt.Enabled = false
	unloadPrompt.Parent = unloadAnchor
	unloadPrompt.Triggered:Connect(function(player)
		self:_unloadLast(player)
	end)
	self._unloadPrompt = unloadPrompt
end

function SledService:_refreshPrompts()
	if self._loadPrompt then
		self._loadPrompt.ObjectText = ("Sled cargo %d/%dkg"):format(self._cargoWeight, Config.Sled.MaxCargoWeight)
	end
	if self._unloadPrompt then
		self._unloadPrompt.Enabled = #self._cargo > 0
	end
	if self._pullPrompt then
		local pulled = self.Sled and self.Sled:GetAttribute("PulledBy") ~= nil
		self._pullPrompt.ActionText = pulled and "Drop sled" or "Pull sled"
		self._pullPrompt.ObjectText = "Sled " .. (Config.Sled.Weight + self._cargoWeight) .. "kg"
	end
end

function SledService:_recalcCargoWeight()
	local total = 0
	for _, piece in ipairs(self._cargo) do
		total += piece:GetAttribute("Weight") or 0
	end
	self._cargoWeight = total
	if self.Sled then
		self.Sled:SetAttribute("CargoWeight", total)
	end
	self:_refreshPrompts()
end

function SledService:_placePiece(piece)
	local cargo = self._cargoPart
	local logPart = getLogPart(piece)
	if not cargo or not logPart then
		return
	end

	local size = logPart.Size
	local axisVec, length = lengthAxis(size)
	local thick = 0
	for _, d in ipairs({ size.X, size.Y, size.Z }) do
		if d ~= length and d > thick then
			thick = d
		end
	end
	if thick == 0 then
		thick = math.min(size.X, size.Y, size.Z)
	end

	local cs = cargo.Size
	local alongIsX = cs.X >= cs.Z
	local slot = self._slots[piece]
	local across = slot and slot.across or 0
	local up = slot and slot.up or (-cs.Y / 2 + thick / 2)
	local localPos = alongIsX and Vector3.new(0, up, across) or Vector3.new(across, up, 0)
	local center = cargo.CFrame:PointToWorldSpace(localPos)

	local alongWorld = horizontalDir(cargo.CFrame:VectorToWorldSpace(alongIsX and Vector3.xAxis or Vector3.zAxis))
	local currentDir = horizontalDir(logPart.CFrame:VectorToWorldSpace(axisVec))
	if currentDir:Dot(alongWorld) < 0 then
		alongWorld = -alongWorld
	end
	local yawDelta = yawBetween(currentDir, alongWorld)

	local partCF = logPart.CFrame
	local desired = CFrame.new(center) * CFrame.Angles(0, yawDelta, 0) * (partCF - partCF.Position)
	local delta = desired * partCF:Inverse()
	piece:PivotTo(delta * piece:GetPivot())
end

function SledService:_loadNearest(player)
	local sled = self.Sled
	if not sled or not self._cargoPart then
		return
	end
	local root = playerRoot(player)
	if not root then
		return
	end
	local sledPos = sled:GetPivot().Position
	if not withinRange(root, sledPos, Config.Sled.InteractRange) then
		return
	end

	local best = nil
	local bestDistance = Config.Sled.LoadRange
	for _, log in ipairs(self.Gameplay.LogsFolder:GetChildren()) do
		local lp = getLogPart(log)
		if not log:GetAttribute("OnSled") and (not lp or lp:GetAttribute("DraggedBy") == nil) then
			local pivot = log:GetPivot().Position
			local dx = pivot.X - sledPos.X
			local dz = pivot.Z - sledPos.Z
			local distance = math.sqrt(dx * dx + dz * dz)
			if distance < bestDistance then
				best = log
				bestDistance = distance
			end
		end
	end
	if not best then
		return
	end
	local logPart = getLogPart(best)
	if not logPart then
		return
	end

	-- Validate everything before changing anything: capacity, then
	-- whether the piece (shrunk to the box length if needed) actually
	-- fits the cargo volume alongside what's already loaded.
	local weight = best:GetAttribute("Weight") or 0
	if self._cargoWeight + weight > Config.Sled.MaxCargoWeight then
		return
	end

	local box = self:_cargoBox()
	if not box then
		return
	end
	local dims = self:_pieceDims(logPart)
	local effLen = math.min(dims.len, box.along * 0.98)
	local trialDims = {}
	for i, piece in ipairs(self._cargo) do
		trialDims[i] = self._cargoDims[piece]
	end
	trialDims[#trialDims + 1] = { len = effLen, thick = dims.thick }
	if not layoutCargo(box, trialDims) then
		return
	end

	-- All checks passed: mutate.
	if logPart:GetAttribute("DraggedBy") then
		DragSystem.ForceStop(logPart)
	end
	if effLen < dims.len then
		self._origSize[best] = logPart.Size
		local sz = logPart.Size
		if dims.axisVec == Vector3.yAxis then
			logPart.Size = Vector3.new(sz.X, effLen, sz.Z)
		elseif dims.axisVec == Vector3.xAxis then
			logPart.Size = Vector3.new(effLen, sz.Y, sz.Z)
		else
			logPart.Size = Vector3.new(sz.X, sz.Y, effLen)
		end
	end

	best:SetAttribute("OnSled", true)
	table.insert(self._cargo, best)
	self._cargoDims[best] = { len = effLen, thick = dims.thick }

	local prompt = logPart:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt:Destroy()
	end
	logPart:SetAttribute("Draggable", nil)

	self:_relayout()
	for _, piece in ipairs(self._cargo) do
		self:_placePiece(piece)
	end
	self:_recalcCargoWeight()
end

function SledService:_unloadLast(player)
	local sled = self.Sled
	if not sled then
		return
	end
	local root = playerRoot(player)
	if not root then
		return
	end
	if not withinRange(root, sled:GetPivot().Position, Config.Sled.InteractRange) then
		return
	end

	local piece = table.remove(self._cargo)
	if not piece then
		return
	end
	self._cargoDims[piece] = nil
	self._slots[piece] = nil
	piece:SetAttribute("OnSled", nil)

	local origSize = self._origSize[piece]
	if origSize then
		self._origSize[piece] = nil
		local part = getLogPart(piece)
		if part then
			part.Size = origSize
		end
	end

	local pivot = sled:GetPivot()
	local forward = horizontalDir(pivot.LookVector)
	local behind = pivot.Position - forward * (self._halfLength + 2.5)
	local logPart = getLogPart(piece)
	if logPart then
		self.World:SnapPartToGround(piece, logPart, behind.X, behind.Z)
	end

	self.Gameplay:AttachDragPrompt(piece)
	self:_relayout()
	self:_recalcCargoWeight()
end

function SledService:_togglePull(player)
	local sled = self.Sled
	if not sled then
		return
	end
	if sled:GetAttribute("PulledBy") == player.UserId then
		self:_releasePull(player)
	elseif sled:GetAttribute("PulledBy") == nil then
		local rootP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not rootP then
			return
		end
		if not withinRange(rootP, sled:GetPivot().Position, Config.Sled.PullRange) then
			return
		end
		self.Gameplay:ReleaseDraggedLogs(player)
		sled:SetAttribute("PulledBy", player.UserId)
		self._pulling[player] = sled
		if rootP then
			local fwdH = Vector3.new(-math.sin(self._yaw), 0, -math.cos(self._yaw))
			local toPlayer = rootP.Position - sled:GetPivot().Position
			if fwdH.X * toPlayer.X + fwdH.Z * toPlayer.Z < 0 then
				self._yaw += math.pi
			end
		end
		self:_makeRopes(player)
	end
	self:_refreshPrompts()
end

function SledService:_makeRopes(player)
	local character = player.Character
	if not character then
		return
	end
	local rootPart = self._rootPart

	local hitch = Instance.new("Attachment")
	hitch.Name = "Hitch"
	hitch.Parent = rootPart

	local ropes = { hitch = hitch, beams = {}, atts = {} }
	local handNames = { "LeftHand", "RightHand" }
	local armNames = { "Left Arm", "Right Arm" }
	for i = 1, 2 do
		local hand = character:FindFirstChild(handNames[i]) or character:FindFirstChild(armNames[i])
		if hand then
			local att = Instance.new("Attachment")
			att.Name = "SledRopeHand"
			att.Parent = hand
			local beam = Instance.new("Beam")
			beam.Attachment0 = att
			beam.Attachment1 = hitch
			beam.Width0 = 0.09
			beam.Width1 = 0.09
			beam.Color = ColorSequence.new(Color3.fromRGB(122, 92, 58))
			beam.FaceCamera = false
			beam.Parent = rootPart
			table.insert(ropes.atts, att)
			table.insert(ropes.beams, beam)
		end
	end
	self._ropes[player] = ropes
end

function SledService:_releasePull(player)
	local sled = self.Sled
	if sled and sled:GetAttribute("PulledBy") == player.UserId then
		sled:SetAttribute("PulledBy", nil)
	end
	self._pulling[player] = nil
	local ropes = self._ropes[player]
	if ropes then
		for _, beam in ipairs(ropes.beams) do
			beam:Destroy()
		end
		for _, att in ipairs(ropes.atts) do
			if att.Parent then
				att:Destroy()
			end
		end
		if ropes.hitch and ropes.hitch.Parent then
			ropes.hitch:Destroy()
		end
		self._ropes[player] = nil
	end
	self:_refreshPrompts()
end

function SledService:Update(dt)
	local sled = self.Sled
	if not sled then
		return
	end

	for i = #self._cargo, 1, -1 do
		local piece = self._cargo[i]
		if not piece.Parent then
			table.remove(self._cargo, i)
			self._cargoDims[piece] = nil
			self._slots[piece] = nil
			self._origSize[piece] = nil
			self:_relayout()
			self:_recalcCargoWeight()
		end
	end

	local pullers = {}
	for player in pairs(self._pulling) do
		table.insert(pullers, player)
	end
	for _, player in ipairs(pullers) do
		self:_updatePull(player)
	end
end

function SledService:_updatePull(player)
	local sled = self.Sled
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local ropes = self._ropes[player]
	if not root or sled:GetAttribute("PulledBy") ~= player.UserId then
		self:_releasePull(player)
		return
	end
	if ropes then
		for _, att in ipairs(ropes.atts) do
			if not att.Parent then
				self:_releasePull(player)
				return
			end
		end
	end

end

function SledService:_stepSled(dt)
	local sled = self.Sled
	if not sled then
		return
	end
	dt = math.min(dt, 0.05)

	local world = self.World
	local pos = sled:GetPivot().Position

	local mass = Config.Sled.Weight + self._cargoWeight
	local massFactor = mass / Config.Sled.Weight

	local s = 3
	local hx1 = world:GroundY(pos.X + s, pos.Z)
	local hx0 = world:GroundY(pos.X - s, pos.Z)
	local hz1 = world:GroundY(pos.X, pos.Z + s)
	local hz0 = world:GroundY(pos.X, pos.Z - s)
	local gradX = (hx1 - hx0) / (2 * s)
	local gradZ = (hz1 - hz0) / (2 * s)

	local fwdH = Vector3.new(-math.sin(self._yaw), 0, -math.cos(self._yaw))

	local puller = nil
	for player in pairs(self._pulling) do
		puller = player
		break
	end
	local root = puller and puller.Character and puller.Character:FindFirstChild("HumanoidRootPart")

	local accel = Vector3.zero
	local tension01 = 0
	local hitchPos = pos + fwdH * (self._halfLength * 0.9) + Vector3.new(0, 0.8, 0)
	if root then
		local toPlayer = root.Position - hitchPos
		local dist = toPlayer.Magnitude
		local stretch = dist - Config.Sled.RopeLength
		if stretch > 0 and dist > 0.01 then
			local dir = toPlayer / dist
			local along = self._vel:Dot(dir)
			local force = stretch * Config.Sled.RopeSpring - along * Config.Sled.RopeDamp
			if force > 0 then
				accel += dir * (force / massFactor)
			end
			tension01 = math.clamp(stretch / 2.5, 0, 1)
		end
		local desired = horizontalDir(root.Position - pos)
		local err = yawBetween(fwdH, desired)
		self._yawVel += err * Config.Sled.YawResponse * dt
	elseif self._vel.Magnitude > 1 then
		local desired = horizontalDir(self._vel)
		if fwdH:Dot(desired) < 0 then
			desired = -desired
		end
		local err = yawBetween(fwdH, desired)
		self._yawVel += err * Config.Sled.YawResponse * 0.5 * dt
	end

	local slopeAccel = Vector3.new(-gradX, 0, -gradZ) * Config.Sled.SlopeGravity
	if root or slopeAccel.Magnitude > Config.Sled.StaticHold then
		accel += slopeAccel
	end

	self._vel += accel * dt
	local friction = Config.Sled.Friction / math.sqrt(massFactor)
	self._vel *= math.exp(-dt * friction)
	if self._vel.Magnitude > Config.Sled.MaxSpeed then
		self._vel = self._vel.Unit * Config.Sled.MaxSpeed
	end
	if self._vel.Magnitude < 0.04 and not root then
		self._vel = Vector3.zero
	end

	self._yawVel *= math.exp(-dt * Config.Sled.YawDamp / math.sqrt(massFactor))
	local maxYaw = 2.2 / math.sqrt(massFactor)
	self._yawVel = math.clamp(self._yawVel, -maxYaw, maxYaw)
	self._yaw += self._yawVel * dt

	local newPos = pos + self._vel * dt

	if root then
		local dx = newPos.X - root.Position.X
		local dz = newPos.Z - root.Position.Z
		local d = math.sqrt(dx * dx + dz * dz)
		local minD = self._halfLength + 1.2
		if d < minD and d > 0.01 then
			newPos = Vector3.new(root.Position.X + dx / d * minD, newPos.Y, root.Position.Z + dz / d * minD)
		end
	end

	fwdH = Vector3.new(-math.sin(self._yaw), 0, -math.cos(self._yaw))
	local rightH = Vector3.new(-fwdH.Z, 0, fwdH.X)
	local fwd3 = Vector3.new(fwdH.X, gradX * fwdH.X + gradZ * fwdH.Z, fwdH.Z).Unit
	local rightRaw = Vector3.new(rightH.X, gradX * rightH.X + gradZ * rightH.Z, rightH.Z).Unit
	local zAxis = -fwd3
	local yAxis = zAxis:Cross(rightRaw)
	if yAxis.Magnitude < 0.01 then
		yAxis = Vector3.yAxis
	else
		yAxis = yAxis.Unit
	end
	local xAxis = yAxis:Cross(zAxis).Unit
	local canon = CFrame.fromMatrix(Vector3.zero, xAxis, yAxis, zAxis)

	-- Collision: the sled is kinematic, so test its footprint before
	-- moving. Slide along obstacles; stop when boxed in on both axes.
	local function blockedAt(cframe)
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.RespectCanCollide = true
		local exclude = { sled, workspace.Terrain, self.Gameplay.LogsFolder }
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Character then
				table.insert(exclude, p.Character)
			end
		end
		params.FilterDescendantsInstances = exclude
		return #workspace:GetPartBoundsInBox(cframe, self._footprint, params) > 0
	end
	local currentCF = CFrame.new(pos.X, pos.Y, pos.Z) * canon * self._orientOffset
	if not blockedAt(currentCF) then
		local candidateCF = CFrame.new(newPos.X, pos.Y, newPos.Z) * canon * self._orientOffset
		if blockedAt(candidateCF) then
			local cfX = CFrame.new(newPos.X, pos.Y, pos.Z) * canon * self._orientOffset
			local cfZ = CFrame.new(pos.X, pos.Y, newPos.Z) * canon * self._orientOffset
			if not blockedAt(cfX) then
				newPos = Vector3.new(newPos.X, pos.Y, pos.Z)
				self._vel = Vector3.new(self._vel.X, 0, 0)
			elseif not blockedAt(cfZ) then
				newPos = Vector3.new(pos.X, pos.Y, newPos.Z)
				self._vel = Vector3.new(0, 0, self._vel.Z)
			else
				newPos = pos
				self._vel *= 0.2
				self._yawVel *= 0.5
			end
		end
	end

	local targetY = world:GroundY(newPos.X, newPos.Z) + self._groundOffset
	local smoothY = pos.Y + (targetY - pos.Y) * (1 - math.exp(-dt * 10))
	sled:PivotTo(CFrame.new(newPos.X, smoothY, newPos.Z) * canon * self._orientOffset)

	local ropes = puller and self._ropes[puller]
	if ropes and ropes.hitch then
		local center = sled:GetPivot().Position
		local hitchWorld = center + fwdH * (self._halfLength * 0.85) + Vector3.new(0, 1, 0)
		ropes.hitch.CFrame = self._rootPart.CFrame:ToObjectSpace(CFrame.new(hitchWorld))
		local sag = (1 - tension01) * -0.85
		for _, beam in ipairs(ropes.beams) do
			beam.CurveSize0 = sag
			beam.CurveSize1 = sag
		end
	end

	for _, piece in ipairs(self._cargo) do
		if piece.Parent then
			self:_placePiece(piece)
		end
	end
end

return SledService
