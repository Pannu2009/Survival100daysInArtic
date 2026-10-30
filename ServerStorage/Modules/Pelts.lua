local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local Pelts = {}
Pelts.__index = Pelts
function Pelts.new(gameplay)
	local self = setmetatable({}, Pelts)
	self.Gameplay = gameplay
	self.Counts = {}
	self.FurPieces = {}
	self._craftCooldowns = {}
	self._craftPrompts = {}
	return self
end
function Pelts:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Pelts"
	folder.Parent = workspace
	self.Folder = folder
end
function Pelts:GetCount(player)
	return self.Counts[player] or 0
end
function Pelts:GetFur(player)
	return self.FurPieces[player] or 0
end
function Pelts:OnWolfKilled(wolf, attacker)
	if not wolf or wolf.Owner then
		return
	end
	if not self.Folder then
		return
	end
	local count = wolf.Leader and Config.Pelts.LeaderPelts or Config.Pelts.RegularPelts
	local pos = wolf.Root and wolf.Root.Position
	if not pos then
		return
	end
	for i = 1, count do
		local pelt = Instance.new("Part")
		pelt.Name = "Pelt"
		pelt.Size = Vector3.new(1.4, 0.2, 1.8)
		pelt.CFrame = CFrame.new(pos.X + (i - 1) * 1.5, pos.Y + 0.3, pos.Z)
		pelt.Anchored = true
		pelt.Material = Enum.Material.Fabric
		pelt.Color = Color3.fromRGB(120, 120, 130)
		pelt.Parent = self.Folder
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Take pelt"
		prompt.ObjectText = "Wolf pelt"
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 10
		prompt.Parent = pelt
		prompt.Triggered:Connect(function(player)
			self:_takePelt(player, pelt)
		end)
	end
	if attacker and typeof(attacker) == "Instance" then
		self.Gameplay:Notify(attacker, ("Wolf pelt dropped (%d)."):format(count))
	end
end
function Pelts:_takePelt(player, pelt)
	if not pelt.Parent then
		return
	end
	local survival = self.Gameplay._survivals[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not survival or survival.Dead or not root then
		return
	end
	if (root.Position - pelt.Position).Magnitude > 14 then
		return
	end
	pelt:Destroy()
	self.Counts[player] = (self.Counts[player] or 0) + 1
	self.Gameplay:Notify(player, ("Pelt taken (%d held)."):format(self.Counts[player]))
end
function Pelts:CraftFur(player, fire)
	local survival = self.Gameplay._survivals[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not survival or survival.Dead or not root or not fire then
		return
	end
	if not fire.Lit or fire.Fuel <= 0 then
		self.Gameplay:Notify(player, "The fire must be lit to craft fur.")
		return
	end
	if (root.Position - fire.Core.Position).Magnitude > Config.Pelts.CraftRange then
		return
	end
	local now = os.clock()
	if now < (self._craftCooldowns[player] or 0) then
		return
	end
	self._craftCooldowns[player] = now + Config.Pelts.CraftCooldown
	if (self.Counts[player] or 0) < Config.Pelts.PeltsPerFur then
		self.Gameplay:Notify(player, ("Need %d pelts for fur (you have %d)."):format(
			Config.Pelts.PeltsPerFur, self.Counts[player] or 0))
		return
	end
	if (self.FurPieces[player] or 0) >= Config.Pelts.MaxFurPieces then
		self.Gameplay:Notify(player, "You already wear a full fur set.")
		return
	end
	self.Counts[player] -= Config.Pelts.PeltsPerFur
	self.FurPieces[player] = (self.FurPieces[player] or 0) + 1
	survival.Insulation = 1 - Config.Pelts.InsulationPerFur * self.FurPieces[player]
	self.Gameplay:Notify(player, ("Fur crafted! (%d/3) Cold bites less now."):format(self.FurPieces[player]))
	self.Gameplay:RecordAction(player, "craft_fur")
end
function Pelts:EnsureCraftPrompt(fire)
	if not fire or not fire.Core or self._craftPrompts[fire] then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Craft fur (3 pelts)"
	prompt.ObjectText = "Fur clothing"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.Parent = fire.Core
	prompt.Triggered:Connect(function(player)
		self:CraftFur(player, fire)
	end)
	self._craftPrompts[fire] = prompt
end
function Pelts:CleanupPlayer(player)
	self.Counts[player] = nil
	self.FurPieces[player] = nil
	self._craftCooldowns[player] = nil
end
return Pelts
