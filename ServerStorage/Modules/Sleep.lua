local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local Sleep = {}
Sleep.__index = Sleep
function Sleep.new(gameplay)
	local self = setmetatable({}, Sleep)
	self.Gameplay = gameplay
	self.Bags = {}
	self.Sleeping = {}
	return self
end
function Sleep:Start()
	if self.Gameplay.Clock and self.Gameplay.Clock.OnPhaseChanged then
		self.Gameplay.Clock.OnPhaseChanged:Connect(function(phase)
			if phase == "Day" then
				for player in pairs(self.Sleeping) do
					self:Wake(player, "Dawn breaks -- you wake up.")
				end
			end
		end)
	end
end
function Sleep:RegisterBag(model, anchor, owner)
	if not model or not anchor then
		return
	end
	local bag = { Model = model, Anchor = anchor, Occupant = nil, Owner = owner, CarriedBy = nil }
	self.Bags[model] = bag
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Sleep"
	prompt.ObjectText = "Sleeping bag"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = Config.Sleep.SleepRange
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player)
		if self.Sleeping[player] then
			self:Wake(player, "You wake up.")
			return
		end
		self:StartSleep(player, bag)
	end)
	local carry = Instance.new("ProximityPrompt")
	carry.Name = "CarryBagPrompt"
	carry.ActionText = "Carry bag"
	carry.ObjectText = "Sleeping bag"
	carry.HoldDuration = 0.3
	carry.MaxActivationDistance = Config.Sleep.SleepRange
	carry.Parent = anchor
	carry.Triggered:Connect(function(player)
		if bag.Owner ~= player then
			self.Gameplay:Notify(player, "That's not your sleeping bag.")
			return
		end
		if self.Sleeping[player] then
			self.Gameplay:Notify(player, "Wake up first, then carry the bag.")
			return
		end
		if bag.CarriedBy == player then
			bag.CarriedBy = nil
			carry.ActionText = "Carry bag"
			self.Gameplay:Notify(player, "Bag dropped here.")
		else
			bag.CarriedBy = player
			carry.ActionText = "Drop bag"
			self.Gameplay:Notify(player, "Carrying your bag -- it follows you now.")
		end
	end)
	bag.CarryPrompt = carry
end
function Sleep:StartSleep(player, bag)
	local survival = self.Gameplay._survivals[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not survival or survival.Dead or not root then
		return
	end
	if bag.Occupant then
		self.Gameplay:Notify(player, "That bag is already slept in.")
		return
	end
	if (root.Position - bag.Anchor.Position).Magnitude > Config.Sleep.SleepRange then
		return
	end
	root.CFrame = CFrame.new(bag.Anchor.Position.X, bag.Anchor.Position.Y + 1, bag.Anchor.Position.Z)
	root.Anchored = true
	bag.Occupant = player
	self.Sleeping[player] = { Bag = bag, Root = root }
	survival.CureBoost = Config.Sleep.CureBoost
	self.Gameplay:Notify(player, "You sleep... (hunger drains while you sleep)")
end
function Sleep:Wake(player, message)
	local state = self.Sleeping[player]
	if not state then
		return
	end
	self.Sleeping[player] = nil
	if state.Bag then
		state.Bag.Occupant = nil
	end
	if state.Root and state.Root.Parent then
		state.Root.Anchored = false
	end
	local survival = self.Gameplay._survivals[player]
	if survival then
		survival.CureBoost = 1
	end
	if message then
		self.Gameplay:Notify(player, message)
	end
end
function Sleep:IsSleeping(player)
	return self.Sleeping[player] ~= nil
end
function Sleep:GetWarmthBonus(player)
	if self.Sleeping[player] then
		return Config.Sleep.WarmthBonus
	end
	return 0
end
function Sleep:Update(dt)
	for _, bag in pairs(self.Bags) do
		if bag.CarriedBy and bag.Model and not self.Sleeping[bag.CarriedBy] then
			local character = bag.CarriedBy.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				local pos = root.Position + root.CFrame.LookVector * 3
				local gy = self.Gameplay.World and self.Gameplay.World:GroundY(pos.X, pos.Z) or pos.Y
				bag.Model:PivotTo(CFrame.new(pos.X, gy + 0.3, pos.Z) * root.CFrame.Rotation)
				if bag.Anchor then
					bag.Anchor.CFrame = CFrame.new(pos.X, gy + 1, pos.Z)
				end
			end
		end
	end
	for player in pairs(self.Sleeping) do
		local survival = self.Gameplay._survivals[player]
		local state = self.Sleeping[player]
		if not survival or survival.Dead or not state then
			self:Wake(player, nil)
		else
			survival.Hunger:Eat(-Config.Sleep.HungerPerSecond * dt)
			if survival.Hunger:Get() <= 0 then
				self:Wake(player, "You wake up starving!")
			end
		end
	end
end
function Sleep:CleanupPlayer(player)
	self:Wake(player, nil)
	for _, bag in pairs(self.Bags) do
		if bag.CarriedBy == player then bag.CarriedBy = nil end
	end
end
return Sleep
