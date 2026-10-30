local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local Merchant = {}
Merchant.__index = Merchant
function Merchant.new(gameplay)
	local self = setmetatable({}, Merchant)
	self.Gameplay = gameplay
	self.Stock = {}
	self.LastRestockDay = 1
	self.MedkitCounts = {}
	self.Stall = nil
	self.StallPosition = nil
	return self
end
function Merchant:Start()
	self:_restock()
	local world = self.Gameplay.World
	local x, z = 20, 20
	local groundY = world:GroundY(x, z)
	local stall = Instance.new("Model")
	stall.Name = "MerchantStall"
	local base = Instance.new("Part")
	base.Name = "MerchantStallBase"
	base.Size = Vector3.new(6, 0.4, 4)
	base.CFrame = CFrame.new(x, groundY + 0.2, z)
	base.Anchored = true
	base.Material = Enum.Material.WoodPlanks
	base.Color = Color3.fromRGB(140, 110, 70)
	base.Parent = stall
	local post = Instance.new("Part")
	post.Name = "MerchantStallPost"
	post.Size = Vector3.new(0.6, 4, 0.6)
	post.CFrame = CFrame.new(x, groundY + 2.2, z)
	post.Anchored = true
	post.Material = Enum.Material.Wood
	post.Color = Color3.fromRGB(100, 70, 40)
	post.Parent = stall
	stall.Parent = workspace
	self.Stall = stall
	self.StallPosition = Vector3.new(x, groundY, z)
	self:_addPrompts(post)
	if self.Gameplay.Clock and self.Gameplay.Clock.OnDayAdvanced then
		self.Gameplay.Clock.OnDayAdvanced:Connect(function(day)
			self:CheckRestock(day)
		end)
	end
	print("[Arctic] Merchant: stall placed near spawn")
end
function Merchant:_restock()
	for name, item in pairs(Config.Merchant.Items) do
		self.Stock[name] = item.Stock
	end
	print("[Arctic] Merchant: stock restocked")
end
function Merchant:CheckRestock(day)
	if day - self.LastRestockDay >= Config.Merchant.RestockDays then
		self.LastRestockDay = day
		self:_restock()
		for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
			self.Gameplay:Notify(player, "The merchant restocked!")
		end
	end
end
function Merchant:GetMedkits(player)
	return self.MedkitCounts[player] or 0
end
function Merchant:_nearStall(player, allowDead)
	local survival = self.Gameplay._survivals[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not survival or not root or not self.StallPosition then
		return nil
	end
	if not allowDead and survival.Dead then
		return nil
	end
	if (root.Position - self.StallPosition).Magnitude > Config.Merchant.TradeRange then
		return nil
	end
	return survival
end
function Merchant:Buy(player, itemName)
	local item = Config.Merchant.Items[itemName]
	if not item then
		return
	end
	local survival = self:_nearStall(player, false)
	if not survival then
		return
	end
	if (self.Stock[itemName] or 0) <= 0 then
		self.Gameplay:Notify(player, ("Out of stock: %s. Restock every %d days."):format(
			itemName, Config.Merchant.RestockDays))
		return
	end
	if not self.Gameplay.Economy.CanAfford(player, item.Price) then
		self.Gameplay:Notify(player, ("Need %d coins for %s (you have %d)."):format(
			itemName, itemName, self.Gameplay.Economy.Get(player)))
		return
	end
	if not self.Gameplay.Economy.Spend(player, item.Price) then
		return
	end
	self.Stock[itemName] -= 1
	if itemName == "Food" then
		survival.Hunger:Eat(item.Hunger)
		self.Gameplay:Notify(player, ("Bought food (+%d hunger)."):format(item.Hunger))
	elseif itemName == "Fuel" then
		self.Gameplay.Weapons:AddFuel(player, item.Fuel)
		self.Gameplay:Notify(player, ("Bought lighter fuel (+%d)."):format(item.Fuel))
	elseif itemName == "Medkit" then
		self.MedkitCounts[player] = (self.MedkitCounts[player] or 0) + 1
		self.Gameplay:Notify(player, ("Bought a medkit (%d held). It can revive you."):format(
			self.MedkitCounts[player]))
	end
	self.Gameplay:RecordAction(player, "buy_" .. itemName:lower())
end
function Merchant:SellPelt(player)
	local survival = self:_nearStall(player, false)
	if not survival or not self.Gameplay.Pelts then
		return
	end
	if self.Gameplay.Pelts:GetCount(player) < 1 then
		self.Gameplay:Notify(player, "You have no pelts to sell.")
		return
	end
	self.Gameplay.Pelts.Counts[player] -= 1
	self.Gameplay.Economy.Add(player, Config.Pelts.SellPrice)
	self.Gameplay:Notify(player, ("Sold a pelt for %d coins."):format(Config.Pelts.SellPrice))
end
function Merchant:UseMedkit(player)
	local survival = self.Gameplay._survivals[player]
	if not survival or not survival.Dead then
		return
	end
	if (self.MedkitCounts[player] or 0) < 1 then
		self.Gameplay:Notify(player, "You have no medkit.")
		return
	end
	self.MedkitCounts[player] -= 1
	self.Gameplay:ReviveWithMedkit(player)
end
function Merchant:_addPrompts(post)
	local function addPrompt(actionText, objectText, handler)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = actionText
		prompt.ObjectText = objectText
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 12
		prompt.Parent = post
		prompt.Triggered:Connect(handler)
	end
	addPrompt("Buy food (10 coins)", "Merchant", function(player)
		self:Buy(player, "Food")
	end)
	addPrompt("Buy fuel (5 coins)", "Merchant", function(player)
		self:Buy(player, "Fuel")
	end)
	addPrompt("Buy medkit (50 coins)", "Merchant", function(player)
		self:Buy(player, "Medkit")
	end)
	addPrompt("Sell pelt (8 coins)", "Merchant", function(player)
		self:SellPelt(player)
	end)
	addPrompt("Use medkit (revive)", "Merchant", function(player)
		self:UseMedkit(player)
	end)
end
function Merchant:CleanupPlayer(player)
	self.MedkitCounts[player] = nil
end
return Merchant
