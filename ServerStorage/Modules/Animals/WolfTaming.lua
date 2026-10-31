local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local Taming = {}
local W = Config.Wolves
function Taming:Feed(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local best, bestDist = nil, 14
	for _, wolf in ipairs(self.Wolves) do
		if not wolf.Owner and wolf.Health > 0 and wolf.Health <= W.TameHealth and not wolf.Removed then
			local d = (wolf.Root.Position - root.Position).Magnitude
			if d < bestDist then
				best, bestDist = wolf, d
			end
		end
	end
	if not best then
		self.Gameplay:Notify(player, "No weak wolf nearby to feed.")
		return
	end
	if self:Count(player) >= W.TeamLimit then
		self.Gameplay:Notify(player, "Your wolf team is full.")
		return
	end
	if best.TameTarget == nil then
		best.TameTarget = best.Leader and (W.TamePoints * W.LeaderTameMult) or W.TamePoints
		best.TamePoints = 0
		best.TameableSince = os.clock()
	end
	local foodType, desc = nil, nil
	local sack = self.Gameplay.Sack
	if sack then
		local list = sack.Items[player]
		if list and #list > 0 then
			local top = list[#list]
			if top.Kind == "Fish" then
				foodType = top.Cooked and "CookedFish" or "RawFish"
				desc = sack:PopTop(player)
			elseif top.Kind == "Meat" then
				foodType = top.Cooked and "CookedMeat" or "RawMeat"
				desc = sack:PopTop(player)
			end
		end
	end
	if not foodType then
		local DragSystem = require(Modules:WaitForChild("DragSystem"))
		local part = DragSystem.GetPlayerItem(player)
		if part then
			local model = part.Parent
			local isFish = model and model.Parent == self.Gameplay.Fish.Folder
			local isMeat = part.Name == "Meat" and self.Gameplay.Meat and self.Gameplay.Meat.Folder and part.Parent == self.Gameplay.Meat.Folder
			if isFish or isMeat then
				if isFish then
					foodType = model:GetAttribute("Cooked") == true and "CookedFish" or "RawFish"
				else
					foodType = part:GetAttribute("FoodType") or "RawMeat"
				end
				DragSystem.Stop(player, part)
				if model and model:IsA("Model") then
					model:Destroy()
				else
					part:Destroy()
				end
			end
		end
	end
	if not foodType then
		self.Gameplay:Notify(player, "No food to feed -- sack a fish or meat first, or drag one.")
		return
	end
	local points = (W.TameFoodPoints or {})[foodType] or 1
	best.TamePoints = (best.TamePoints or 0) + points
	local target = best.TameTarget or W.TamePoints
	if best.TamePoints < target then
		self.Gameplay:Notify(player, ("It wants more food! (%.1f/%.1f)"):format(best.TamePoints, target))
		best.State = "Roam"
		return
	end
	self:_claimWolf(best, player.UserId)
end
function Taming:_tryTame(wolf)
	if os.clock() < (wolf.RefuseUntil or 0) then
		return false
	end
	local pos = wolf.Root.Position
	local best, bestDist, bestFood = nil, 14, nil
	local fishFolder = self.Gameplay.Fish and self.Gameplay.Fish.Folder
	if fishFolder then
		for _, fish in ipairs(fishFolder:GetChildren()) do
			local lastDragger = fish:GetAttribute("LastDragger")
			if lastDragger and fish:GetAttribute("WolfEating") ~= true then
				local primary = fish:FindFirstChild("F1") or fish:FindFirstChildWhichIsA("BasePart", true)
				if primary and primary:GetAttribute("DraggedBy") == nil then
					local d = (primary.Position - pos).Magnitude
					if d < bestDist then
						best, bestDist = fish, d
						bestFood = fish:GetAttribute("Cooked") == true and "CookedFish" or "RawFish"
					end
				end
			end
		end
	end
	local meatFolder = self.Gameplay.Meat and self.Gameplay.Meat.Folder
	if meatFolder then
		for _, meat in ipairs(meatFolder:GetChildren()) do
			if meat:GetAttribute("LastDragger") and meat:GetAttribute("DraggedBy") == nil and meat:GetAttribute("WolfEating") ~= true then
				local d = (meat.Position - pos).Magnitude
				if d < bestDist then
					best, bestDist = meat, d
					bestFood = meat:GetAttribute("FoodType") or "RawMeat"
				end
			end
		end
	end
	if not best then
		return false
	end
	wolf.EatTarget = best
	wolf.EatFood = bestFood
	wolf.State = "GoEat"
	return true
end
function Taming:_tryHungryEat(wolf)
	local pos = wolf.Root.Position
	local best, bestDist, bestFood = nil, W.HungrySearchRange or 30, nil
	local fishFolder = self.Gameplay.Fish and self.Gameplay.Fish.Folder
	if fishFolder then
		for _, fish in ipairs(fishFolder:GetChildren()) do
			if fish:GetAttribute("WolfEating") ~= true then
				local primary = fish:FindFirstChild("F1") or fish:FindFirstChildWhichIsA("BasePart", true)
				if primary and primary:GetAttribute("DraggedBy") == nil then
					local d = (primary.Position - pos).Magnitude
					if d < bestDist then
						best, bestDist = fish, d
						bestFood = fish:GetAttribute("Cooked") == true and "CookedFish" or "RawFish"
					end
				end
			end
		end
	end
	local meatFolder = self.Gameplay.Meat and self.Gameplay.Meat.Folder
	if meatFolder then
		for _, meat in ipairs(meatFolder:GetChildren()) do
			if meat:GetAttribute("DraggedBy") == nil and meat:GetAttribute("WolfEating") ~= true then
				local d = (meat.Position - pos).Magnitude
				if d < bestDist then
					best, bestDist = meat, d
					bestFood = meat:GetAttribute("FoodType") or "RawMeat"
				end
			end
		end
	end
	if not best then return false end
	wolf.EatTarget = best
	wolf.EatFood = bestFood
	wolf.HungryEat = true
	wolf.State = "GoEat"
	return true
end
function Taming:_stepGoEat(wolf, dt, now)
	local fish = wolf.EatTarget
	local primary = nil
	if fish and fish.Parent then
		if fish:IsA("BasePart") then
			primary = fish
		else
			primary = fish:FindFirstChild("F1") or fish:FindFirstChildWhichIsA("BasePart", true)
		end
	end
	if not primary then
		wolf.EatTarget = nil
		wolf.EatingUntil = nil
		wolf.State = wolf.TargetPlayer and "Aggro" or "Roam"
		return
	end
	local draggedBy = primary:GetAttribute("DraggedBy")
	if draggedBy ~= nil then
		self:_failTame(wolf, draggedBy)
		return
	end
	if wolf.EatingUntil then
		if not primary or primary:GetAttribute("DraggedBy") ~= nil or fish:GetAttribute("WolfEating") ~= true then
			if fish and fish.Parent then
				fish:SetAttribute("WolfEating", nil)
			end
			if primary and primary.Parent then
				primary:SetAttribute("WolfEating", nil)
			end
			wolf.EatingUntil = nil
			wolf.EatTarget = nil
			wolf.State = wolf.TargetPlayer and "Aggro" or "Roam"
			return
		end
		self:_moveToward(wolf, wolf.Root.Position, 0, dt)
		if now >= wolf.EatingUntil then
			wolf.EatingUntil = nil
			wolf.EatTarget = nil
			self:_consumeFood(wolf, fish)
		end
		return
	end
	local d = self:_moveSmart(wolf, primary.Position, 6, dt)
	if d <= 2.2 then
		fish:SetAttribute("WolfEating", true)
		if primary ~= fish then
			primary:SetAttribute("WolfEating", true)
		end
		wolf.EatingUntil = now + W.EatSeconds
		if wolf.BiteSound then
			wolf.BiteSound:Play()
		end
	end
end
function Taming:_failTame(wolf, draggedBy)
	wolf.EatTarget = nil
	wolf.EatingUntil = nil
	wolf.RefuseUntil = os.clock() + W.TameRefuseSeconds
	local grabber = typeof(draggedBy) == "number" and Players:GetPlayerByUserId(draggedBy) or nil
	wolf.State = grabber and "Aggro" or "Roam"
	wolf.TargetPlayer = grabber
	if grabber then
		self.Gameplay:Notify(grabber, "Tame failed -- the wolf turned on you!")
	end
end
function Taming:_consumeFood(wolf, food)
	local lastDragger = food:GetAttribute("LastDragger")
	local foodType = wolf.EatFood or "RawFish"
	food:Destroy()
	wolf.EatFood = nil
	if wolf.HungryEat then
		wolf.HungryEat = false
		wolf.Hunger = math.min(100, (wolf.Hunger or 0) + (W.HungryEatRestore or 40))
		wolf.State = "Roam"
		return
	end
	local points = (W.TameFoodPoints or {})[foodType] or 1
	wolf.TamePoints = (wolf.TamePoints or 0) + points
	local target = wolf.TameTarget or W.TamePoints
	if wolf.TamePoints < target then
		local owner = lastDragger and Players:GetPlayerByUserId(lastDragger)
		if owner then
			self.Gameplay:Notify(owner, ("It wants more food! (%.1f/%.1f)"):format(wolf.TamePoints, target))
		end
		wolf.State = "Roam"
		return
	end
	self:_claimWolf(wolf, lastDragger)
end
function Taming:_claimWolf(wolf, lastDragger)
	local owner = lastDragger and Players:GetPlayerByUserId(lastDragger)
	wolf.TameTarget = nil
	wolf.TamePoints = 0
	wolf.TameableSince = nil
	if not owner or self:Count(owner) >= W.TeamLimit then
		wolf.Health = math.min(wolf.MaxHealth, wolf.Health + 40)
		wolf.State = "Roam"
		self:_refreshTag(wolf)
		return
	end
	wolf.Owner = owner
	wolf.TamedAt = os.clock()
	wolf.State = "Tamed"
	wolf.TargetPlayer = nil
	local list = self._byOwner[owner]
	if not list then
		list = {}
		self._byOwner[owner] = list
	end
	table.insert(list, wolf)
	wolf.SlotIndex = #list
	self.Gameplay:Notify(owner, ("Wolf tamed! (%d/%d)"):format(#list, W.TeamLimit))
	wolf.Model:SetAttribute("Owner", owner.UserId)
	self:_publishOwner(owner)
	self:_refreshTag(wolf)
	print(("[Arctic] %s tamed a wolf (%d/%d)"):format(owner.Name, #list, W.TeamLimit))
end
return Taming
