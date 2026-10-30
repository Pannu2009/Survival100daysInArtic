local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local Coal = {}
Coal.__index = Coal
function Coal.new(gameplay)
	local self = setmetatable({}, Coal)
	self.Gameplay = gameplay
	self.Folder = nil
	self.Lumps = {}
	self._mineCooldowns = {}
	self._respawnAt = nil
	self.DepositPosition = nil
	return self
end
function Coal:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Coal"
	folder.Parent = workspace
	self.Folder = folder
	local layout = self.Gameplay.World and self.Gameplay.World.Layout
	local spot = layout and layout.CoalSpot
	if not spot then
		warn("[Arctic] Coal: no CoalSpot in layout - no deposit placed")
		return
	end
	self.DepositPosition = Vector3.new(spot.X, 0, spot.Z)
	self:_spawnDeposit()
	print("[Arctic] Coal: deposit placed at the far coal spot")
end
function Coal:_spawnDeposit()
	if not self.DepositPosition then
		return
	end
	local world = self.Gameplay.World
	local groundY = world:GroundY(self.DepositPosition.X, self.DepositPosition.Z)
	self.Lumps = {}
	for i = 1, Config.Coal.Lumps do
		local lump = Instance.new("Part")
		lump.Name = "CoalDeposit"
		lump.Size = Vector3.new(2, 1.4, 2)
		lump.CFrame = CFrame.new(
			self.DepositPosition.X + (i - 3) * 2.5,
			groundY + 0.7,
			self.DepositPosition.Z)
		lump.Anchored = true
		lump.Material = Enum.Material.Slate
		lump.Color = Color3.fromRGB(30, 30, 35)
		lump.Parent = self.Folder
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Mine coal"
		prompt.ObjectText = "Coal deposit"
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 12
		prompt.Parent = lump
		prompt.Triggered:Connect(function(player)
			self:Mine(player, lump)
		end)
		table.insert(self.Lumps, lump)
	end
	self._respawnAt = nil
end
function Coal:_hasAxe(player)
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character
	return (backpack and backpack:FindFirstChild("Axe"))
		or (character and character:FindFirstChild("Axe"))
end
function Coal:Mine(player, lump)
	if not lump.Parent then
		return
	end
	local survival = self.Gameplay._survivals[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not survival or survival.Dead or not root then
		return
	end
	if (root.Position - lump.Position).Magnitude > Config.Coal.MineRange then
		return
	end
	if not self:_hasAxe(player) then
		self.Gameplay:Notify(player, "You need the axe to mine coal.")
		return
	end
	local now = os.clock()
	if now < (self._mineCooldowns[player] or 0) then
		return
	end
	self._mineCooldowns[player] = now + Config.Coal.MineCooldown
	lump:Destroy()
	for i, other in ipairs(self.Lumps) do
		if other == lump then
			table.remove(self.Lumps, i)
			break
		end
	end
	self:_spawnPiece(lump.Position)
	self.Gameplay:Notify(player, "Coal mined! Feed it to a fire -- it burns long and hot.")
	self.Gameplay:RecordAction(player, "mine_coal")
	if #self.Lumps == 0 then
		self._respawnAt = os.clock() + Config.Coal.RespawnSeconds
	end
end
function Coal:_spawnPiece(position)
	local piece = Instance.new("Part")
	piece.Name = "Coal"
	piece.Size = Vector3.new(1.2, 1, 1.2)
	piece.CFrame = CFrame.new(position.X, position.Y + 1, position.Z)
	piece.Anchored = false
	piece.CanCollide = true
	piece.Material = Enum.Material.Slate
	piece.Color = Color3.fromRGB(25, 25, 30)
	piece:SetAttribute("Coal", true)
	piece:SetAttribute("Burnable", true)
	piece:SetAttribute("Draggable", true)
	piece:SetAttribute("Weight", Config.Coal.Weight)
	piece.Parent = self.Folder
	local existing = piece:FindFirstChildOfClass("ProximityPrompt")
	if existing then
		existing:Destroy()
	end
end
function Coal:Update(_dt)
	if self._respawnAt and os.clock() >= self._respawnAt then
		self._respawnAt = nil
		self:_spawnDeposit()
	end
end
return Coal
