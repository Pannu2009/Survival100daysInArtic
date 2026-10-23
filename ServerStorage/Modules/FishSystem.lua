local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local DragSystem = require(Modules:WaitForChild("DragSystem"))

-- Fish items (Ajay's Assets.Fish, parts F1..F5): physical,
-- draggable, cookable, eaten piece by piece. Split out of Gameplay
-- to keep files under 1,000 lines; Gameplay owns the wiring
-- (remotes, the per-tick call) and the shared state it reads
-- (survivals, burning logs, the world).
local FishSystem = {}
FishSystem.__index = FishSystem

local function getLogPart(log)
	return log:FindFirstChild("Log", true) or log:FindFirstChildWhichIsA("BasePart", true)
end

function FishSystem.new(gameplay)
	local self = setmetatable({}, FishSystem)
	self.Gameplay = gameplay
	self.Folder = nil
	self.Template = nil
	self.HolesFolder = nil
	self.Holes = {} -- cellKey -> { Part, Position, ExpiresAt }
	self.IceHits = {} -- cellKey -> { Hits, Needed }
	self.Sessions = {} -- player -> fishing session
	return self
end

function FishSystem:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Fish"
	folder.Parent = workspace
	self.Folder = folder

	local assets = ReplicatedStorage:WaitForChild("Assets", 5)
	self.Template = assets and assets:FindFirstChild("Fish")

	local holesFolder = Instance.new("Folder")
	holesFolder.Name = "FishingHoles"
	holesFolder.Parent = workspace
	self.HolesFolder = holesFolder
end

local function getFishPart(fish)
	return fish:FindFirstChild("F1") or fish:FindFirstChildWhichIsA("BasePart", true)
end

local function pointInPart(position, part, slack)
	local p = part.CFrame:PointToObjectSpace(position)
	local s = part.Size
	return math.abs(p.X) <= s.X / 2 + slack
		and math.abs(p.Y) <= s.Y / 2 + slack
		and math.abs(p.Z) <= s.Z / 2 + slack
end

-- Fish are physical items built from Ajay's Assets.Fish (parts
-- F1..F5, welded to F1): drag them, cook them in a fire's FireBox,
-- eat them.
function FishSystem:Spawn(x, z)
	local template = self.Template
	if not template then
		return
	end
	local fish = template:Clone()
	fish.Name = "Fish"
	fish:SetAttribute("Weight", 1.5)
	fish:SetAttribute("Cooked", false)
	fish:SetAttribute("Pieces", Config.Food.PiecesPerFish)
	fish.Parent = self.Folder

	local primary = getFishPart(fish)
	if not primary then
		fish:Destroy()
		return
	end
	local delta = Vector3.new(x, self.Gameplay.World:GroundY(x, z) + 1, z) - primary.Position
	for _, part in ipairs(fish:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CFrame = part.CFrame + delta
		end
	end
	for _, part in ipairs(fish:GetDescendants()) do
		if part:IsA("BasePart") then
			if part == primary then
				part.Anchored = true
				part.CanCollide = true
			else
				part.Anchored = false
				part.CanCollide = false
				part.Massless = true
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primary
				weld.Part1 = part
				weld.Parent = primary
			end
		elseif part:IsA("Script") or part:IsA("LocalScript") then
			part:Destroy()
		end
	end
	if fish:IsA("Model") then
		fish.PrimaryPart = primary
	end
	self:_attachDragPrompt(fish, primary)
end

function FishSystem:_attachDragPrompt(fish, part)
	fish:SetAttribute("Draggable", true)
	part:SetAttribute("Draggable", true)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Drag"
	prompt.ObjectText = "Fish"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		if part:GetAttribute("DraggedBy") == player.UserId then
			DragSystem.Stop(player, part)
		elseif part:GetAttribute("DraggedBy") == nil then
			if DragSystem.Start(player, part) then
				prompt.ActionText = "Drop"
			end
		end
	end)
end

