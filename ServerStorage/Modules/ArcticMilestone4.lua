local M = {}
local C = {
	red = Color3.fromRGB(132, 42, 39), redDark = Color3.fromRGB(83, 35, 34),
	metal = Color3.fromRGB(91, 108, 120), trim = Color3.fromRGB(164, 179, 190),
	snow = Color3.fromRGB(224, 235, 243), glass = Color3.fromRGB(104, 177, 207),
	dark = Color3.fromRGB(18, 34, 46), screen = Color3.fromRGB(45, 125, 151),
	warm = Color3.fromRGB(255, 183, 91), wood = Color3.fromRGB(91, 72, 57),
}
local function part(parent, name, size, cf, color, material, collide)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	p.Color, p.Material = color, material or Enum.Material.Metal
	p.Anchored = true
	p.CanCollide = collide ~= false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = color, range, brightness
	l.Shadows = true
	l.Parent = parent
end
local function sign(parent, text, cf, size)
	local p = part(parent, "FacilitySign", Vector3.new(0.25, size.Y, size.X), cf, C.dark, Enum.Material.Metal, false)
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.SizingMode, gui.PixelsPerStud = Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, 45
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1,1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = C.snow
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = gui
	return p
end
local function room(root, name, x, y, z, sx, sz)
	local m = Instance.new("Model"); m.Name = name; m.Parent = root
	part(m,"Floor",Vector3.new(sx,.7,sz),CFrame.new(x,y+.35,z),C.metal,Enum.Material.DiamondPlate)
	part(m,"BackWall",Vector3.new(sx,10,.7),CFrame.new(x,y+5,z-sz/2),C.redDark)
	part(m,"LeftWall",Vector3.new(.7,10,sz),CFrame.new(x-sx/2,y+5,z),C.red)
	part(m,"RightWall",Vector3.new(.7,10,sz),CFrame.new(x+sx/2,y+5,z),C.red)
	part(m,"FrontLeft",Vector3.new(sx*.36,10,.7),CFrame.new(x-sx*.32,y+5,z+sz/2),C.red)
	part(m,"FrontRight",Vector3.new(sx*.36,10,.7),CFrame.new(x+sx*.32,y+5,z+sz/2),C.red)
	part(m,"FrontLintel",Vector3.new(sx*.28,2,.7),CFrame.new(x,y+9,z+sz/2),C.red)
	part(m,"Ceiling",Vector3.new(sx,.5,sz),CFrame.new(x,y+10,z),C.metal)
	part(m,"SnowRoof",Vector3.new(sx+1,.35,sz+1),CFrame.new(x,y+10.45,z),C.snow,Enum.Material.Snow,false)
	return m
end
local function console(parent, x,y,z, labelText)
	local desk = part(parent,"ControlDesk",Vector3.new(7,2,2),CFrame.new(x,y+1,z),C.metal,Enum.Material.Metal)
	local panel = part(parent,"TerminalScreen",Vector3.new(5,2.6,.25),CFrame.new(x,y+3,z-.75),C.screen,Enum.Material.Neon,false)
	panel.CanTouch = false
	local gui = Instance.new("SurfaceGui"); gui.Face=Enum.NormalId.Front; gui.Parent=panel
	local label=Instance.new("TextLabel"); label.Size=UDim2.fromScale(1,1); label.BackgroundTransparency=1
	label.Text=labelText; label.TextColor3=Color3.new(1,1,1); label.Font=Enum.Font.GothamBold; label.TextScaled=true; label.Parent=gui
	light(panel,C.glass,8,.35)
	return desk
end
local function lamp(root,x,y,z)
	local pole=part(root,"PathLamp",Vector3.new(.35,5,.35),CFrame.new(x,y+2.5,z),C.trim)
	local head=part(root,"PathLampHead",Vector3.new(1.1,.3,1.1),CFrame.new(x,y+5,z),C.warm,Enum.Material.Neon,false)
	light(head,C.warm,15,.8)
