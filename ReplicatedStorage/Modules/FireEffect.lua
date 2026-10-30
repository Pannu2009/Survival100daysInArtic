local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FireEffect = {}
function FireEffect.AttachFire(parent)
	local utils = ReplicatedStorage:FindFirstChild("utils")
	local template = utils and utils:FindFirstChild("Fire")
	if not template then
		return {}
	end
	local clones = {}
	if template:IsA("ParticleEmitter") then
		local clone = template:Clone()
		clone.Enabled = false
		clone.Parent = parent
		table.insert(clones, clone)
	else
		for _, emitter in ipairs(template:GetDescendants()) do
			if emitter:IsA("ParticleEmitter") then
				local clone = emitter:Clone()
				clone.Enabled = false
				clone.Parent = parent
				table.insert(clones, clone)
			end
		end
	end
	return clones
end
return FireEffect
