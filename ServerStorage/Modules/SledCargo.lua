local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local DragSystem = require(Modules:WaitForChild("DragSystem"))
local Cargo = {}
local function getLogPart(log)
	return log:FindFirstChild("Log", true) or log:FindFirstChildWhichIsA("BasePart", true)
endlocal function lengthAxis(size)
	if size.Y >= size.X and size.Y >= size.Z then
		return Vector3.yAxis, size.Y
	elseif size.X >= size.Z then
		return Vector3.xAxis, size.X
	else
		return Vector3.zAxis, size.Z
	end
endlocal function layoutCargo(box, dimsList)
	local placements = {}
	local layers = {}
	local order = {}
	for i in ipairs(dimsList) do
		order[i] = i
	end
	table.sort(order, function(a, b)
		return dimsList[a].thick > dimsList[b].thick
	end)
	for _, i in ipairs(order) do
		local d = dimsList[i]
		local spot = nil
		for l = 1, #layers + 1 do
			local layer = layers[l]
			if not layer then
				local y = 0
				for j = 1, l - 1 do
					y += layers[j].height + 0.04
				end
				layer = { used = 0, height = 0, y = y }
				layers[l] = layer
			end
			local gap = layer.used > 0 and 0.05 or 0
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
			elseif layer.used == 0 then
				spot = {
					across = 0,
					up = -box.height / 2 + layer.y + d.thick / 2,
				}
				layer.used = box.across
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
function Cargo:_pieceDims(logPart)
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
function Cargo:_cargoBox()
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
function Cargo:_relayout()
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
function Cargo:_recalcCargoWeight()
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
function Cargo:_placePiece(piece)
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
	local axisWorld = logPart.CFrame:VectorToWorldSpace(axisVec)
	if axisWorld:Dot(alongWorld) < 0 then
		alongWorld = -alongWorld
	end
	local cross = axisWorld:Cross(alongWorld)
	local rot = CFrame.new()
	if cross.Magnitude > 0.001 then
		rot = CFrame.fromAxisAngle(cross.Unit, math.acos(math.clamp(axisWorld:Dot(alongWorld), -1, 1)))
	end
	local partCF = logPart.CFrame
	local desired = CFrame.new(center) * rot * (partCF - partCF.Position)
	local delta = desired * partCF:Inverse()
	piece:PivotTo(delta * piece:GetPivot())
end
function Cargo:_overCargo(position)
	local cargo = self._cargoPart
	if not cargo then
		return false
	end
	local rel = cargo.CFrame:PointToObjectSpace(position)
	local half = cargo.Size / 2 + Vector3.new(1.5, 2.5, 1.5)
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end
function Cargo:StoreDragged(player)
	local sled = self.Sled
	if not sled or not self._cargoPart then
		return
	end
	local root = playerRoot(player)
	if not root then
		return
	end
	if not withinRange(root, sled:GetPivot().Position, Config.Sled.InteractRange) then
		return
	end
	local part = DragSystem.GetPlayerItem(player)
	if not part then
		return
	end
	local piece = part.Parent
	if not piece or piece.Parent ~= self.Gameplay.LogsFolder or piece:GetAttribute("OnSled") then
		return
	end
	if not self:_overCargo(part.Position) then
		return
	end
	self:_loadPiece(player, piece)
end
function Cargo:_loadPiece(player, best)
	local logPart = getLogPart(best)
	if not logPart then
		return
	end
	if #self._cargo >= Config.Sled.MaxCargoPieces then
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
	self._cargoOwners[best] = player
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
function Cargo:_unloadLast(player)
	local sled = self.Sled
	if not sled then
		return
	end
	local root = playerRoot(player)
	if not root then
		return
	end
	if not withinRange(root, sled:GetPivot().Position, Config.Sled.InteractRange) then
		print(("[Arctic] Unload blocked: player too far from the sled (range %d)"):format(Config.Sled.InteractRange))
		return
	end
	local topPiece = self._cargo[#self._cargo]
	if not topPiece then
		return
	end
	local storer = self._cargoOwners[topPiece]
	local sledUserId = sled:GetAttribute("PulledBy")
	if storer and storer ~= player and storer.Parent ~= nil
		and sledUserId ~= player.UserId
	then
		print("[Arctic] Unload blocked: not your cargo")
		return
	end
	local piece = table.remove(self._cargo)
	self._cargoOwners[piece] = nil
	self._cargoDims[piece] = nil
	self._slots[piece] = nil
	self._cargoOwners[piece] = nil
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
	local away = horizontalDir(root.Position - pivot.Position)
	local dropAt = root.Position + away * 2.2
	local logPart = getLogPart(piece)
	if logPart then
		self.World:SnapPartToGround(piece, logPart, dropAt.X, dropAt.Z)
	end
	self.Gameplay:AttachDragPrompt(piece)
	self:_relayout()
	self:_recalcCargoWeight()
end
function Cargo:_throwTopPiece(vel)
	local piece = self._cargo[#self._cargo]
	if not piece then
		return
	end
	self:RemovePiece(piece)
	local part = getLogPart(piece)
	if not part then
		return
	end
	local sled = self.Sled
	local center = sled and sled:GetPivot().Position or part.Position
	local behind = Vector3.new(math.sin(self._yaw), 0, math.cos(self._yaw))
	local dropXZ = center + behind * (self._halfLength + 2.5)
	local dropPos = Vector3.new(dropXZ.X, self.World:GroundY(dropXZ.X, dropXZ.Z) + 1.2, dropXZ.Z)
	piece:PivotTo(CFrame.new(dropPos))
	part.AssemblyLinearVelocity = (vel or Vector3.zero) * 0.4 + Vector3.new(0, 4, 0)
	part.AssemblyAngularVelocity = Vector3.new(0, 1.5, 0)
end
function Cargo:RemovePiece(piece)
	local found = false
	for i, p in ipairs(self._cargo) do
		if p == piece then
			table.remove(self._cargo, i)
			found = true
			break
		end
	end
	if not found then
		return
	end
	self._cargoDims[piece] = nil
	self._slots[piece] = nil
	piece:SetAttribute("OnSled", nil)
	local origSize = self._origSize[piece]
	local part = getLogPart(piece)
	if origSize then
		self._origSize[piece] = nil
		if part then
			part.Size = origSize
		end
	end
	if part then
		part.Anchored = false
	end
	self:_relayout()
	self:_recalcCargoWeight()
end
return Cargo
