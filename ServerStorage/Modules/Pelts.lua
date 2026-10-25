-- Pelts (Phase 3, setup): wolf pelts into fur clothing.
--
-- Wild wolf kills drop pelts (Animals calls OnWolfKilled
-- from DamageWolf -- leader 2, regular 1). A pelt is a
-- physical part with a Take prompt: taking it adds to the
-- player's pelt count, it is not a draggable haul item yet
-- (hauling pelts on the sled is a slow-improve item).
--
-- Fur: three pelts craft one fur piece at a lit fire
-- (Gameplay hangs the Craft prompt on lit fires). Each
-- piece cuts cold exposure loss by 15% by lowering
-- SurvivalPlayer.Insulation -- the seam laid in Phase 3
-- base, default 1, minimum 0.55 at three pieces. Pelts
-- also sell to the merchant (see Merchant:SellPelt).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))

local Pelts = {}
Pelts.__index = Pelts

function Pelts.new(gameplay)
	local self = setmetatable({}, Pelts)
	self.Gameplay = gameplay
	self.Counts = {} -- player -> pelts held
	self.FurPieces = {} -- player -> fur pieces worn
	self._craftCooldowns = {}
	self._craftPrompts = {} -- fire -> prompt
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

-- Called by Animals when a wolf dies. Only wild kills drop
-- pelts: a tamed dog dying drops nothing (and tamed dogs
-- are not axe targets anyway). The pelt lands where the
-- wolf fell, so the killer has to walk over and take it.
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

-- Craft-at-fire v1 (design allows this until the grinder /
-- workbench chain lands): standing at a lit fire with 3
-- pelts turns them into one fur piece, worn immediately.
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
	-- Insulation is the seam: 1 - 0.15 per piece, floor 0.55.
	survival.Insulation = 1 - Config.Pelts.InsulationPerFur * self.FurPieces[player]
	self.Gameplay:Notify(player, ("Fur crafted! (%d/3) Cold bites less now."):format(self.FurPieces[player]))
	self.Gameplay:RecordAction(player, "craft_fur")
end

-- Gameplay calls this every tick: a lit fire gets one
-- Craft prompt (created once per fire), so crafting needs
-- no client button. The handler re-validates everything.
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
