-- SoundModule: every sound NAME the game uses, in one place.
-- Split out of Config so sound data is not buried in the
-- big config table. Sounds themselves still live in Ajay's
-- models (a wolf's "damage" sound, a "Cough" sound in a head);
-- this module only centralises the names + a safe Play helper.
local SoundModule = {}

SoundModule.Wolf = {
	Bite = "damage",
}

SoundModule.Player = {
	Cough = "Cough",
}

SoundModule.Sled = {
	-- No sled sound asset yet; empty means "no sound", not a bug.
	Roll = "",
}

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
