local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local TrackMarks = require(script.Parent.Parent:WaitForChild("TrackMarks"))
local Navigation = {}
local W = Config.Wolves
function Navigation:_pushOutOfFire(position)
	local x, z = position.X, position.Z
	for _, fire in ipairs(self.Gameplay.World.Fires or {}) do
		if fire.Lit and fire.Fuel > 0 then
			local anchor = fire.CookingPart or fire.Core
			if anchor then
				local radius = W.FireScareRadius + 1
				local dx = x - anchor.Position.X
				local dz = z - anchor.Position.Z
				local d2 = dx * dx + dz * dz
				if d2 < radius * radius then
					local d = math.sqrt(d2)
					if d < 0.01 then
						dx, dz, d = 1, 0, 1
					end
					x = anchor.Position.X + dx / d * radius
					z = anchor.Position.Z + dz / d * radius
				end
			end
		end
	end
	return Vector3.new(x, position.Y, z)
end
function Navigation:_computePath(from, to)
	local path = PathfindingService:CreatePath({
		AgentRadius = 1.2,
		AgentHeight = 3,
		AgentCanJump = true,
		AgentCanClimb = false,
	})
	local ok = pcall(function()
		path:ComputeAsync(from, to)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return nil
	end
	local points = {}
	for _, waypoint in ipairs(path:GetWaypoints()) do
		table.insert(points, self:_pushOutOfFire(waypoint.Position))
	end
	if #points < 2 then
		return nil
	end
	return points
end
function Navigation:_safeRetreat(wolf, threatPos)
	local pos = wolf.Root.Position
	local away = Vector3.new(pos.X - threatPos.X, 0, pos.Z - threatPos.Z)
	if away.Magnitude < 0.1 then
		away = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
	end
	away = away.Unit
	local dist = W.RetreatDistance or 20
	for _, angle in ipairs({ 0, 60, -60, 120, -120 }) do
		local rad = math.rad(angle)
		local dir = Vector3.new(away.X * math.cos(rad) - away.Z * math.sin(rad), 0, away.X * math.sin(rad) + away.Z * math.cos(rad))
		local candidate = self:_pushOutOfFire(pos + dir * dist)
		if not self:_shelteredByFire(candidate) then
			return candidate
		end
	end
	return self:_pushOutOfFire(pos + away * dist)
end
function Navigation:_moveSmart(wolf, targetPos, speed, dt)
	local pos = wolf.Root.Position
	local targetDist = (Vector3.new(targetPos.X, 0, targetPos.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
	local now = os.clock()
	if wolf.RecoverTarget and now < (wolf.RecoverUntil or 0) then
		self:_moveToward(wolf, wolf.RecoverTarget, speed, dt)
		return targetDist
	end
	wolf.RecoverTarget = nil
	if speed <= 0 then
		wolf.StuckCheckAt = nil
	end
	if speed > 0 and targetDist > 3 then
		if not wolf.StuckCheckAt then
			wolf.StuckCheckAt = now
			wolf.StuckCheckPos = pos
		elseif now - wolf.StuckCheckAt >= (W.StuckSeconds or 2) then
			if (pos - wolf.StuckCheckPos).Magnitude < (W.StuckMoveMin or 0.5) then
				wolf.Path = nil
				local dir = Vector3.new(targetPos.X - pos.X, 0, targetPos.Z - pos.Z)
				if dir.Magnitude < 0.1 then dir = Vector3.new(1, 0, 0) end
				dir = dir.Unit
				local side = math.random() < 0.5 and 1 or -1
				wolf.RecoverTarget = self:_pushOutOfFire(pos + Vector3.new(-dir.Z * side * 6, 0, dir.X * side * 6))
				wolf.RecoverUntil = now + (W.RecoverSeconds or 2)
				wolf.StuckCheckAt = now
				wolf.StuckCheckPos = pos
				self:_moveToward(wolf, wolf.RecoverTarget, speed, dt)
				return targetDist
			end
			wolf.StuckCheckAt = now
			wolf.StuckCheckPos = pos
		end
	end
	if targetDist < 8 then
		wolf.Path = nil
		self:_moveToward(wolf, targetPos, speed, dt)
		return targetDist
	end
	if now < (wolf.PathFailUntil or 0) then
		self:_moveToward(wolf, targetPos, speed, dt)
		return targetDist
	end
	local path = wolf.Path
	if not path or (path.TargetPos - targetPos).Magnitude > 8 or now > path.ExpiresAt then
		local points = self:_computePath(pos, targetPos)
		if points then
			wolf.Path = { Points = points, Index = 2, TargetPos = targetPos, ExpiresAt = now + 5 }
			path = wolf.Path
			wolf.PathFailCount = 0
		else
			wolf.Path = nil
			path = nil
			wolf.PathFailCount = (wolf.PathFailCount or 0) + 1
			wolf.PathFailUntil = now + math.min(1.5 * wolf.PathFailCount, W.PathFailBackoffMax or 6)
		end
	end
	if not path then
		self:_moveToward(wolf, targetPos, speed, dt)
		return targetDist
	end
	while path.Index <= #path.Points do
		local wp = path.Points[path.Index]
		local dx = wp.X - pos.X
		local dz = wp.Z - pos.Z
		if dx * dx + dz * dz < 2.6 then
			path.Index += 1
		else
			break
		end
	end
	if path.Index > #path.Points then
		wolf.Path = nil
		self:_moveToward(wolf, targetPos, speed, dt)
	else
		self:_moveToward(wolf, path.Points[path.Index], speed, dt)
	end
	return targetDist
end
function Navigation:_moveToward(wolf, targetPos, speed, dt)
	local weather = self.Gameplay.Temperature and self.Gameplay.Temperature:GetWeather()
	if weather == "Blizzard" then speed = speed * 0.75 end
	if weather == "Storm" then speed = speed * 0.9 end
	if (wolf.Hunger or 50) <= 0 then speed = speed * 0.85 end
	local pos = wolf.Root.Position
	local to = Vector3.new(targetPos.X - pos.X, 0, targetPos.Z - pos.Z)
	local dist = to.Magnitude
	local moving = false
	if dist > 0.35 then
		local dir = to / dist
		wolf.Yaw = yawLerp(wolf.Yaw, yawOf(dir), dt * 7)
		local step = math.min(speed * dt, dist)
		pos = Vector3.new(pos.X + dir.X * step, pos.Y, pos.Z + dir.Z * step)
		moving = true
		wolf.WalkCycle += dt * speed * 0.9
	end
	local howling = os.clock() < wolf.HowlUntil
	if howling then
		if wolf.WalkTrack and wolf.WalkTrack.IsPlaying then
			wolf.WalkTrack:Stop(0.15)
		end
		if wolf.IdleTrack and wolf.IdleTrack.IsPlaying then
			wolf.IdleTrack:Stop(0.15)
		end
		if wolf.HowlTrack and not wolf.HowlTrack.IsPlaying then
			wolf.HowlTrack:Play(0.1)
		end
	else
		if wolf.WalkTrack then
			if moving and not wolf.WalkTrack.IsPlaying then
				wolf.WalkTrack:Play(0.15)
			elseif not moving and wolf.WalkTrack.IsPlaying then
				wolf.WalkTrack:Stop(0.2)
			end
		end
		if wolf.IdleTrack then
			if not moving and not wolf.IdleTrack.IsPlaying then
				wolf.IdleTrack:Play(0.25)
			elseif moving and wolf.IdleTrack.IsPlaying then
				wolf.IdleTrack:Stop(0.15)
			end
		end
	end
	if moving then
		wolf.MarkAcc = (wolf.MarkAcc or 0) + speed * dt
		if wolf.MarkAcc >= 2.2 then
			wolf.MarkAcc = 0
			wolf.MarkSide = -(wolf.MarkSide or 1)
			local right = Vector3.new(math.cos(wolf.Yaw), 0, -math.sin(wolf.Yaw))
			local paw = Vector3.new(pos.X, pos.Y, pos.Z) + right * (0.35 * wolf.MarkSide)
			TrackMarks.SpawnPaw(paw, wolf.Yaw, 10)
		end
	end
	local groundY = self.Gameplay.World:GroundY(pos.X, pos.Z)
	local bob = moving and math.sin(wolf.WalkCycle * 2) * 0.07 or 0
	local y = groundY + wolf.GroundOffset + bob
	wolf.Model:PivotTo(CFrame.new(Vector3.new(pos.X, y, pos.Z)) * CFrame.Angles(0, wolf.Yaw + W.ModelYawOffset, 0))
	return dist
end
return Navigation
