local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPack = game:GetService("StarterPack")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))

-- Weapons: every weapon and tool in the game lives here, driven by
-- the Definitions list below. Adding one = one new list entry plus a
-- model in Assets/Tools. No model, no tool.

local Weapons = {}
Weapons.__index = Weapons

local function getLogPart(log)
	return log:FindFirstChild("Log", true) or log:FindFirstChildWhichIsA("BasePart", true)
end

local function findWoodPart(model)
	return model:FindFirstChild("WoodPart", true)
		or model:FindFirstChild("Trunk", true)
		or model:FindFirstChildWhichIsA("BasePart", true)
end

local function lengthAxis(size)
	if size.Y >= size.X and size.Y >= size.Z then
		return Vector3.yAxis, size.Y
	elseif size.X >= size.Z then
		return Vector3.xAxis, size.X
	else
		return Vector3.zAxis, size.Z
	end
end

local function setLength(part, axisVec, newLength)
	local s = part.Size
	if axisVec == Vector3.yAxis then
		part.Size = Vector3.new(s.X, newLength, s.Z)
	elseif axisVec == Vector3.xAxis then
		part.Size = Vector3.new(newLength, s.Y, s.Z)
	else
		part.Size = Vector3.new(s.X, s.Y, newLength)
	end
end

local function rotateAround(model, center, rotation)
	local cf = model:GetPivot()
	model:PivotTo(CFrame.new(center) * rotation * CFrame.new(-center) * cf)
end

