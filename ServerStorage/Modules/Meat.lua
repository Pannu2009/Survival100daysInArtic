local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local DragSystem = require(Modules:WaitForChild("DragSystem"))
local Meat = {}
Meat.__index = Meat
local function pointInPart(position, part, slack)
	local p = part.CFrame:PointToObjectSpace(position)
	local s = part.Size
	return math.abs(p.X) <= s.X / 2 + slack
		and math.abs(p.Y) <= s.Y / 2 + slack
		and math.abs(p.Z) <= s.Z / 2 + slack
end
local function getLogPart(log)
	return log:FindFirstChild("Log", true) or log:FindFirstChildWhichIsA("BasePart", true)
end
function Meat.new(gameplay)
	local self = setmetatable({}, Meat)
	self.Gameplay = gameplay
	self.Folder = nil
	return self
end
function Meat:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Meat"
	folder.Parent = workspace
	self.Folder = folder
end
function Meat:Spawn(x, z, cooked)
	if not self.Folder then
		return nil
	end
	local part = Instance.new("Part")
	part.Name = "Meat"
	part.Size = Vector3.new(1.2, 0.4, 1)
	part.Material = Enum.Material.SmoothPlastic
	part.Color = cooked and Color3.fromRGB(198, 124, 56) or Color3.fromRGB(150, 50, 50)
	part.Anchored = false
	part.CanCollide = true
	part:SetAttribute("Draggable", true)
	part:SetAttribute("Cooked", cooked == true)
	part:SetAttribute("FoodType", cooked and "CookedMeat" or "RawMeat")
	part:SetAttribute("CookTime", 0)
	local y = self.Gameplay.World:GroundY(x, z) + 1
	part.CFrame = CFrame.new(x, y, z)
	part.Parent = self.Folder
	return part
end
function Meat:OnWolfKilled(wolf, attacker)
	if not wolf or wolf.Owner or not self.Folder then
		return
	end
	local pos = wolf.Root and wolf.Root.Position
	if not pos then
		return
	end
	local count = wolf.Leader and Config.Wolves.MeatDropLeader or Config.Wolves.MeatDropRegular
	for i = 1, count do
		self:Spawn(pos.X + (i - 1) * 1.5, pos.Z, false)
	end
end
function Meat:Eat(player, meat)
	if typeof(meat) ~= "Instance" or meat.Parent ~= self.Folder then
		return
	end
	local survival = self.Gameplay._survivals[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not survival or survival.Dead or not root then
		return
	end
	local draggedBy = meat:GetAttribute("DraggedBy")
	if draggedBy ~= nil and draggedBy ~= player.UserId then
		return
	end
	if (meat.Position - root.Position).Magnitude > 11 then
		return
	end
	local cooked = meat:GetAttribute("Cooked") == true
	if cooked then
		survival.Hunger:Eat(Config.Food.CookedMeat)
		survival:Heal(2)
	else
		survival.Hunger:Eat(Config.Food.RawMeat)
		survival:Damage(2)
	end
	self.Gameplay:RecordAction(player, "eat")
	if draggedBy then
		DragSystem.ForceStop(meat)
	end
	meat:Destroy()
end
function Meat:Cook(dt)
	if not self.Folder then
		return
	end
	for _, meat in ipairs(self.Folder:GetChildren()) do
		if meat:GetAttribute("Cooked") ~= true and meat:GetAttribute("DraggedBy") == nil then
			local cooking = false
			for _, fire in ipairs(self.Gameplay.World.Fires) do
				if fire.Lit and fire.Fuel > 0 and fire.CookingPart
					and pointInPart(meat.Position, fire.CookingPart, 0.75)
				then
					cooking = true
					break
				end
			end
			if not cooking then
				for log in pairs(self.Gameplay._burning) do
					local lp = getLogPart(log)
					if lp and (lp.Position - meat.Position).Magnitude <= Config.Campfire.BurningLogCookRange then
						cooking = true
						break
					end
				end
			end
			if cooking then
				local t = (meat:GetAttribute("CookTime") or 0) + dt
				if t >= Config.Food.CookSeconds then
					meat:SetAttribute("Cooked", true)
					meat:SetAttribute("FoodType", "CookedMeat")
					meat.Color = Color3.fromRGB(198, 124, 56)
				else
					meat:SetAttribute("CookTime", t)
				end
			elseif (meat:GetAttribute("CookTime") or 0) ~= 0 then
				meat:SetAttribute("CookTime", 0)
			end
		end
	end
end
return Meat
