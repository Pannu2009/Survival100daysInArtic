local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local DragSystem = require(Modules:WaitForChild("DragSystem"))

-- Fish items (Ajay's Assets.Fish, parts F1..F5): physical,
-- draggable, cookable, eaten piece by piece. Split out of Gameplay
-- to keep files under 1,000 lines; Gameplay owns the wiring
-- (remotes, the per-tick call) and the shared state it reads
-- (survivals, burning logs, the world).
local FishSystem = {}
FishSystem.__index = FishSystem

local function getLogPart(log)
	return log:FindFirstChild("Log", true) or log:FindFirstChildWhichIsA("BasePart", true)
end

function FishSystem.new(gameplay)
	local self = setmetatable({}, FishSystem)
	self.Gameplay = gameplay
	self.Folder = nil
	self.Template = nil
	return self
end

function FishSystem:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Fish"
	folder.Parent = workspace
	self.Folder = folder

	local assets = ReplicatedStorage:WaitForChild("Assets", 5)
	self.Template = assets and assets:FindFirstChild("Fish")

	-- Starter fish on the lake ice so the cook/eat loop is testable
	-- before ice fishing lands (Day 2).
	local world = self.Gameplay.World
	if self.Template and world and world.Layout and world.Layout.Lake then
		local lake = world.Layout.Lake
		for i = 1, 3 do
			self:Spawn(lake.X + (i - 2) * 4, lake.Z + lake.Radius * 0.3)
		end
	end
end

local function getFishPart(fish)
	return fish:FindFirstChild("F1") or fish:FindFirstChildWhichIsA("BasePart", true)
end

local function pointInPart(position, part, slack)
	local p = part.CFrame:PointToObjectSpace(position)
	local s = part.Size
	return math.abs(p.X) <= s.X / 2 + slack
		and math.abs(p.Y) <= s.Y / 2 + slack
		and math.abs(p.Z) <= s.Z / 2 + slack
end

-- Fish are physical items built from Ajay's Assets.Fish (parts
-- F1..F5, welded to F1): drag them, cook them in a fire's FireBox,
-- eat them.
function FishSystem:Spawn(x, z)
	local template = self.Template
	if not template then
		return
	end
	local fish = template:Clone()
	fish.Name = "Fish"
	fish:SetAttribute("Weight", 1.5)
	fish:SetAttribute("Cooked", false)
	fish:SetAttribute("Pieces", Config.Food.PiecesPerFish)
	fish.Parent = self.Folder

	local primary = getFishPart(fish)
	if not primary then
		fish:Destroy()
		return
	end
	local delta = Vector3.new(x, self.Gameplay.World:GroundY(x, z) + 1, z) - primary.Position
	for _, part in ipairs(fish:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CFrame = part.CFrame + delta
		end
	end
	for _, part in ipairs(fish:GetDescendants()) do
		if part:IsA("BasePart") then
			if part == primary then
				part.Anchored = true
				part.CanCollide = true
			else
				part.Anchored = false
				part.CanCollide = false
				part.Massless = true
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primary
				weld.Part1 = part
				weld.Parent = primary
			end
		elseif part:IsA("Script") or part:IsA("LocalScript") then
			part:Destroy()
		end
	end
	if fish:IsA("Model") then
		fish.PrimaryPart = primary
	end
	self:_attachDragPrompt(fish, primary)
end

function FishSystem:_attachDragPrompt(fish, part)
	fish:SetAttribute("Draggable", true)
	part:SetAttribute("Draggable", true)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Drag"
	prompt.ObjectText = "Fish"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		if part:GetAttribute("DraggedBy") == player.UserId then
			DragSystem.Stop(player, part)
		elseif part:GetAttribute("DraggedBy") == nil then
			if DragSystem.Start(player, part) then
				prompt.ActionText = "Drop"
			end
		end
	end)
end

function FishSystem:Eat(player, fish)
	if typeof(fish) ~= "Instance" or fish.Parent ~= self.Folder then
		return
	end
	local survival = self.Gameplay._survivals[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local part = getFishPart(fish)
	if not survival or not root or not part then
		return
	end
	if (part.Position - root.Position).Magnitude > 11 then
		return
	end
	-- One fish is 5 pieces; each eat takes one piece off the model.
	local cooked = fish:GetAttribute("Cooked") == true
	survival.Hunger:Eat(cooked and Config.Food.CookedPieceHunger or Config.Food.RawPieceHunger)
	-- Health goes through the survival system's own methods, never
	-- a direct assignment: Heal/Damage route through _setHealth, so
	-- OnHealthChanged fires and hitting zero sets Dead + OnDied.
	-- (Raw fish heals negative -- at low health it can kill you.)
	local heal = cooked and Config.Food.CookedPieceHeal or Config.Food.RawPieceHeal
	if heal >= 0 then
		survival:Heal(heal)
	else
		survival:Damage(-heal)
	end
	local pieces = (fish:GetAttribute("Pieces") or Config.Food.PiecesPerFish) - 1
	if pieces <= 0 then
		if part:GetAttribute("DraggedBy") then
			DragSystem.ForceStop(part)
		end
		fish:Destroy()
		return
	end
	fish:SetAttribute("Pieces", pieces)
	fish:SetAttribute("Weight", 1.5 * pieces / Config.Food.PiecesPerFish)
	for i = Config.Food.PiecesPerFish, 2, -1 do
		local piecePart = fish:FindFirstChild("F" .. i)
		if piecePart then
			piecePart:Destroy()
			break
		end
	end
end

-- A fish resting inside a burning fire's CookingPart cooks over
-- CookSeconds, then turns golden and counts as cooked food.
function FishSystem:Cook(dt)
	if not self.Folder then
		return
	end
	for _, fish in ipairs(self.Folder:GetChildren()) do
		if fish:GetAttribute("Cooked") ~= true then
			local part = getFishPart(fish)
			if part and part:GetAttribute("DraggedBy") == nil then
				local cooking = false
				for _, fire in ipairs(self.Gameplay.World.Fires) do
					if fire.Lit and fire.Fuel > 0 and fire.CookingPart
						and pointInPart(part.Position, fire.CookingPart, 0.75)
					then
						cooking = true
						break
					end
				end
				if not cooking then
					for log in pairs(self.Gameplay._burning) do
						local lp = getLogPart(log)
						if lp and (lp.Position - part.Position).Magnitude <= Config.Campfire.BurningLogCookRange then
							cooking = true
							break
						end
					end
				end
				if cooking then
					local t = (fish:GetAttribute("CookTime") or 0) + dt
					if t >= Config.Food.CookSeconds then
						fish:SetAttribute("Cooked", true)
						for _, p in ipairs(fish:GetDescendants()) do
							if p:IsA("BasePart") then
								p.Color = Color3.fromRGB(198, 124, 56)
							end
						end
					else
						fish:SetAttribute("CookTime", t)
					end
				elseif (fish:GetAttribute("CookTime") or 0) ~= 0 then
					fish:SetAttribute("CookTime", 0)
				end
			end
		end
	end
end
return FishSystem