end
function M.Build(layout, groundY)
	assert(type(layout)=="table" and type(groundY)=="function","layout and groundY required")
	local lm
	for _,v in ipairs(layout.Landmarks or {}) do if v.Id=="ResearchOutpost" then lm=v break end end
	if not lm then warn("[ArcticMilestone4] ResearchOutpost landmark missing"); return nil end
	local x,z=lm.Position.X,lm.Position.Z
	local ok,y=pcall(groundY,x+78,z+5); if not ok or type(y)~="number" then y=0 end
	local old=workspace:FindFirstChild("ArcticMilestone4"); if old then old:Destroy() end
	local root=Instance.new("Folder"); root.Name="ArcticMilestone4"; root.Parent=workspace

	local lab=room(root,"ResearchAnnex",x+78,y,z+5,38,30)
	sign(lab,"NORTH / ARCTIC RESEARCH",CFrame.new(x+78,y+7,z+20.4)*CFrame.Angles(0,math.rad(180),0),Vector2.new(18,3))

	part(lab,"LabPartition",Vector3.new(.5,8,18),CFrame.new(x+78,y+4,z+1),C.trim)
	part(lab,"PartitionDoorHeader",Vector3.new(.5,2,5),CFrame.new(x+78,y+9,z+1),C.trim)
	console(lab,x+69,y+.7,z-4,"WEATHER / BAROMETER")
	console(lab,x+87,y+.7,z-4,"RADAR / SIGNAL")
	part(lab,"LabBench",Vector3.new(12,1.4,3),CFrame.new(x+69,y+1.4,z+9),C.wood,Enum.Material.WoodPlanks)
	for i=0,3 do
		local vial=part(lab,"SampleCanister",Vector3.new(.65,2.2,.65),CFrame.new(x+65+i*2.2,y+3,z+9),i%2==0 and C.glass or C.warm,Enum.Material.Glass,false)
		vial.Transparency=.18
	end
	part(lab,"BunkFrame",Vector3.new(8,.7,3),CFrame.new(x+88,y+1.2,z+8),C.metal)
	part(lab,"BunkMattress",Vector3.new(7,.45,2.6),CFrame.new(x+88,y+1.75,z+8),C.snow,Enum.Material.Fabric,false)
	part(lab,"LockerBank",Vector3.new(2,6,9),CFrame.new(x+94,y+3,z+2),C.red,Enum.Material.Metal)
	for i=0,2 do
		part(lab,"LockerDoor",Vector3.new(.12,5.6,2.7),CFrame.new(x+92.9,y+3,z-1+i*3),C.trim,Enum.Material.Metal,false)
	end
	for _,p in ipairs({Vector3.new(x+68,y+9.4,z+2),Vector3.new(x+88,y+9.4,z+2),Vector3.new(x+78,y+9.4,z-10)}) do
		local fixture=part(lab,"CeilingLight",Vector3.new(5,.2,.8),CFrame.new(p),C.warm,Enum.Material.Neon,false)
		light(fixture,C.warm,13,.55)
	end

	local gy=y
	part(root,"GeneratorPad",Vector3.new(16,.7,11),CFrame.new(x+110,gy+.35,z+20),C.metal,Enum.Material.Concrete)
	local gen=part(root,"BackupGenerator",Vector3.new(10,5,5),CFrame.new(x+110,gy+3.2,z+20),C.redDark)
	for i=-2,2 do part(root,"GeneratorVent",Vector3.new(.25,3,.7),CFrame.new(x+105+i*1.7,gy+3.2,z+17.35),C.trim,Enum.Material.Metal,false) end
	light(gen,C.warm,7,.2)
	for i=0,1 do
		part(root,"FuelTank",Vector3.new(4,7,4),CFrame.new(x+103+i*7,gy+3.5,z+31),C.metal,Enum.Material.Metal)
		part(root,"TankTop",Vector3.new(4.3,.4,4.3),CFrame.new(x+103+i*7,gy+7.2,z+31),C.snow,Enum.Material.Metal)
	end
	part(root,"CableTray",Vector3.new(32,.35,.6),CFrame.new(x+95,gy+5,z+20),C.trim,Enum.Material.Metal,false)
	for dx=0,32,8 do part(root,"CableSupport",Vector3.new(.3,4,.3),CFrame.new(x+79+dx,gy+2.5,z+20),C.metal) end

	for i=0,7 do
		local fx=x+52+i*12
		if i~=3 and i~=4 then
			part(root,"FencePost",Vector3.new(.55,4,.55),CFrame.new(fx,gy+2,z+39),C.trim)
		end
	end
	part(root,"FenceRail",Vector3.new(96,.25,.25),CFrame.new(x+94,gy+3.2,z+39),C.trim,Enum.Material.Metal,false)
	part(root,"FenceRail",Vector3.new(96,.25,.25),CFrame.new(x+94,gy+1.5,z+39),C.trim,Enum.Material.Metal,false)
	for i=0,4 do lamp(root,x+42+i*18,groundY(x+42+i*18,z+46),z+46) end

	root:SetAttribute("Facility","NorthernResearchOutpost")
	root:SetAttribute("WorldSeed",tostring(layout.SeedString or "unknown"))
	print("[ArcticMilestone4] Research annex and utility yard built")
	return root
end
return M