function FishSystem:Eat(player, fish)
	if typeof(fish) ~= "Instance" or fish.Parent ~= self.Folder then
		return
	end
	local survival = self.Gameplay._survivals[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local part = getFishPart(fish)
	if not survival or not root or not part then
		return
	end
	if (part.Position - root.Position).Magnitude > 11 then
		return
	end
	-- One fish is 5 pieces; each eat takes one piece off the model.
	local cooked = fish:GetAttribute("Cooked") == true
	survival.Hunger:Eat(cooked and Config.Food.CookedPieceHunger or Config.Food.RawPieceHunger)
	-- Health goes through the survival system's own methods, never
	-- a direct assignment: Heal/Damage route through _setHealth, so
	-- OnHealthChanged fires and hitting zero sets Dead + OnDied.
	-- (Raw fish heals negative -- at low health it can kill you.)
	local heal = cooked and Config.Food.CookedPieceHeal or Config.Food.RawPieceHeal
	if heal >= 0 then
		survival:Heal(heal)
	else
		survival:Damage(-heal)
	end
	local pieces = (fish:GetAttribute("Pieces") or Config.Food.PiecesPerFish) - 1
	if pieces <= 0 then
		if part:GetAttribute("DraggedBy") then
			DragSystem.ForceStop(part)
		end
		fish:Destroy()
		return
	end
	fish:SetAttribute("Pieces", pieces)
	fish:SetAttribute("Weight", 1.5 * pieces / Config.Food.PiecesPerFish)
	for i = Config.Food.PiecesPerFish, 2, -1 do
		local piecePart = fish:FindFirstChild("F" .. i)
		if piecePart then
			piecePart:Destroy()
			break
		end
	end
end

-- A fish resting inside a burning fire's CookingPart cooks over
-- CookSeconds, then turns golden and counts as cooked food.
function FishSystem:Cook(dt)
	if not self.Folder then
		return
	end
	for _, fish in ipairs(self.Folder:GetChildren()) do
		if fish:GetAttribute("Cooked") ~= true then
			local part = getFishPart(fish)
			if part and part:GetAttribute("DraggedBy") == nil then
				local cooking = false
				for _, fire in ipairs(self.Gameplay.World.Fires) do
					if fire.Lit and fire.Fuel > 0 and fire.CookingPart
						and pointInPart(part.Position, fire.CookingPart, 0.75)
					then
						cooking = true
						break
					end
				end
				if not cooking then
					for log in pairs(self.Gameplay._burning) do
						local lp = getLogPart(log)
						if lp and (lp.Position - part.Position).Magnitude <= Config.Campfire.BurningLogCookRange then
							cooking = true
							break
						end
					end
				end
				if cooking then
					local t = (fish:GetAttribute("CookTime") or 0) + dt
					if t >= Config.Food.CookSeconds then
						fish:SetAttribute("Cooked", true)
						for _, p in ipairs(fish:GetDescendants()) do
							if p:IsA("BasePart") then
								p.Color = Color3.fromRGB(198, 124, 56)
							end
						end
					else
						fish:SetAttribute("CookTime", t)
					end
				elseif (fish:GetAttribute("CookTime") or 0) ~= 0 then
					fish:SetAttribute("CookTime", 0)
				end
			end
		end
	end
end
-- ============ Day 2 ice fishing ============
-- Tools crack a lake-ice cell by work points (axe 3 hits,
-- shovel 7) into a water hole. The rod casts at a hole: wait for the
-- bite, tap inside the window to set the hook, then a Fisch-style
-- reel game -- a needle sweeps back and forth; tap when it crosses
-- the drifting zone to gain progress. The needle and zone are pure
-- functions of elapsed time from shared start values, so the client
-- renders them locally from attributes and the server judges taps
-- with the same math. Everything is validated server-side.

local ICE_CELL = 4

local function iceKey(x, z)
	return math.floor(x / ICE_CELL) .. "," .. math.floor(z / ICE_CELL)
end

local function reelNeedle(elapsed)
	local phase = (elapsed % Config.Fishing.ReelSweepSeconds) / Config.Fishing.ReelSweepSeconds
	if phase < 0.5 then
		return phase * 2
	end
	return 2 - phase * 2
end

local function reelZone(elapsed, seed)
	return 0.5 + 0.38 * math.sin(elapsed * 0.9 + seed)
end

-- Is this point lake ice? The glacier slab sits UNDER the snow
-- fill at the lake, so the surface material alone lies -- inside
-- the lake's bounds it's ice whatever the top voxel says.
function FishSystem:IsIceAt(position)
	local world = self.Gameplay.World
	local hit = world:TerrainRaycastDown(position.X, position.Z)
	if not hit or (hit.Position - position).Magnitude > 3.5 then
		return false
	end
	if hit.Material == Enum.Material.Glacier then
		return true
	end
	local lake = world.Layout and world.Layout.Lake
	if lake then
		local dx = position.X - lake.X
		local dz = position.Z - lake.Z
		if dx * dx + dz * dz <= (lake.Radius * 0.95) * (lake.Radius * 0.95) then
			return true
		end
	end
	return false
end

-- Crack ice by work points: an axe hit does 7, a shovel hit 3,
-- the cell breaks at 21 -- axe 3 hits, shovel 7, mixes proportion.
function FishSystem:HitIce(player, position, work)
	if self.Sessions[player] then
		return
	end
	local key = iceKey(position.X, position.Z)
	if self.Holes[key] then
		return
	end
	local cell = self.IceHits[key]
	if not cell then
		cell = { Work = 0 }
		self.IceHits[key] = cell
	end
	cell.Work += work
	if cell.Work < Config.Fishing.IceWorkNeeded then
		return
	end
	self.IceHits[key] = nil

	-- Break through: carve the ice sheet itself (same terrain
	-- carving as digging snow) -- the water layer underneath
	-- shows in the hole. Refreezing fills it back in.
	local world = self.Gameplay.World
	local cx = (math.floor(position.X / ICE_CELL) + 0.5) * ICE_CELL
	local cz = (math.floor(position.Z / ICE_CELL) + 0.5) * ICE_CELL
	local surfaceY = world:GroundY(cx, cz)
	local carveCenter = Vector3.new(cx, surfaceY - 0.4, cz)
	local terrain = workspace:WaitForChild("Terrain")
	terrain:FillBall(carveCenter, 2.1, Enum.Material.Air)
	self.Holes[key] = {
		Position = Vector3.new(cx, surfaceY, cz),
		CarveCenter = carveCenter,
		ExpiresAt = os.clock() + Config.Fishing.HoleLifeSeconds,
	}
end

local function sessionRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

function FishSystem:_publishSession(player)
	local session = self.Sessions[player]
	if not session then
		player:SetAttribute("FishingPhase", "")
		return
	end
	player:SetAttribute("FishingPhase", session.Phase)
	player:SetAttribute("FishingProgress", math.floor(session.Progress))
	if session.Phase == "Reel" then
		player:SetAttribute("FishingStartAt", session.ReelStartAt)
		player:SetAttribute("FishingSeed", session.Seed)
	end
end

function FishSystem:_endSession(player)
	local session = self.Sessions[player]
	if not session then
		return
	end
	if session.Bobber then
		session.Bobber:Destroy()
	end
	if session.Line then
		session.Line:Destroy()
	end
	if session.RodAtt then
		session.RodAtt:Destroy()
	end
	self.Sessions[player] = nil
	player:SetAttribute("FishingPhase", "")
end

function FishSystem:_startSession(player, hole)
	local character = player.Character
	local rod = character and character:FindFirstChild("FishingRod")
	local handle = rod and (rod:FindFirstChild("Handle") or rod:FindFirstChildWhichIsA("BasePart", true))
	local session = {
		Phase = "Waiting",
		Hole = hole,
		BiteAt = os.clock() + math.random(Config.Fishing.BiteWaitMin, Config.Fishing.BiteWaitMax),
		Progress = 0,
		Seed = math.random() * 100,
		LastTap = 0,
	}
	-- Bobber in the hole + a line from the rod tip. The line is a
	-- Beam between two attachments; no string on Ajay's rod model
	-- yet, so the code draws it.
	local bobber = Instance.new("Part")
	bobber.Name = "Bobber"
	bobber.Shape = Enum.PartType.Ball
	bobber.Size = Vector3.new(0.4, 0.4, 0.4)
	bobber.Color = Color3.fromRGB(214, 48, 43)
	bobber.Material = Enum.Material.SmoothPlastic
	bobber.Anchored = true
	bobber.CanCollide = false
	bobber.CanQuery = false
	bobber.CFrame = CFrame.new(hole.Position + Vector3.new(0, -0.7, 0))
	bobber.Parent = self.HolesFolder
	session.Bobber = bobber
	if handle then
		local rodAtt = Instance.new("Attachment")
		rodAtt.Name = "FishingLineRod"
		rodAtt.Parent = handle
		local bobAtt = Instance.new("Attachment")
		bobAtt.Name = "FishingLineBobber"
		bobAtt.Parent = bobber
		local beam = Instance.new("Beam")
		beam.Attachment0 = rodAtt
		beam.Attachment1 = bobAtt
		beam.Width0 = 0.03
		beam.Width1 = 0.03
		beam.Color = ColorSequence.new(Color3.fromRGB(230, 230, 230))
		beam.FaceCamera = false
		beam.Parent = bobber
		session.RodAtt = rodAtt
		session.Line = beam
	end
	self.Sessions[player] = session
	self:_publishSession(player)
end

-- Rod activation rides the center-dot ToolAim remote. With no live
-- session it is a cast (dot must be on/near a hole); during Bite it
-- sets the hook; during Reel it is a reel tap.
function FishSystem:OnAim(player, hitInstance, hitPosition)
	local root = sessionRoot(player)
	if not root then
		return
	end
	local session = self.Sessions[player]
	local now = os.clock()
	if session then
		if now - session.LastTap < 0.15 then
			return
		end
		session.LastTap = now
		if session.Phase == "Bite" then
			session.Phase = "Reel"
			session.ReelStartAt = workspace:GetServerTimeNow()
			session.ReelEndsAt = now + Config.Fishing.ReelSeconds
			session.Progress = 20
			self:_publishSession(player)
		elseif session.Phase == "Reel" then
			local elapsed = workspace:GetServerTimeNow() - session.ReelStartAt
			local needle = reelNeedle(elapsed)
			local zone = reelZone(elapsed, session.Seed)
			if math.abs(needle - zone) <= Config.Fishing.ReelZoneHalf then
				session.Progress += Config.Fishing.ReelGoodGain
			else
				session.Progress -= Config.Fishing.ReelBadLoss
			end
			if session.Progress >= 100 then
				-- Caught: the fish flops onto the ice beside the hole.
				local holePos = session.Hole.Position
				local toward = (root.Position - holePos)
				toward = Vector3.new(toward.X, 0, toward.Z)
				if toward.Magnitude > 0.1 then
					toward = toward.Unit * 1.6
				end
				self:_endSession(player)
				self:Spawn(holePos.X + toward.X, holePos.Z + toward.Z)
				return
			elseif session.Progress <= 0 then
				self:_endSession(player)
				return
			end
			self:_publishSession(player)
		end
		return
	end

	-- Cast: find a hole near the dot, within cast range of the player.
	if typeof(hitPosition) ~= "Vector3" then
		return
	end
	local best, bestDist = nil, math.huge
	for _, hole in pairs(self.Holes) do
		local d = (hole.Position - hitPosition).Magnitude
		if d < bestDist then
			best, bestDist = hole, d
		end
	end
	if not best or bestDist > 6 then
		return
	end
	if (best.Position - root.Position).Magnitude > Config.Fishing.CastRange then
		return
	end
	self:_startSession(player, best)
end

function FishSystem:TickFishing(dt)
	local now = os.clock()
	-- Holes refreeze: the carved cell is filled back in with ice.
	for key, hole in pairs(self.Holes) do
		if now >= hole.ExpiresAt then
			local terrain = workspace:WaitForChild("Terrain")
			terrain:FillBlock(
				CFrame.new(hole.CarveCenter.X, hole.Position.Y - 0.5, hole.CarveCenter.Z),
				Vector3.new(4.4, 1.2, 4.4),
				Enum.Material.Glacier
			)
			self.Holes[key] = nil
		end
	end
	for player, session in pairs(self.Sessions) do
		local root = sessionRoot(player)
		if not root or now >= session.Hole.ExpiresAt then
			self:_endSession(player)
			continue
		end
		if (session.Hole.Position - root.Position).Magnitude > Config.Fishing.CastRange + 4 then
			self:_endSession(player) -- walked away: line's gone
			continue
		end
		if session.Phase == "Waiting" and now >= session.BiteAt then
			session.Phase = "Bite"
			session.BiteEndsAt = now + Config.Fishing.BiteWindow
			if session.Bobber then
				session.Bobber.CFrame = CFrame.new(session.Hole.Position + Vector3.new(0, -0.95, 0))
			end
			self:_publishSession(player)
		elseif session.Phase == "Bite" and now > session.BiteEndsAt then
			self:_endSession(player) -- missed it: fish is gone
		elseif session.Phase == "Reel" then
			session.Progress -= Config.Fishing.ReelDecayPerSecond * dt
			if session.Progress <= 0 or now > session.ReelEndsAt then
				self:_endSession(player)
			else
				self:_publishSession(player)
			end
		end
	end
end

return FishSystem
