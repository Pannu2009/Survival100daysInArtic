local npc = script.Parent
local humanoid = npc:WaitForChild("Humanoid")
local rootPart = npc:FindFirstChild("HumanoidRootPart")

local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ragdollGroup = "NPCRagdoll"

pcall(function()
	PhysicsService:CreateCollisionGroup(ragdollGroup)
end)

PhysicsService:CollisionGroupSetCollidable(ragdollGroup, ragdollGroup, false)

for _, part in ipairs(workspace:GetDescendants()) do
	if part:IsA("BasePart") and part.Name == "Ground" then
		PhysicsService:SetPartCollisionGroup(part, "Default")
	end
end

local ragdolled = false
local jointsBackup = {}

local function disableTouchOnParts()
	for _, part in npc:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanTouch = false
		end
	end
end

local function enableRagdoll()
	if ragdolled then return end
	ragdolled = true

	for _, joint in pairs(npc:GetDescendants()) do
		if joint:IsA("Motor6D") then
			local socket = Instance.new("BallSocketConstraint")
			local a1 = Instance.new("Attachment")
			local a2 = Instance.new("Attachment")

			a1.CFrame = joint.C0
			a2.CFrame = joint.C1

			a1.Parent = joint.Part0
			a2.Parent = joint.Part1

			socket.Attachment0 = a1
			socket.Attachment1 = a2
			socket.Parent = joint.Parent

			socket.LimitsEnabled = true
			socket.TwistLimitsEnabled = true

			table.insert(jointsBackup, {Part0 = joint.Part0, Part1 = joint.Part1, Name = joint.Name, C0 = joint.C0, C1 = joint.C1})
			joint:Destroy()
		end
	end

	for _, part in pairs(npc:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			PhysicsService:SetPartCollisionGroup(part, ragdollGroup)
		end
	end

	disableTouchOnParts()
end

local function disableRagdoll()
	if not ragdolled then return end
	ragdolled = false

	for _, part in pairs(npc:GetDescendants()) do
		if part:IsA("BallSocketConstraint") then
			part:Destroy()
		end
	end

	for _, attach in pairs(npc:GetDescendants()) do
		if attach:IsA("Attachment") then
			attach:Destroy()
		end
	end

	for _, jointData in ipairs(jointsBackup) do
		local newJoint = Instance.new("Motor6D")
		newJoint.Name = jointData.Name
		newJoint.Part0 = jointData.Part0
		newJoint.Part1 = jointData.Part1
		newJoint.C0 = jointData.C0
		newJoint.C1 = jointData.C1
		newJoint.Parent = jointData.Part0
	end

	jointsBackup = {}

	for _, part in pairs(npc:GetDescendants()) do
		if part:IsA("BasePart") then
			PhysicsService:SetPartCollisionGroup(part, "Default")
		end
	end

	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
end

local touchedCooldown = false
local function setupTouchReset()
	for _, part in pairs(npc:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Touched:Connect(function(hit)
				if not ragdolled or touchedCooldown or humanoid.Health <= 0 then return end
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player then
					touchedCooldown = true
					task.delay(3, function()
						disableRagdoll()
						humanoid:MoveTo(rootPart.Position)
						touchedCooldown = false
					end)
				end
			end)
		end
	end
end

humanoid.BreakJointsOnDeath = false

humanoid.Died:Connect(function()
	enableRagdoll()
	setupTouchReset()
end)
