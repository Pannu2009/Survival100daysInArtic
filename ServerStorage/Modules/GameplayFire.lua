local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local DragSystem = require(Modules:WaitForChild("DragSystem"))
local Fire = {}
local function getLogPart(log)
	return log:FindFirstChild("Log", true) or log:FindFirstChildWhichIsA("BasePart", true)
end
local function logWeight(logPart)
	local size = logPart.Size
	local weight = math.floor(size.X * size.Y * size.Z * Config.Log.WeightPerVolume + 0.5)
	return math.min(weight, Config.Log.MaxWeight)
end
local function logBurnUnits(logPart)
	return math.max(1, math.floor(logWeight(logPart) / Config.Log.KgPerBurnUnit + 0.5))
end
function Fire:_takeLogNear(player, position)
	if not self.LogsFolder then
		return nil
	end
	local chosen = nil
	local draggedPart = DragSystem.GetPlayerItem(player)
	if draggedPart then
		local model = draggedPart.Parent
		if model
			and model.Parent == self.LogsFolder
			and not model:GetAttribute("OnSled")
			and model:GetAttribute("Burning") ~= true
			and (model:GetPivot().Position - position).Magnitude <= Config.Campfire.FeedRange
		then
			chosen = model
		end
	end
	if not chosen then
		local nearestDistance = Config.Campfire.FeedRange
		for _, log in ipairs(self.LogsFolder:GetChildren()) do
			local logPart = getLogPart(log)
			if logPart
				and not log:GetAttribute("OnSled")
				and log:GetAttribute("Burning") ~= true
				and logPart:GetAttribute("DraggedBy") == nil
			then
				local distance = (log:GetPivot().Position - position).Magnitude
				if distance <= nearestDistance then
					chosen = log
					nearestDistance = distance
				end
			end
		end
	end
	if not chosen then
		return nil
	end
	local logPart = getLogPart(chosen)
	if not logPart then
		return nil
	end
	local taken = {
		Weight = chosen:GetAttribute("Weight") or 0,
		BurnUnits = logBurnUnits(logPart),
	}
	if logPart:GetAttribute("DraggedBy") then
		DragSystem.ForceStop(logPart)
	end
	chosen:Destroy()
	return taken
end
function Fire:_addLogToBlueprint(player, bp)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - bp.Position).Magnitude > 14 then
		return nil
	end
	local taken = self:_takeLogNear(player, bp.Position)
	if not taken then
		return nil
	end
	bp.Contributors[player] = true
	return taken.Weight
end
function Fire:_lightFire(player, fire)
	if fire.Lit or fire.Fuel <= 0 then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - fire.Core.Position).Magnitude > 14 then
		return false
	end
	if not self.Weapons:SpendFuel(player) then
		return false
	end
	fire.Lit = true
	if self.Net then
		self.Net:SendToClient(player, "PlaySound", { Sound = "FireIgnite" })
	end
	for _, key in ipairs(TUTORIAL_ORDER) do
		self:_markTutorial(player, key)
	end
	return true
end
function Fire:_igniteLog(player, log)
	local logPart = getLogPart(log)
	if not logPart or log:GetAttribute("Burning") == true then
		return false
	end
	if not self.Weapons:SpendFuel(player) then
		return false
	end
	self:_setBurning(log)
	if self.Net then
		self.Net:SendToClient(player, "PlaySound", { Sound = "FireIgnite" })
	end
	self:Notify(player, "Log is burning -- stay within 16 studs to feel its warmth.")
	return true
