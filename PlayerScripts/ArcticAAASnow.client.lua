local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local camera=Workspace.CurrentCamera
local holder=Instance.new("Part")
holder.Name="LocalArcticSnowFX" holder.Anchored=true holder.Transparency=1 holder.Size=Vector3.one
holder.CanCollide=false holder.CanTouch=false holder.CanQuery=false holder.CastShadow=false holder.Parent=Workspace
local attachment=Instance.new("Attachment") attachment.Parent=holder
local emitter=Instance.new("ParticleEmitter") emitter.Name="ArcticSnowMotes"
emitter.Texture="rbxasset://textures/particles/sparkles_main.dds"
emitter.Rate=18 emitter.Lifetime=NumberRange.new(3.5,6) emitter.Speed=NumberRange.new(3,7)
emitter.Acceleration=Vector3.new(0,-2,0) emitter.SpreadAngle=Vector2.new(180,180)
emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.08),NumberSequenceKeypoint.new(1,.025)})
emitter.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.18),NumberSequenceKeypoint.new(1,.72)})
emitter.LightInfluence=.15 emitter.Parent=attachment
local conn=RunService.RenderStepped:Connect(function()
 camera=Workspace.CurrentCamera
 if camera then holder.CFrame=CFrame.new(camera.CFrame.Position+Vector3.new(0,12,0)) end
 local state=string.lower(tostring(ReplicatedStorage:GetAttribute("ArcticEvent") or Workspace:GetAttribute("ArcticEvent") or "").." "..tostring(ReplicatedStorage:GetAttribute("Weather") or Workspace:GetAttribute("Weather") or ""))
 emitter.Rate=(string.find(state,"whiteout",1,true) or string.find(state,"blizzard",1,true)) and 42 or 18
end)
script.Destroying:Connect(function() conn:Disconnect() holder:Destroy() end)
