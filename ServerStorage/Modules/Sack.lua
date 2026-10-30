-- Sack (Batch 1): Dead Rails style carry bag, 5 items max.
-- The player stores the item they are dragging (log, fish or
-- meat) and takes items back out, last in first out. Items are
-- stored as small descriptors, not models, so a full sack is
-- cheap. Taking an item respawns it in front of the player.
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
	self.Items = {} -- player -> array of descriptors
	return self
end

function Sack:Count(player)
	local list = self.Items[player]
	return list and #list or 0
end

function Sack:_publish(player)
	player:SetAttribute("SackCount", self:Count(player))
	-- Net example: the client listens for UpdateInventory
	-- and can refresh its HUD from this, instead of a
	-- second remote per inventory change.
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
	if model then
		model:Destroy()
	elseif part.Parent then
		part:Destroy()
	end
	table.insert(list, desc)
	self:_publish(player)
	self.Gameplay:Notify(player, ("Sacked (%d/5)."):format(#list))
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
	local desc = table.remove(list)
	local pos = root.Position + root.CFrame.LookVector * 3
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
			else
				log:Destroy()
			end
		end
	elseif desc.Kind == "Fish" then
		local x, z = pos.X, pos.Z
		self.Gameplay.Fish:Spawn(x, z)
		-- Spawn is fire-and-forget; find the newest fish near
		-- the player and restore its stored state.
		local best, bestDist = nil, 999
		for _, fish in ipairs(self.Gameplay.Fish.Folder:GetChildren()) do
			local p = getFishPart(fish)
			if p then
				local d = (p.Position - pos).Magnitude
				if d < bestDist then
					best, bestDist = fish, d
				end
			end
		end
		if best then
			best:SetAttribute("Cooked", desc.Cooked)
			best:SetAttribute("Pieces", desc.Pieces)
			if desc.Cooked then
				for _, p in ipairs(best:GetDescendants()) do
					if p:IsA("BasePart") then
						p.Color = Color3.fromRGB(198, 124, 56)
					end
				end
			end
		end
	elseif desc.Kind == "Meat" then
		self.Gameplay.Meat:Spawn(pos.X, pos.Z, desc.Cooked)
	end
	self:_publish(player)
	self.Gameplay:Notify(player, ("Took from sack (%d/5 left)."):format(#list))
end

function Sack:CleanupPlayer(player)
	self.Items[player] = nil
end

return Sack