end
function Fire:_setBurning(log)
	local logPart = getLogPart(log)
	if not logPart or log:GetAttribute("Burning") == true then
		return
	end
	log:SetAttribute("Burning", true)
	DragSystem.ForceStop(logPart)
	if log:GetAttribute("OnSled") and self.Sleds then
		self.Sleds:RemovePiece(log)
	end
	self:_refreshLog(log)
	local burnEmitters = FireEffect.AttachFire(logPart)
	for _, emitter in ipairs(burnEmitters) do
		emitter.Enabled = true
	end
	if #burnEmitters == 0 then
		local flame = Instance.new("Fire")
		flame.Name = "BurnFlame"
		flame.Size = 5
		flame.Heat = 10
		flame.Parent = logPart
	end
	local light = Instance.new("PointLight")
	light.Name = "BurnLight"
	light.Color = Color3.fromRGB(255, 176, 66)
	light.Range = 16
	light.Brightness = 1.5
	light.Parent = logPart
	self._burning[log] = logBurnUnits(logPart) * Config.Campfire.OpenBurnSecondsPerUnit
end
function Fire:_tickBurning(dt)
	for log, timeLeft in pairs(self._burning) do
		if not log.Parent then
			self._burning[log] = nil
		else
			timeLeft -= dt
			if timeLeft <= 0 then
				self._burning[log] = nil
				local logPart = getLogPart(log)
				if logPart and logPart:GetAttribute("DraggedBy") then
					DragSystem.ForceStop(logPart)
				end
				log:Destroy()
			else
				self._burning[log] = timeLeft
			end
		end
	end
end
function Fire:_spreadFire(dt)
	if not next(self._burning) then
		if next(self._spread) then
			table.clear(self._spread)
		end
		return
	end
	local burningParts = {}
	for log in pairs(self._burning) do
		local part = getLogPart(log)
		if part then
			table.insert(burningParts, part)
		end
	end
	for _, log in ipairs(self.LogsFolder:GetChildren()) do
		if log:GetAttribute("Burnable") and log:GetAttribute("Burning") ~= true then
			local part = getLogPart(log)
			if part and part:GetAttribute("DraggedBy") == nil then
				local touching = false
				for _, other in ipairs(burningParts) do
					if other ~= part then
						local gap = (other.Position - part.Position).Magnitude
							- (other.Size.Magnitude + part.Size.Magnitude) / 2
						if gap <= Config.Campfire.SpreadGap then
							touching = true
							break
						end
					end
				end
				if touching then
					local exposure = (self._spread[log] or 0) + dt
					if exposure >= Config.Campfire.SpreadSeconds then
						self._spread[log] = nil
						self:_setBurning(log)
					else
						self._spread[log] = exposure
					end
				elseif self._spread[log] then
					self._spread[log] = nil
				end
			end
		end
	end
end
function Fire:_feedFires()
	for _, fire in ipairs(self.World.Fires) do
		if fire.AddBox and self.Coal and self.Coal.Folder then
			for _, piece in ipairs(self.Coal.Folder:GetChildren()) do
				if piece:GetAttribute("Coal") == true then
					local inBox = false
					if piece:IsA("BasePart") then
						local rel = fire.AddBox.CFrame:PointToObjectSpace(piece.Position)
						local half = fire.AddBox.Size / 2 + Vector3.new(0.3, 0.3, 0.3)
						inBox = math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
					end
					if inBox and piece:GetAttribute("DraggedBy") == nil then
						piece:Destroy()
						self.World:AddCoal(fire, 1)
					end
				end
			end
		end
		if fire.AddBox then
			for _, log in ipairs(self.LogsFolder:GetChildren()) do
				if not log:GetAttribute("OnSled") then
					local logPart = getLogPart(log)
					local inBox = false
					if logPart then
						local rel = fire.AddBox.CFrame:PointToObjectSpace(logPart.Position)
						local half = fire.AddBox.Size / 2 + Vector3.new(0.3, 0.3, 0.3)
						inBox = math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
					end
					if logPart and inBox and logPart:GetAttribute("DraggedBy") == nil then
						local units = logBurnUnits(logPart)
						self._burning[log] = nil
						log:Destroy()
						if units > 0 then
							self.World:AddFuel(fire, units)
						end
					end
				end
			end
		end
	end
end
return Fire
