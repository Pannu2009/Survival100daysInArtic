local AnimationModule = {}
AnimationModule.Wolf = {
	Walk = "WalkAnim",
	Howl = "HowlAnim",
	Attack = "AttackAnim",
	Idle = { "Idle_1_Anim", "Idle_2_Anim", "Idle_3_Anim", "IdleAnim" },
}
AnimationModule.Player = {
	Chop = "",
	Carry = "",
	Sleep = "",
	Shiver = "",
}
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
