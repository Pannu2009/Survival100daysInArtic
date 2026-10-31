local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local AnimationModule = require(Modules:WaitForChild("AnimationModule"))
local SoundModule = require(Modules:WaitForChild("SoundModule"))
local Builder = {}
local W = Config.Wolves
local function findRootPart(model)
	local named = model:FindFirstChild("HumanoidRootPart", true)
		or model:FindFirstChild("Root", true)
		or model:FindFirstChild("Body", true)
	if named and named:IsA("BasePart") then
		return named
	end
	local biggest, biggestVolume = nil, -1
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > biggestVolume then
				biggest, biggestVolume = d, v
			end
		end
	end
	return biggest
end
function Builder:_buildWolf()
	local walkTrack = nil
	local attackTrack = nil
	local idleTrack = nil
	local howlTrack = nil
	local biteSoundFound = nil
	local variantName = (W.VariantOrder or {})[math.random(#(W.VariantOrder or { "WolfModel" }))]
	local variant = (W.Variants or {})[variantName] or { Health = W.MaxHealth, Bite = W.BiteDamage, SpeedMult = 1, Level = 1 }
	local template = (self.VariantTemplates and self.VariantTemplates[variantName]) or self.Template
	local wolf = template:Clone()
	CollectionService:AddTag(wolf, "ArcticWolf")
	for _, d in ipairs(wolf:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	local root = findRootPart(wolf)
	if not root then
		wolf:Destroy()
		return nil
	end
	local jointed = {}
	for _, d in ipairs(wolf:GetDescendants()) do
		if d:IsA("Motor6D") or d:IsA("Weld") or d:IsA("WeldConstraint") then
			if d.Part0 then
				jointed[d.Part0] = true
			end
			if d.Part1 then
				jointed[d.Part1] = true
			end
		end
	end
	for _, d in ipairs(wolf:GetDescendants()) do
		if d:IsA("BasePart") then
			if d == root then
				d.Anchored = true
				d.CanCollide = false
			else
				d.Anchored = false
				d.CanCollide = false
				d.Massless = true
				if not jointed[d] and d.Parent ~= root then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = root
					weld.Part1 = d
					weld.Parent = d
				end
			end
		end
	end
	local function loadAnim(name)
		local anim = wolf:FindFirstChild(name, true)
		if not (anim and anim:IsA("Animation")) then
			return nil
		end
		local host = wolf:FindFirstChildOfClass("AnimationController")
			or wolf:FindFirstChildOfClass("Humanoid")
		if not host then
			host = Instance.new("AnimationController")
			host.Parent = wolf
		end
		local animator = host:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = host
		end
		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		return ok and track or nil
	end
	walkTrack = loadAnim(AnimationModule.Wolf.Walk)
	if walkTrack then
		walkTrack.Looped = true
		wolf:SetAttribute("WalkTrackReady", true)
	end
	attackTrack = loadAnim(AnimationModule.Wolf.Attack)
	howlTrack = loadAnim(AnimationModule.Wolf.Howl)
	local idleTracks = {}
	local function addIdle(name)
		local track = loadAnim(name)
		if track then
			track.Looped = true
			table.insert(idleTracks, track)
		end
	end
	for _, idleName in ipairs(AnimationModule.Wolf.Idle) do addIdle(idleName) end
	for _, d in ipairs(wolf:GetDescendants()) do
		if d:IsA("Animation") and d.Name:sub(1, 4) == "Idle"
			and d.Name ~= "Idle_1_Anim" and d.Name ~= "Idle_2_Anim"
			and d.Name ~= "Idle_3_Anim" and d.Name ~= "IdleAnim"
		then
			addIdle(d.Name)
		end
	end
	idleTrack = idleTracks[1]
	local biteSound = wolf:FindFirstChild(SoundModule.Wolf.Bite, true)
	if biteSound and biteSound:IsA("Sound") then
		wolf:SetAttribute("BiteSoundReady", true)
		biteSoundFound = biteSound
	end
	wolf:SetAttribute("IsWolf", true)
	local head = wolf:FindFirstChild("Head", true)
	local anchor = (head and head:IsA("BasePart") and head) or root
	local tag = Instance.new("BillboardGui")
	tag.Name = "WolfTag"
	tag.Size = UDim2.fromOffset(150, 34)
	tag.StudsOffset = Vector3.new(0, 2.2, 0)
	tag.AlwaysOnTop = false
	tag.Enabled = false
	tag.Adornee = anchor
	tag.Parent = wolf
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.4
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.Parent = tag
	local record = {
		Model = wolf,
		Root = root,
		WalkTrack = walkTrack,
		AttackTrack = attackTrack,
		HowlTrack = howlTrack,
		IdleTrack = idleTrack,
		IdleTracks = idleTracks,
		Mood = "Wandering",
		MoodTarget = "",
		PlayUntil = 0,
		PlayTurn = 0,
		BiteSound = biteSoundFound,
		Tag = tag,
		TagLabel = label,
		Yaw = math.random() * math.pi * 2,
		WalkCycle = math.random() * 10,
		Think = math.random() * 0.2,
		BiteCd = 0,
		State = "Roam",
		Health = variant.Health or W.MaxHealth,
		MaxHealth = variant.Health or W.MaxHealth,
		Leader = false,
		Variant = variantName,
		Level = variant.Level or 1,
		SpeedMult = variant.SpeedMult or 1,
		Personality = (function()
			local r = math.random()
			if r < 0.35 then return "Cautious" elseif r < 0.7 then return "Aggressive" else return "Curious" end
		end)(),
		BiteDamage = variant.Bite or W.BiteDamage,
		PackIndex = 0,
		PackRole = nil,
		Hunger = 50,
		HungryEat = false,
		RestUntil = 0,
		TamePoints = 0,
		TameTarget = nil,
		Owner = nil,
		PackId = nil,
		Home = Vector3.zero,
		RoamTarget = nil,
		TargetPlayer = nil,
		RefuseUntil = 0,
		EatingUntil = nil,
		SledService = nil,
		SlotIndex = 0,
		AttackWolf = nil,
		AttackUntil = 0,
		HowlUntil = 0,
		NextHowl = 0,
	}
	local pivotY = wolf:GetPivot().Position.Y
	local _, size = wolf:GetBoundingBox()
	local cf = wolf:GetBoundingBox()
	record.GroundOffset = math.max(0.2, pivotY - (cf.Position.Y - size.Y / 2))
	return record
end
function Builder:_placeAt(record, position)
	local groundY = self.Gameplay.World:GroundY(position.X, position.Z)
	local pos = Vector3.new(position.X, groundY + record.GroundOffset, position.Z)
	record.Model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, record.Yaw + W.ModelYawOffset, 0))
	record.Model.Parent = self.Folder
end
return Builder
