-- AnimationModule: every animation NAME the game uses, in one
-- place. Split out of Config (Config.Animations now points
-- here, it does not own the data). Animations themselves
-- still live in Ajay's models; this module only centralises
-- the names + a safe Load helper, so a rename touches one file.
local AnimationModule = {}

AnimationModule.Wolf = {
	Walk = "WalkAnim",
	Howl = "HowlAnim", -- Ajay added this to WolfModel, 2026-10-29
	Attack = "AttackAnim",
	-- Idle is a ROTATION, not one clip: every Idle* animation
	-- in the model joins the play set (see Animals).
	Idle = { "Idle_1_Anim", "Idle_2_Anim", "Idle_3_Anim", "IdleAnim" },
}

AnimationModule.Player = {
	Chop = "",
	Carry = "",
	Sleep = "",
	Shiver = "",
}

-- Load an Animation by name from a model, if present.
-- Returns the track, or nil (missing animation is never an error).
function AnimationModule.Load(model, name)
	if not model or not name or name == "" then
		return nil
	end
	local anim = model:FindFirstChild(name, true)
	if not (anim and anim:IsA("Animation")) then
		return nil
	end
	local host = model:FindFirstChildOfClass("AnimationController")
		or model:FindFirstChildOfClass("Humanoid")
	if not host then
		host = Instance.new("AnimationController")
		host.Parent = model
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

return AnimationModule
