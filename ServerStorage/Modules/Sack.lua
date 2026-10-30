local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local DragSystem = require(Modules:WaitForChild("DragSystem"))
local Sack = {}
Sack.__index = Sack
local function getLogPart(log)
	return log:FindFirstChild("Log", true) or log:FindFirstChildWhichIsA("BasePart", true)
end
local function getFishPart(fish)
	return fish:FindFirstChild("F1") or fish:FindFirstChildWhichIsA("BasePart", true)
end
function Sack.new(gameplay)
	local self = setmetatable({}, Sack)
	self.Gameplay = gameplay
	self.Items = {}
	return self
end
function Sack:Count(player)
	local list = self.Items[player]
	return list and #list or 0
end
function Sack:_publish(player)
	player:SetAttribute("SackCount", self:Count(player))
	if self.Gameplay.Net then
		local survival = self.Gameplay._survivals[player]
		self.Gameplay.Net:SendToClient(player, "UpdateInventory", {
			Sack = self:Count(player),
			Coins = survival and survival.Coins or 0,
		})
	end
end
function Sack:Store(player)
	local part = DragSystem.GetPlayerItem(player)
	if not part then
		return
	end
	local list = self.Items[player]
	if not list then
		list = {}
		self.Items[player] = list
	end
	if #list >= Config.Sack.MaxItems then
		self.Gameplay:Notify(player, "Sack is full (5 items).")
		return
	end
	local model = part.Parent
	local desc = nil
	if model and model.Parent == self.Gameplay.LogsFolder then
		local logPart = getLogPart(model)
		if logPart then
			desc = { Kind = "Log", Size = logPart.Size }
		end
	elseif model and model.Parent == self.Gameplay.Fish.Folder then
		desc = {
			Kind = "Fish",
			Cooked = model:GetAttribute("Cooked") == true,
			Pieces = model:GetAttribute("Pieces") or Config.Food.PiecesPerFish,
		}
	elseif part.Parent == self.Gameplay.Meat.Folder then
		desc = { Kind = "Meat", Cooked = part:GetAttribute("Cooked") == true }
	end
	if not desc then
		return
	end
	DragSystem.Stop(player, part)
	if desc.Kind == "Meat" then
		part:Destroy()
	elseif model then
		model:Destroy()
	elseif part.Parent then
		part:Destroy()
	end
	table.insert(list, desc)
	self:_publish(player)
	self.Gameplay:Notify(player, ("Sacked (%d/5)."):format(#list))
end
function Sack:PopTop(player)
	local list = self.Items[player]
	if not list or #list == 0 then
		return nil
	end
	local desc = table.remove(list)
	self:_publish(player)
	return desc
end
function Sack:Take(player)
	local list = self.Items[player]
	if not list or #list == 0 then
		self.Gameplay:Notify(player, "Sack is empty.")
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local desc = list[#list]
	local pos = root.Position + root.CFrame.LookVector * 3
	local spawned = false
	if desc.Kind == "Log" then
		local template = self.Gameplay.World.WoodLogTemplate
		if template then
			local log = template:Clone()
			local logPart = getLogPart(log)
			if logPart then
				log.Name = "WoodLog"
				logPart.Size = desc.Size
				log.Parent = self.Gameplay.LogsFolder
				self.Gameplay.World:SnapPartToGround(log, logPart, pos.X, pos.Z)
				self.Gameplay:AttachDragPrompt(log)
				spawned = true
			else
				log:Destroy()
			end
		end
	elseif desc.Kind == "Fish" then
		local fish = self.Gameplay.Fish:Spawn(pos.X, pos.Z)
		if fish then
			fish:SetAttribute("LastDragger", player.UserId)
			for _, part in ipairs(fish:GetDescendants()) do
				if part:IsA("BasePart") then
					pcall(function() part:SetNetworkOwnershipAuto() end)
				end
			end
			fish:SetAttribute("Cooked", desc.Cooked)
			fish:SetAttribute("Pieces", desc.Pieces)
			if desc.Cooked then
				for _, part in ipairs(fish:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Color = Color3.fromRGB(198, 124, 56)
					end
				end
			end
			spawned = true
		end
	elseif desc.Kind == "Meat" then
		if self.Gameplay.Meat.Folder then
			local meat = self.Gameplay.Meat:Spawn(pos.X, pos.Z, desc.Cooked)
			if meat then
				meat:SetAttribute("LastDragger", player.UserId)
				pcall(function() meat:SetNetworkOwnershipAuto() end)
				spawned = true
			end
		end
	end
	if not spawned then
		self.Gameplay:Notify(player, "Could not take that item out -- it stays in your sack.")
		return
	end
	table.remove(list)
	self:_publish(player)
	self.Gameplay:Notify(player, ("Took from sack (%d/5 left)."):format(#list))
end
function Sack:CleanupPlayer(player)
	self.Items[player] = nil
end
return Sack
