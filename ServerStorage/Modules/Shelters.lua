local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local Shelters = {}
Shelters.__index = Shelters
function Shelters.new(gameplay)
	local self = setmetatable({}, Shelters)
	self.Gameplay = gameplay
	self.Shelters = {}
	return self
end
function Shelters:Start()
	local layout = self.Gameplay.World and self.Gameplay.World.Layout
	if not layout or not layout.Cabins then
		warn("[Arctic] Shelters: no cabin spots in layout - no broken shelters placed")
		return
	end
	for _, cabin in ipairs(layout.Cabins) do
		local model, anchor = self.Gameplay.World:CreateStructure("Shed", cabin.X, cabin.Z, true)
		if model and anchor then
			table.insert(self.Shelters, {
				Position = Vector3.new(cabin.X, 0, cabin.Z),
				Radius = Config.Shelters.WarmthRadius,
			})
			self:_addLoot(model, cabin.X, cabin.Z)
		end
	end
	print(("[Arctic] Shelters: %d broken shelters placed"):format(#self.Shelters))
end
function Shelters:RegisterBuiltShed(model, x, z)
	table.insert(self.Shelters, {
		Position = Vector3.new(x, 0, z),
		Radius = Config.Shelters.WarmthRadius,
	})
end
function Shelters:WarmthBonusAt(position)
	local bonus = 0
	for _, shelter in ipairs(self.Shelters) do
		local dx = position.X - shelter.Position.X
		local dz = position.Z - shelter.Position.Z
		if dx * dx + dz * dz <= shelter.Radius * shelter.Radius then
			bonus = math.max(bonus, Config.Shelters.WarmthBonus)
		end
	end
	return bonus
end
function Shelters:_addLoot(model, x, z)
	local groundY = self.Gameplay.World:GroundY(x, z)
	for i = 1, Config.Shelters.LootCratesPerShelter do
		local crate = Instance.new("Part")
		crate.Name = "LootCrate"
		crate.Size = Vector3.new(1.6, 1.2, 1.6)
		crate.CFrame = CFrame.new(x + (i - 1.5) * 3, groundY + 0.6, z + 2)
		crate.Anchored = true
		crate.Material = Enum.Material.WoodPlanks
		crate.Color = Color3.fromRGB(140, 110, 70)
		crate.Parent = model
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Take loot"
		prompt.ObjectText = "Broken shelter loot"
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 10
		prompt.Parent = crate
		prompt.Triggered:Connect(function(player)
			self:_takeLoot(player, crate)
		end)
	end
end
function Shelters:_takeLoot(player, crate)
	if not crate.Parent then
		return
	end
	local survival = self.Gameplay._survivals[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not survival or survival.Dead or not root then
		return
	end
	if (root.Position - crate.Position).Magnitude > 14 then
		return
	end
	crate:Destroy()
	local coins = math.random(Config.Shelters.LootCoinsMin, Config.Shelters.LootCoinsMax)
	self.Gameplay.Economy.Add(player, coins)
	survival.Hunger:Eat(Config.Shelters.LootHunger)
	self.Gameplay:Notify(player, ("Loot! +%d coins, a little food."):format(coins))
	self.Gameplay:RecordAction(player, "loot")
end
return Shelters
