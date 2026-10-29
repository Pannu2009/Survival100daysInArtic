-- Kids (Phase 3, setup): the 3 rescuable kids.
--
-- This is a CHILD module of Animals: it lives under the
-- Animals ModuleScript (Animals/init.lua is the parent
-- system, this file is its Kids child), and it follows
-- Animals' patterns -- a table of records stepped on the
-- server tick, ground-snapped kinematic movement, tags
-- for state, and server-validated prompts.
--
-- Setup scope, stated plainly: rescue + follow + a basic
-- work loop + eating. Kids are placeholder models (a
-- single part with a tag) until Ajay drops a real kid
-- model -- the code looks Assets.Kid up by name first
-- and uses it if present, exactly like the shed does.
-- Work yields are concrete where the game already has
-- the item (wood logs, fish) and abstract where it does
-- not yet (sled routes grant a few coins for supplies
-- found on the route -- a real route haul is the
-- slow-improve item). Eating is a shared camp-food
-- abstraction: kids take hunger from their owner's
-- hunger bar on a timer; a hungry kid stops working
-- until fed. Real food items for kids are slow-improve.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))

local Kids = {}
Kids.__index = Kids

function Kids.new(gameplay)
	local self = setmetatable({}, Kids)
	self.Gameplay = gameplay
	self.Kids = {}
	self.Folder = nil
	return self
end

