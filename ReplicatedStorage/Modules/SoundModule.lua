local SoundModule = {}
SoundModule.Wolf = {
	Bite = "damage",
}
SoundModule.Player = {
	Cough = "Cough",
}
SoundModule.Sled = {
	Roll = "",
}
function SoundModule.PlayService(name, looped)
	local RunService = game:GetService("RunService")
	if not RunService:IsClient() then
		return nil
	end
	local SoundService = game:GetService("SoundService")
	local Players = game:GetService("Players")
	local original = SoundService:FindFirstChild(name)
	if not original then
		local folder = SoundService:FindFirstChild("Folder")
		if folder then
			original = folder:FindFirstChild(name)
		end
	end
	if not (original and original:IsA("Sound")) then
		return nil
	end
	local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return nil
	end
	local clone = original:Clone()
	clone.Looped = looped == true
	clone.Parent = playerGui
	clone:Play()
	if not looped then
		clone.Ended:Connect(function()
			clone:Destroy()
		end)
	end
	return clone
end
function SoundModule.Play(sound)
	if sound and sound:IsA("Sound") then
		pcall(function()
			sound:Play()
		end)
		return true
	end
	return false
end
function SoundModule.FindSound(model, name)
	if not model or not name or name == "" then
		return nil
	end
	local sound = model:FindFirstChild(name, true)
	if sound and sound:IsA("Sound") then
		return sound
	end
	return nil
end
return SoundModule
