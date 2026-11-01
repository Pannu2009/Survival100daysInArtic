local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local caps = {
	WindSnowVolume = isTouch and 55 or 190,
	SnowKick = isTouch and 12 or 45,
}
local function tune(instance)
	if not instance:IsA("ParticleEmitter") then return end
	local parent = instance.Parent
	local rootName = parent and parent.Name
	if rootName == "WindSnowVolume" or instance.Name == "BlowingSnow" then
		instance.Rate = math.min(instance.Rate, caps.WindSnowVolume)
	elseif instance.Name == "SnowKick" then
		instance.Rate = math.min(instance.Rate, caps.SnowKick)
	end
end
for _, item in ipairs(Workspace:GetDescendants()) do tune(item) end
Workspace.DescendantAdded:Connect(function(item)
	if item:IsA("ParticleEmitter") then task.defer(tune, item) end
end)
print("[Arctic] Milestone 7 client visual budget active; touch device:", isTouch)
