-- Sleep (Phase 3, setup): sleeping bags and sleep.
--
-- A built sleeping bag is a warmth anchor away from base. A
-- player sleeps in it through a ProximityPrompt (no client UI
-- needed): while asleep the character is anchored in the bag,
-- warmth gets the bag bonus, sickness cures faster (the
-- CureBoost seam in SurvivalPlayer), and hunger drains at
-- the sleep rate -- sleep rides out the night, but it costs
-- food. Sleep ends at dawn, when hunger runs out, on death,
-- or when the sleeper wakes with the same prompt.
--
-- The +1 day multiplier for the sleeping bag is NOT here:
-- it is granted once, when the first bag is BUILT, in
-- Gameplay.OnBlueprintBuilt -- crafting the bag is the
-- design's multiplier source, not each night slept.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))

local Sleep = {}
Sleep.__index = Sleep

function Sleep.new(gameplay)
	local self = setmetatable({}, Sleep)
	self.Gameplay = gameplay
	self.Bags = {} -- model -> { Anchor, Occupant }
	self.Sleeping = {} -- player -> { Bag, Root }
	return self
end

function Sleep:Start()
	-- Wake everyone at dawn: sleep is a night ride, not a
	-- way to skip days while the sun is up.
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

-- A completed bag gets its Sleep/Wake prompt. The prompt is
-- server-side, so the client needs no new button.
function Sleep:RegisterBag(model, anchor, owner)
	if not model or not anchor then
		return
	end
	-- Owner = the player who built it: 1 bag per player, and only
	-- the owner can carry it. CarriedBy moves the bag with the
	-- owner each tick (see Update) until dropped.
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
	-- Carry anywhere: owner picks the bag up, it follows them;
	-- trigger again to drop it where they stand.
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
		return -- prompt range is client-side; re-check here
	end
	-- Anchor in the bag: sleeping is still, by design.
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

-- Warmth while asleep: the bag bonus, on top of any fire
-- rate Gameplay already found. SurvivalPlayer adds this
-- bonus to the fire rate, so a bag alone holds warmth
-- against a clear night and slows a storm night's loss.
function Sleep:GetWarmthBonus(player)
	if self.Sleeping[player] then
		return Config.Sleep.WarmthBonus
	end
	return 0
end

function Sleep:Update(dt)
	-- Carried bags follow their owner (ground-snapped, in front).
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
			-- Sleep costs food: the night ride is paid for
			-- in hunger, not for free.
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
	-- A leaving player's bag stays built for the run; only
	-- the sleeper state goes with them.
end

return Sleep