function Kids:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Kids"
	folder.Parent = workspace
	self.Folder = folder
	local layout = self.Gameplay.World and self.Gameplay.World.Layout
	for i = 1, Config.Kids.Count do
		local pos = self:_rescuePosition(layout)
		if pos then
			self:_spawnKid(i, pos)
		end
	end
	print(("[Arctic] Kids: %d kids placed for rescue"):format(#self.Kids))
end

function Kids:_rescuePosition(layout)
	local lake = layout and layout.Lake
	local mountain = layout and layout.Mountain
	for _ = 1, 12 do
		local angle = math.random() * math.pi * 2
		local dist = math.random(Config.Kids.MinDistance, Config.Kids.MaxDistance)
		local x, z = math.cos(angle) * dist, math.sin(angle) * dist
		local ok = true
		if lake and math.sqrt((x - lake.X) ^ 2 + (z - lake.Z) ^ 2) < lake.Radius + 30 then
			ok = false
		end
		if mountain and math.sqrt((x - mountain.X) ^ 2 + (z - mountain.Z) ^ 2) < mountain.Radius * 0.8 then
			ok = false
		end
		if ok then
			return Vector3.new(x, 0, z)
		end
	end
	return Vector3.new(250, 0, 250)
end

function Kids:_spawnKid(id, position)
	local world = self.Gameplay.World
	local groundY = world:GroundY(position.X, position.Z)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = assets and (assets:FindFirstChild("Kid") or assets:FindFirstChild("KidModel"))
	local model
	if template and (template:IsA("Model") or template:IsA("BasePart")) then
		model = template:Clone()
		model.Name = "Kid" .. id
		for _, obj in ipairs(model:GetDescendants()) do
			if obj:IsA("BasePart") then
				obj.Anchored = true
				obj.CanCollide = false
			elseif obj:IsA("Script") or obj:IsA("LocalScript") then
				obj:Destroy()
			end
		end
		model.Parent = self.Folder
		if model:IsA("Model") then
			world:SnapToGround(model, position.X, position.Z)
		end
	else
		-- Placeholder kid: one part + a tag. Ajay's kid
		-- model, dropped in as Assets.Kid, replaces it.
		model = Instance.new("Model")
		model.Name = "Kid" .. id .. "PLACEHOLDER"
		local body = Instance.new("Part")
		body.Name = "KidBody"
		body.Size = Vector3.new(1.2, 2.4, 0.8)
		body.CFrame = CFrame.new(position.X, groundY + 1.2, position.Z)
		body.Anchored = true
		body.CanCollide = false
		body.Material = Enum.Material.SmoothPlastic
		body.Color = Color3.fromRGB(200, 180, 160)
		body.Parent = model
		model.Parent = self.Folder
	end
	local anchor = model:FindFirstChildWhichIsA("BasePart", true)
	local tag = Instance.new("BillboardGui")
	tag.Name = "KidTag"
	tag.Size = UDim2.fromOffset(180, 30)
	tag.StudsOffset = Vector3.new(0, 3, 0)
	tag.Parent = model
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "Kid -- rescue me!"
	label.TextColor3 = Color3.fromRGB(234, 160, 0)
	label.TextSize = 15
	label.Font = Enum.Font.GothamBold
	label.Parent = tag
	-- Kid names for the panel (first kid is Arzh, per Ajay's panel
	-- sketch). Rename here if Ajay renames a kid.
	local kidNames = { "Arzh", "Noor", "Veer" }
	local kid = {
		Id = id,
		Name = kidNames[id] or ("Kid " .. id),
		Model = model,
		Anchor = anchor,
		Tag = label,
		State = "Lost",
		Owner = nil,
		Hungry = false,
		Task = "Idle",
		TaskAssignBy = nil,
		HomePosition = nil,
		TaskTimer = 0,
		EatTimer = 0,
		RouteTarget = nil,
	}
	self:_addPrompts(kid)
	table.insert(self.Kids, kid)
	return kid
end

function Kids:_addPrompts(kid)
	local anchor = kid.Anchor
	if not anchor then
		return
	end
	local rescue = Instance.new("ProximityPrompt")
	rescue.Name = "RescuePrompt"
	rescue.ActionText = "Rescue kid"
	rescue.ObjectText = "Lost kid"
	rescue.HoldDuration = 0.5
	rescue.MaxActivationDistance = 12
	rescue.Parent = anchor
	rescue.Triggered:Connect(function(player)
		self:Rescue(player, kid)
	end)
	kid.RescuePrompt = rescue
	local assign = Instance.new("ProximityPrompt")
	assign.Name = "AssignPrompt"
	assign.ActionText = "Assign work"
	assign.ObjectText = "Kid work"
	assign.HoldDuration = 0.3
	assign.MaxActivationDistance = 12
	assign.Enabled = false
	assign.Parent = anchor
	-- Panel is the assign path now: the prompt just points there.
	assign.Triggered:Connect(function(player)
		if kid.Owner == player then
			self.Gameplay:Notify(player, "Open the Kids panel to assign " .. kid.Name .. " a task.")
		end
	end)
	kid.AssignPrompt = assign
	local feed = Instance.new("ProximityPrompt")
	feed.Name = "FeedPrompt"
	feed.ActionText = "Feed kid"
	feed.ObjectText = "Hungry kid"
	feed.HoldDuration = 0.3
	feed.MaxActivationDistance = 12
	feed.Enabled = false
	feed.Parent = anchor
	feed.Triggered:Connect(function(player)
		self:Feed(player, kid)
	end)
	kid.FeedPrompt = feed
end

function Kids:Rescue(player, kid)
	if kid.State ~= "Lost" then
		return
	end
	local survival = self.Gameplay._survivals[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not survival or survival.Dead or not root or not kid.Anchor then
		return
	end
	if (root.Position - kid.Anchor.Position).Magnitude > Config.Kids.RescueRange then
		return
	end
	-- Stay at base: rescued kids do NOT follow the player.
	-- Home is where they were rescued; a Stay task moves them
	-- to the campfire instead (see AssignTask).
	kid.State = "AtBase"
	kid.Owner = player
	kid.Hungry = false
	kid.Task = "Idle"
	kid.TaskAssignBy = nil
	kid.HomePosition = kid.Anchor and kid.Anchor.Position or nil
	kid.TaskTimer = 0
	kid.EatTimer = 0
	if kid.RescuePrompt then
		kid.RescuePrompt.Enabled = false
	end
	-- AssignPrompt stays disabled: the Kids panel assigns tasks.
	kid.Tag.Text = kid.Name .. " -- at base, assign a task"
	self.Gameplay:GrantKidMultiplier(player, kid.Id)
	self.Gameplay:Notify(player, "Kid rescued! Open the Kids panel to assign a task -- and remember, kids eat too.")
end

function Kids:AssignTask(player, kid, task)
	if kid.Owner ~= player or kid.State ~= "AtBase" then
		return false
	end
	-- Panel tasks only: Get Wood, Go Fishing, Stay at Campfire, Idle.
	local allowed = { Wood = true, Fish = true, Stay = true, Idle = true }
	if not allowed[task] then
		return false
	end
	kid.Task = task
	kid.TaskAssignBy = player.Name
	kid.TaskTimer = 0
	kid.RouteTarget = nil
	if task == "Stay" then
		-- Stay at campfire: move to the first built fire, if any,
		-- otherwise stay at home base.
		local fires = self.Gameplay.World and self.Gameplay.World.Fires
		local fire = fires and fires[1]
		if fire and fire.Core and kid.Model then
			local fp = fire.Core.Position
			local gy = self.Gameplay.World:GroundY(fp.X + 3, fp.Z)
			kid.Model:PivotTo(CFrame.new(fp.X + 3, gy + 1.2, fp.Z))
			kid.HomePosition = Vector3.new(fp.X + 3, gy, fp.Z)
		end
	end
	kid.Tag.Text = ("%s -- %s"):format(kid.Name, task)
	self.Gameplay:Notify(player, ("%s's task: %s"):format(kid.Name, task))
	return true
end

-- Panel data for one player, as "Name|Task|AssignedBy;..." so the
-- client panel needs no new remote: it reads KidPanel attribute.
function Kids:PanelStringFor(player)
	local rows = {}
	for _, kid in ipairs(self.Kids) do
		if kid.Owner == player then
			table.insert(rows, ("%s|%s|%s"):format(
				kid.Name, kid.Task, kid.TaskAssignBy or "-"))
		end
	end
	return table.concat(rows, ";")
end

function Kids:Feed(player, kid)
	if kid.Owner ~= player then
		return
	end
	local survival = self.Gameplay._survivals[player]
	if not survival or survival.Dead then
		return
	end
	if survival.Hunger:Get() < Config.Kids.FeedHunger then
		self.Gameplay:Notify(player, "You don't have enough food to feed the kid.")
		return
	end
	survival.Hunger:Eat(-Config.Kids.FeedHunger)
	kid.State = "AtBase"
	kid.Hungry = false
	kid.EatTimer = 0
	if kid.FeedPrompt then
		kid.FeedPrompt.Enabled = false
	end
	kid.Tag.Text = ("Kid -- working: %s"):format(kid.Task)
	self.Gameplay:Notify(player, "Kid fed -- back to work.")
end

-- Owner gone (left or died): the kid waits where they
-- stand and can be rescued again by anyone alive.
function Kids:OnOwnerGone(player)
	for _, kid in ipairs(self.Kids) do
		if kid.Owner == player then
			kid.Owner = nil
			kid.State = "Lost"
			kid.Task = "Idle"
			kid.TaskAssignBy = nil
			kid.HomePosition = nil
			kid.Tag.Text = "Kid -- rescue me!"
			if kid.RescuePrompt then
				kid.RescuePrompt.Enabled = true
			end
			if kid.AssignPrompt then
				kid.AssignPrompt.Enabled = false
			end
			if kid.FeedPrompt then
				kid.FeedPrompt.Enabled = false
			end
		end
	end
end

function Kids:CountFor(player)
	local n = 0
	for _, kid in ipairs(self.Kids) do
		if kid.Owner == player then
			n += 1
		end
	end
	return n
end

function Kids:CleanupPlayer(player)
	self:OnOwnerGone(player)
end

-- One physical log, delivered by a working kid: the same
-- shape as a felled-tree log (WoodLog template, or a
-- plain part fallback), so feeding and building accept it.
function Kids:_spawnLog(position)
	local gameplay = self.Gameplay
	local template = gameplay.World.WoodLogTemplate
	local log
	if template then
		log = template:Clone()
		log.Name = "WoodLog"
		log.Parent = gameplay.LogsFolder
		local part = log:FindFirstChild("Log", true) or log:FindFirstChildWhichIsA("BasePart", true)
		if part then
			gameplay.World:SnapPartToGround(log, part, position.X + 2, position.Z)
		end
	else
		log = Instance.new("Model")
		log.Name = "WoodLog"
		local part = Instance.new("Part")
		part.Name = "Log"
		part.Size = Vector3.new(1, 1, 5)
		part.Anchored = false
		part.CanCollide = true
		part.Material = Enum.Material.Wood
		part.Parent = log
		log.Parent = gameplay.LogsFolder
		gameplay.World:SnapPartToGround(log, part, position.X + 2, position.Z)
	end
	if log then
		gameplay:AttachDragPrompt(log)
	end
end

function Kids:_doWork(kid)
	local owner = kid.Owner
	if not owner then
		return
	end
	local survival = self.Gameplay._survivals[owner]
	local character = owner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not survival or survival.Dead or not root then
		return
	end
	if kid.Task == "Wood" then
		self:_spawnLog(root.Position)
		self.Gameplay:Notify(owner, "Your kid brought wood!")
	elseif kid.Task == "Fish" then
		if self.Gameplay.Fish then
			self.Gameplay.Fish:Spawn(root.Position.X + 3, root.Position.Z)
			self.Gameplay:Notify(owner, "Your kid caught a fish!")
		end
	-- Stay / Idle: no work yield, kid just stays at base.
	end
end

function Kids:Update(dt)
	for _, kid in ipairs(self.Kids) do
		if kid.State ~= "AtBase" or not kid.Owner then
			continue
		end
		local owner = kid.Owner
		local survival = self.Gameplay._survivals[owner]
		local character = owner.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not survival or survival.Dead or not root or not kid.Anchor then
			self:OnOwnerGone(owner)
			continue
		end
		-- At base: NO following. The kid stays where HomePosition
		-- says (rescue spot, or the campfire after a Stay task).
		if kid.HomePosition and kid.Model then
			local hp = kid.HomePosition
			local kp = kid.Anchor.Position
			if (Vector3.new(kp.X - hp.X, 0, kp.Z - hp.Z)).Magnitude > 2 then
				local gy = self.Gameplay.World:GroundY(hp.X, hp.Z)
				kid.Model:PivotTo(CFrame.new(hp.X, gy + 1.2, hp.Z))
			end
		end
		kid.EatTimer += dt
		if kid.EatTimer >= Config.Kids.EatInterval then
			kid.EatTimer = 0
			if survival.Hunger:Get() > 0 then
				survival.Hunger:Eat(-Config.Kids.EatHunger)
			else
				kid.Hungry = true
				kid.Tag.Text = kid.Name .. " -- hungry! Feed me."
				if kid.FeedPrompt then
					kid.FeedPrompt.Enabled = true
				end
				self.Gameplay:Notify(owner, "Your kid is hungry and stopped working!")
			end
		end
		if not kid.Hungry and (kid.Task == "Wood" or kid.Task == "Fish") then
			kid.TaskTimer += dt
			if kid.TaskTimer >= Config.Kids.WorkInterval then
				kid.TaskTimer = 0
				self:_doWork(kid)
			end
		end
	end
	-- Hungry is a flag, not a state: hungry kids stay at base,
	-- they just stop working until fed.
end

return Kids