-- THE LIST. Order = hotbar order. Fields:
--   Id         tool name (must match the client hotbar + ToolAim names)
--   Kind       "Weapon" or "Tool"
--   Damage     tree/enemy health removed per validated hit (weapons)
--   Cooldown   seconds between validated uses, server-enforced
--   Range      server-side reach check for the tool's action
--   Asset      model name under ReplicatedStorage/Assets/Tools, or nil
--   KeepScripts  true = Ajay's scripts inside the asset clone survive
--              (the lighter's flame effects); false = stripped (axe)
--   FuelCost / StartFuel   lighter-style consumable, if the tool has one
Weapons.List = {
	{
		Id = "Axe",
		Kind = "Weapon",
		Damage = 1,
		Cooldown = Config.Tree.ChopCooldown,
		Range = Config.Tree.ChopRange,
		Asset = "Axe",
		KeepScripts = false,
	},
	{
		Id = "Shovel",
		Kind = "Tool",
		Cooldown = Config.Digging.Cooldown,
		Range = Config.Digging.AimRange,
		Asset = "Shovel",
		KeepScripts = false,
	},
	{
		Id = "Blueprint",
		Kind = "Tool",
		Cooldown = 0,
		Range = 0,
		Asset = "Blueprint",
		KeepScripts = false,
	},
	{
		Id = "Lighter",
		Kind = "Tool",
		Cooldown = 0,
		Range = Config.Lighter.AimRange,
		Asset = "Lighter",
		KeepScripts = true,
		FuelCost = Config.Lighter.LightCost,
		StartFuel = Config.Lighter.StartFuel,
	},
	{
		-- Day 2's tool: NOT in StarterPack (Deferred). Gameplay
		-- grants it with Weapons:GiveTool when Day 2 begins.
		Id = "FishingRod",
		Kind = "Tool",
		Cooldown = 0.3,
		Range = Config.Fishing.CastRange,
		Asset = "FishingRod",
		KeepScripts = false,
		Deferred = true,
	},
}

Weapons.Definitions = {}
for _, def in ipairs(Weapons.List) do
	Weapons.Definitions[def.Id] = def
end

function Weapons.Get(id)
	return Weapons.Definitions[id]
end

function Weapons.new(gameplay)
	local self = setmetatable({}, Weapons)
	self.Gameplay = gameplay
	self._fuel = {}
	self._cooldowns = {}
	return self
end

-- Clone Ajay's asset model for a definition and normalize it so it
-- always equips and activates: unanchor every part, guarantee a
-- Handle (a Tool with no Handle can never be held, so clicks
-- silently do nothing), weld loose parts to the Handle. Scripts are
-- stripped unless the definition says KeepScripts.
local function findToolTemplate(def)
	local assets = ReplicatedStorage:WaitForChild("Assets", 5)
	if not assets then
		return nil
	end
	local toolsFolder = assets:FindFirstChild("Tools")
	local template = toolsFolder and toolsFolder:FindFirstChild(def.Asset)
	if not template then
		template = assets:FindFirstChild(def.Asset)
	end
	if template and template:IsA("Tool") then
		return template
	end
	-- Last resort: a Tool whose name smells like this definition
	-- (e.g. a rod model named "Fishing Rod" instead of "FishingRod").
	local needle = def.Id:lower()
	for _, folder in ipairs({ toolsFolder, assets }) do
		if folder then
			for _, child in ipairs(folder:GetChildren()) do
				if child:IsA("Tool") and child.Name:lower():find(needle:sub(1, 4), 1, true) then
					return child
				end
			end
		end
	end
	return nil
end

local function cloneAssetTool(def)
	local template = findToolTemplate(def)
	if not template then
		return nil
	end
	local tool = template:Clone()
	tool.Name = def.Id
	tool.CanBeDropped = false
	local handle = nil
	local biggest = nil
	local biggestVolume = -1
	local parts = {}
	for _, d in ipairs(tool:GetDescendants()) do
		if (d:IsA("Script") or d:IsA("LocalScript")) and not def.KeepScripts then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = false
			table.insert(parts, d)
			if d.Name == "Handle" then
				handle = d
			end
			local volume = d.Size.X * d.Size.Y * d.Size.Z
			if volume > biggestVolume then
				biggestVolume = volume
				biggest = d
			end
		end
	end
	if not handle and biggest then
		biggest.Name = "Handle"
		handle = biggest
	end
	if handle then
		for _, part in ipairs(parts) do
			if part ~= handle then
				part.Massless = true
				part.CanCollide = false
				local welded = false
				for _, c in ipairs(part:GetDescendants()) do
					if c:IsA("WeldConstraint") or c:IsA("Weld") then
						welded = true
						break
					end
				end
				if not welded then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = handle
					weld.Part1 = part
					weld.Parent = part
				end
			end
		end
	end
	tool.RequiresHandle = handle ~= nil
	return tool
end

-- Build every tool in the list into StarterPack from its Assets model.
function Weapons:BuildTools()
	for _, def in ipairs(Weapons.List) do
		if def.Deferred then
			-- Granted later, on purpose (the rod at Day 2).
			continue
		end
		local tool = nil
		if def.Asset then
			tool = cloneAssetTool(def)
		end
		if tool then
			tool.Parent = StarterPack
		else
			warn(("[Arctic] Weapons: no Assets/Tools model for %s - tool not built"):format(def.Id))
		end
	end
end

-- Hand a Deferred tool to one player (into their Backpack, where
-- the auto-slot hotbar picks it up). No-op if they already have it
-- or the asset model is missing.
function Weapons:GiveTool(player, id)
	local def = Weapons.Definitions[id]
	if not def then
		return false
	end
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character
	if (backpack and backpack:FindFirstChild(id)) or (character and character:FindFirstChild(id)) then
		return true
	end
	local tool = def.Asset and cloneAssetTool(def)
	if not tool then
		warn(("[Arctic] Weapons: no Assets model for %s - cannot give"):format(id))
		return false
	end
	tool.Parent = backpack
	return true
end

function Weapons:SetupPlayer(player)
	-- Fuel persists across respawns; it only resets when the
	-- player leaves (CleanupPlayer) or first joins.
	for _, def in ipairs(Weapons.List) do
		if def.StartFuel and self._fuel[player] == nil then
			self._fuel[player] = def.StartFuel
		end
	end
	if not self._cooldowns[player] then
		self._cooldowns[player] = {}
	end
end

function Weapons:CleanupPlayer(player)
	self._fuel[player] = nil
	self._cooldowns[player] = nil
end

function Weapons:GetFuel(player)
	return self._fuel[player] or 0
end

-- Spend one use of the lighter's fuel. Gameplay's fire actions
-- (lighting a campfire, igniting a log) call this so the fuel
-- lives in exactly one place even though fires live in Gameplay.
function Weapons:SpendFuel(player)
	local def = Weapons.Definitions.Lighter
	if not def or not def.FuelCost then
		return false
	end
	local fuel = self._fuel[player] or 0
	if fuel < def.FuelCost then
		return false
	end
	self._fuel[player] = fuel - def.FuelCost
	return true
end

function Weapons:_cooldownReady(player, id, cooldown)
	local now = os.clock()
	local ready = self._cooldowns[player]
	if not ready then
		ready = {}
		self._cooldowns[player] = ready
	end
	if now < (ready[id] or 0) then
		return false
	end
	ready[id] = now + cooldown
	return true
end

function Weapons:_equippedRoot(player, id)
	local character = player.Character
	if not character then
		return nil, nil
	end
	if not character:FindFirstChild(id) then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil, nil
	end
	return character, root
end

-- Dig one snow column at (tx, tz). The target comes from the
-- player's center-dot aim; every check runs server-side.
function Weapons:_digAt(player, tx, tz)
	local def = Weapons.Definitions.Shovel
	local character, root = self:_equippedRoot(player, "Shovel")
	if not root then
		return
	end
	local dx = tx - root.Position.X
	local dz = tz - root.Position.Z
	if dx * dx + dz * dz > def.Range * def.Range then
		return
	end
	if not self:_cooldownReady(player, "Shovel", def.Cooldown) then
		return
	end

	local world = self.Gameplay.World
	if world:IsNearStructure(tx, tz, Config.Digging.SafeRadius) then
		return
	end

	local hit = world:TerrainRaycastDown(tx, tz)
	if not hit or hit.Material ~= Enum.Material.Snow then
		return
	end

	local terrain = workspace:WaitForChild("Terrain")
	local center = hit.Position - Vector3.new(0, Config.Digging.Radius * 0.35, 0)
	terrain:FillBall(center, Config.Digging.Radius, Enum.Material.Air)
	self.Gameplay:_markTutorial(player, "Dug")
end

-- Center-dot tool aim: the client raycasts the middle of the
-- screen and reports what the dot is on; the server decides what
-- happens. The shovel digs where the dot points; the lighter
-- lights the exact log or fire the dot is on. New dot tools plug
-- in here by Id.
function Weapons:OnToolAim(player, toolName, hitInstance, hitPosition)
	if typeof(hitPosition) ~= "Vector3" then
		return
	end
	local def = Weapons.Definitions[toolName]
	if not def then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if toolName == "Axe" then
		if not character:FindFirstChild("Axe") then
			return
		end
		local world = self.Gameplay.World
		-- Ice: the dot is ON the lake (glacier), crack it there.
		local groundHit = world:TerrainRaycastDown(hitPosition.X, hitPosition.Z)
		if groundHit and groundHit.Material == Enum.Material.Glacier
			and (groundHit.Position - hitPosition).Magnitude <= 3.5
			and (hitPosition - root.Position).Magnitude <= def.Range + 4
		then
			if self:_cooldownReady(player, "Axe", def.Cooldown) then
				self.Gameplay.Fish:HitIce(player, hitPosition)
			end
			return
		end
		-- Tree: the tree whose trunk the dot is touching.
		local treesFolder = world.TreesFolder
		if treesFolder then
			for _, tree in ipairs(treesFolder:GetChildren()) do
				if not tree:GetAttribute("Falling") then
					local cf, size = tree:GetBoundingBox()
					local localPos = cf:PointToObjectSpace(hitPosition)
					local closest = cf:PointToWorldSpace(Vector3.new(
						math.clamp(localPos.X, -size.X / 2, size.X / 2),
						math.clamp(localPos.Y, -size.Y / 2, size.Y / 2),
						math.clamp(localPos.Z, -size.Z / 2, size.Z / 2)
					))
					if (closest - hitPosition).Magnitude <= 2.5
						and (closest - root.Position).Magnitude <= def.Range + 2
					then
						self:_hitTree(player, tree, def)
						return
					end
				end
			end
		end
	elseif toolName == "Shovel" then
		if not character:FindFirstChild("Shovel") then
			return
		end
		-- The claimed point must sit on the real terrain column.
		local hit = self.Gameplay.World:TerrainRaycastDown(hitPosition.X, hitPosition.Z)
		if not hit or (hit.Position - hitPosition).Magnitude > 3.5 then
			return
		end
		-- On the lake the shovel cracks ice instead of digging
		-- (slower work than the axe: 7 hits to break through).
		if self.Gameplay.Fish:IsIceAt(hitPosition) then
			if self:_cooldownReady(player, "Shovel", def.Cooldown) then
				self.Gameplay.Fish:HitIce(player, hitPosition, Config.Fishing.ShovelIceWork)
			end
			return
		end
		self:_digAt(player, hitPosition.X, hitPosition.Z)
	elseif toolName == "FishingRod" then
		if not character:FindFirstChild("FishingRod") then
			return
		end
		self.Gameplay.Fish:OnAim(player, hitInstance, hitPosition)
	elseif toolName == "Lighter" then
		if not character:FindFirstChild("Lighter") then
			return
		end
		if (hitPosition - root.Position).Magnitude > def.Range then
			return
		end
		-- Dot on a log: that exact log catches.
		if typeof(hitInstance) == "Instance" and hitInstance:IsA("BasePart") then
			local model = hitInstance.Parent
			if model and model.Parent == self.Gameplay.LogsFolder
				and model:GetAttribute("Burnable")
				and model:GetAttribute("Burning") ~= true
				and not model:GetAttribute("OnSled")
			then
				local lp = getLogPart(model)
				if lp and lp:GetAttribute("DraggedBy") == nil then
					self.Gameplay:_igniteLog(player, model)
					return
				end
			end
		end
		-- Dot on a campfire: light that fire.
		for _, fire in ipairs(self.Gameplay.World.Fires) do
			if not fire.Lit and fire.Fuel > 0
				and (fire.Core.Position - hitPosition).Magnitude <= 4
			then
				self.Gameplay:_lightFire(player, fire)
				return
			end
		end
	end
end

function Weapons:_shakeTree(tree)
	local world = self.Gameplay.World
	if tree:GetAttribute("Shaking") or tree:GetAttribute("Falling") then
		return
	end
	tree:SetAttribute("Shaking", true)
	task.spawn(function()
		local pos = tree:GetPivot().Position
		local base = Vector3.new(pos.X, world:GroundY(pos.X, pos.Z), pos.Z)
		local axis = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
		if axis.Magnitude < 0.1 then
			axis = Vector3.new(1, 0, 0)
		end
		axis = axis.Unit
		local tilt = CFrame.fromAxisAngle(axis, math.rad(2.5))
		rotateAround(tree, base, tilt)
		task.wait(0.07)
		if tree.Parent then
			rotateAround(tree, base, tilt:Inverse())
			local settle = CFrame.fromAxisAngle(axis, math.rad(-1.2))
			rotateAround(tree, base, settle)
			task.wait(0.06)
			if tree.Parent then
				rotateAround(tree, base, settle:Inverse())
			end
		end
		if tree.Parent then
			tree:SetAttribute("Shaking", false)
		end
	end)
end

function Weapons:_dropLogPieces(treeModel, spotPos)
	local gameplay = self.Gameplay
	local template = gameplay.World.WoodLogTemplate
	if not template then
		return
	end
	local woodPart = findWoodPart(treeModel)
	if not woodPart then
		return
	end
	local woodSize = woodPart.Size
	local axisVec, woodLength = lengthAxis(woodSize)
	local isBig = woodLength >= Config.Log.BigTreeLength
	local targetLength = isBig and Config.Log.BigPieceTargetLength or Config.Log.PieceTargetLength
	local maxPieces = isBig and Config.Log.BigTreeMaxPieces or Config.Log.MaxPieces
	local pieceCount = math.clamp(math.round(woodLength / targetLength), 1, maxPieces)
	local pieceLength = woodLength / pieceCount

	for _ = 1, pieceCount do
		local log = template:Clone()
		local logPart = getLogPart(log)
		if logPart then
			log.Name = "WoodLog"
			logPart.Size = woodSize
			setLength(logPart, axisVec, pieceLength)
			for _, part in ipairs(log:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = true
					if part == logPart then
						part.Anchored = true
					else
						part.Anchored = false
						local weld = Instance.new("WeldConstraint")
						weld.Part0 = logPart
						weld.Part1 = part
						weld.Parent = part
					end
				end
			end
			log.Parent = gameplay.LogsFolder

			if axisVec == Vector3.yAxis then
				log:PivotTo(log:GetPivot() * CFrame.Angles(0, 0, math.rad(90)))
			end
			local pivot = log:GetPivot()
			local yaw = CFrame.Angles(0, math.random() * math.pi * 2, 0)
			log:PivotTo(CFrame.new(pivot.Position) * yaw * (pivot - pivot.Position))

			local ox = spotPos.X + (math.random() - 0.5) * 3
			local oz = spotPos.Z + (math.random() - 0.5) * 3
			gameplay.World:SnapPartToGround(log, logPart, ox, oz)

			gameplay:AttachDragPrompt(log)
		end
	end
end

function Weapons:_fellTree(tree)
	local world = self.Gameplay.World
	tree:SetAttribute("Falling", true)
	local spotPos = tree:GetPivot().Position
	task.spawn(function()
		local base = Vector3.new(spotPos.X, world:GroundY(spotPos.X, spotPos.Z), spotPos.Z)
		local axis = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
		if axis.Magnitude < 0.1 then
			axis = Vector3.new(1, 0, 0)
		end
		axis = axis.Unit
		local total = math.rad(math.random(72, 86))
		local steps = 16
		local previous = 0
		for i = 1, steps do
			if not tree.Parent then
				return
			end
			local t = i / steps
			local angle = total * t * t
			rotateAround(tree, base, CFrame.fromAxisAngle(axis, angle - previous))
			previous = angle
			task.wait(0.03)
		end
		if not tree.Parent then
			return
		end
		local bounce = CFrame.fromAxisAngle(axis, math.rad(-4))
		rotateAround(tree, base, bounce)
		task.wait(0.07)
		if not tree.Parent then
			return
		end
		rotateAround(tree, base, bounce:Inverse())
		self:_dropLogPieces(tree, spotPos)
		tree:Destroy()
	end)
end

-- One axe swing: equipped check, per-player cooldown from the
-- list, nearest reachable tree by bounding box, line of sight.
function Weapons:SwingAxe(player)
	local def = Weapons.Definitions.Axe
	local character, root = self:_equippedRoot(player, "Axe")
	if not root then
		return
	end
	local readyAt = self._cooldowns[player] and self._cooldowns[player]["Axe"] or 0
	if os.clock() < readyAt then
		return
	end

	local world = self.Gameplay.World
	local candidates = {}
	local treesFolder = world.TreesFolder
	if treesFolder then
		for _, tree in ipairs(treesFolder:GetChildren()) do
			if not tree:GetAttribute("Falling") then
				-- Range is measured to the nearest point of the tree's
				-- bounding box, not its pivot: his tree models are tall
				-- and their pivots sit high, so pivot distance put big
				-- trees out of range even when he stood at the trunk.
				local cf, size = tree:GetBoundingBox()
				local localPos = cf:PointToObjectSpace(root.Position)
				local closest = cf:PointToWorldSpace(Vector3.new(
					math.clamp(localPos.X, -size.X / 2, size.X / 2),
					math.clamp(localPos.Y, -size.Y / 2, size.Y / 2),
					math.clamp(localPos.Z, -size.Z / 2, size.Z / 2)
				))
				local distance = (closest - root.Position).Magnitude
				if distance <= def.Range then
					table.insert(candidates, { model = tree, distance = distance, point = closest })
				end
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)

	local target = nil
	local origin = root.Position + Vector3.new(0, 1, 0)
	for _, candidate in ipairs(candidates) do
		local direction = candidate.point - origin
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		-- Terrain is excluded: trees stand ON terrain, and a snow bump
		-- between the player and the trunk was silently eating swings.
		-- Rocks, cabins and props still block the line of sight.
		rayParams.FilterDescendantsInstances = { character, candidate.model, workspace.Terrain }
		rayParams.IgnoreWater = true
		local hit = workspace:Raycast(origin, direction, rayParams)
		if not hit or hit.Distance >= direction.Magnitude - 2 then
			target = candidate.model
			break
		end
	end
	if not target then
		return
	end
	self:_hitTree(player, target, def)
end

-- One validated axe hit on a tree: cooldown, health, shake or fell.
-- Shared by the proximity swing and the center-dot path.
function Weapons:_hitTree(player, target, def)
	if not self:_cooldownReady(player, "Axe", def.Cooldown) then
		return
	end
	local remaining = (target:GetAttribute("Health") or Config.Tree.Health) - def.Damage
	if remaining > 0 then
		target:SetAttribute("Health", remaining)
		self:_shakeTree(target)
		return
	end
	self:_fellTree(target)
	self.Gameplay:_markTutorial(player, "Felled")
end

return Weapons
