-- FireEffect: Ajay's fire emitter, from Studio (NOT in this repo):
--   ReplicatedStorage.utils.Fire
-- AttachFire(parent) clones that emitter (or every emitter
-- inside it, if Fire is a Model/Part holding emitters) onto
-- parent, disabled, and returns the list of clones. Callers
-- enable/disable them with the fire state, the same way
-- _refreshFireVisual already toggles campfire emitters.
-- If utils.Fire is missing, returns an empty list -- callers
-- fall back to the legacy Fire object, so the game still
-- works in a repo-only test without Ajay's Studio asset.
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
