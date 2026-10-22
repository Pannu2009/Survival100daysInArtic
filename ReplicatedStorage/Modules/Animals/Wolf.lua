local Figure = script.Parent -- whatever path
local HumanoidRootPart = Figure:WaitForChild("HumanoidRootPart")
local Humanoid = Figure:WaitForChild("Humanoid")
local Animator = Humanoid:WaitForChild("Animator")

local walkAnim = Instance.new("Animation")
walkAnim.AnimationId = "rbxassetid://89469722269972" -- your walking anim ID
local walkTrack = Animator:LoadAnimation(walkAnim)

-- SETTINGS
local walkSpeed = 24
local aggroDistance = 15
local wanderRange = 30
local attackDistance = 5
local attackDamage = 15
local attackCooldown = 2

Humanoid.WalkSpeed = walkSpeed

local isAgro = false
local agroTarget = nil


game:GetService("RunService").Heartbeat:Connect(function()
	local vel = HumanoidRootPart.Velocity
	local moving = Vector3.new(vel.X, 0, vel.Z).Magnitude > 1
	if moving and not walkTrack.IsPlaying then
		walkTrack:Play()
	elseif not moving and walkTrack.IsPlaying then
		walkTrack:Stop()
	end
end)


Humanoid.HealthChanged:Connect(function(health)
	if health < Humanoid.MaxHealth and not isAgro then
		for _, player in pairs(game:GetService("Players"):GetPlayers()) do
			if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				local dist = (player.Character.HumanoidRootPart.Position - HumanoidRootPart.Position).Magnitude
				if dist <= 50 then
					isAgro = true
					agroTarget = player
					break
				end
			end
		end
	end
end)


local function getClosestPlayer()
	local closest = nil
	local shortestDist = aggroDistance
	for _, player in pairs(game:GetService("Players"):GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local dist = (player.Character.HumanoidRootPart.Position - HumanoidRootPart.Position).Magnitude
			if dist <= shortestDist then
				closest = player
				shortestDist = dist
			end
		end
	end
	return closest
end


while true do
	wait(0)

	
	local playerNearby = getClosestPlayer()
	if playerNearby and not isAgro then
		isAgro = true
		agroTarget = playerNearby
	end

	
	if isAgro and agroTarget and agroTarget.Character and agroTarget.Character:FindFirstChild("HumanoidRootPart") then
		local targetHRP = agroTarget.Character.HumanoidRootPart
		local targetHumanoid = agroTarget.Character:FindFirstChild("Humanoid")
		local targetPos = targetHRP.Position
		local distToTarget = (targetHRP.Position - HumanoidRootPart.Position).Magnitude

	
		if distToTarget <= attackDistance then
			if targetHumanoid and not targetHumanoid:GetAttribute("RecentlyBit") then
				targetHumanoid:TakeDamage(attackDamage)

				
				local sound = Figure:FindFirstChild("damage")
				if sound and sound:IsA("Sound") then
					sound:Play()
				end

			
				targetHumanoid:SetAttribute("RecentlyBit", true)
				task.delay(attackCooldown, function()
					if targetHumanoid then
						targetHumanoid:SetAttribute("RecentlyBit", false)
					end
				end)
			end
		end

		
		if Humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
			if math.random(1, 1000) == 1 then
				Humanoid.Jump = true
			end
		end

		Humanoid:MoveTo(targetPos)

	else
	
		isAgro = false
		agroTarget = nil

		local randomOffset = Vector3.new(math.random(-wanderRange, wanderRange), 0, math.random(-wanderRange, wanderRange))
		local targetPos = HumanoidRootPart.Position + randomOffset

		Humanoid:MoveTo(targetPos)
		Humanoid.MoveToFinished:Wait()

		
		wait(math.random(1, 3))
	end
end
