local npc = script.Parent
local humanoid = npc:FindFirstChildOfClass("Humanoid")
local TweenService = game:GetService("TweenService")

local function fadeAndDestroy()
	wait(2) -- Wait 2 seconds after death

	for _, part in ipairs(npc:GetDescendants()) do
		if part:IsA("BasePart") then
			local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			local goal = {Transparency = 1}
			local tween = TweenService:Create(part, tweenInfo, goal)
			tween:Play()
		end
	end

	wait(1.1) -- Give it time to finish tweening
	npc:Destroy()
end

humanoid.Died:Connect(fadeAndDestroy)
