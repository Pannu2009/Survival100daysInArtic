local ScriptsFolder = script.Parent
local Tool = ScriptsFolder.Parent
	local EffectsHolder = Tool:WaitForChild("EffectsHolder")
	local Handle = Tool:WaitForChild("Handle")
	local Sparker = Tool:WaitForChild("Sparker")

local LidsFolder = Tool:WaitForChild("Lids")
	local ClosedLid = LidsFolder:WaitForChild("ClosedLid")
	local OpenedLid = LidsFolder:WaitForChild("OpenedLid")

local Opened = Tool:WaitForChild("Opened")

local TweenService = game:GetService("TweenService")

for i, light in pairs(EffectsHolder.AttachOn:GetChildren()) do
	if light.ClassName == "PointLight" then
		local OriginalValue = Instance.new("NumberValue", light)
		OriginalValue.Value = light.Range
		OriginalValue.Name = "OriginalValue"
		
		wait()
		
		light.Range = 0
	end
end

Tool.Activated:Connect(function()
	if Opened.Value == false then
		for i, light in pairs(EffectsHolder.AttachOn:GetChildren()) do
			if light.ClassName == "PointLight" then
				light.Range = 0
			end
		end
		
		Opened.Value = true
		
		Handle.sound_open:Play()
		
		ClosedLid.Transparency = 1
		OpenedLid.Transparency = 0
		
		for i, particle in pairs(EffectsHolder.AttachOn:GetChildren()) do
			if particle.ClassName == "ParticleEmitter" then
				particle.Enabled = true
			end
		end
		
		for i, light in pairs(EffectsHolder.AttachOn:GetChildren()) do
			if light.ClassName == "PointLight" then
				local OriginalValue = light:FindFirstChild("OriginalValue")
				TweenService:Create(light, TweenInfo.new(0.5), {Range = OriginalValue.Value}):Play()
			end
		end
		
	else
		Opened.Value = false
		
		Handle.sound_close:Play()
		
		ClosedLid.Transparency = 0
		OpenedLid.Transparency = 1
		
		for i, particle in pairs(EffectsHolder.AttachOn:GetChildren()) do
			if particle.ClassName == "ParticleEmitter" then
				particle.Enabled = false
			end
		end
		
		for i, light in pairs(EffectsHolder.AttachOn:GetChildren()) do
			if light.ClassName == "PointLight" then
				local OriginalValue = light:FindFirstChild("OriginalValue")
				TweenService:Create(light, TweenInfo.new(0.5), {Range = 0}):Play()
			end
		end
	end
end)