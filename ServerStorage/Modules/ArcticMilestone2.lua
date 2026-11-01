local M = {}
local C = {
    snow = Color3.fromRGB(226,235,243), ice = Color3.fromRGB(111,177,211),
    deepIce = Color3.fromRGB(54,116,157), rock = Color3.fromRGB(83,98,111),
    red = Color3.fromRGB(142,43,39), redDark = Color3.fromRGB(91,32,31),
    metal = Color3.fromRGB(92,108,120), lightMetal = Color3.fromRGB(157,171,181),
    wood = Color3.fromRGB(91,72,57), darkWood = Color3.fromRGB(55,47,42),
    warm = Color3.fromRGB(255,181,89),
}
local function make(parent, name, size, cf, color, material, shape)
    local p = Instance.new("Part")
    p.Name, p.Size, p.CFrame = name, size, cf
    p.Color, p.Material = color, material or Enum.Material.Metal
    p.Anchored, p.TopSurface, p.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    if shape then p.Shape = shape end
    p.Parent = parent
    return p
end
local function group(parent, name)
    local m = Instance.new("Model")
    m.Name, m.Parent = name, parent
    return m
end
local function lamp(parent, x, y, z)
    make(parent,"LampPost",Vector3.new(.35,7,.35),CFrame.new(x,y+3.5,z),C.metal,Enum.Material.Metal)
    local h = make(parent,"LampHead",Vector3.new(1.2,.35,1.2),CFrame.new(x,y+7,z),C.warm,Enum.Material.Neon)
    local l = Instance.new("PointLight")
    l.Color, l.Brightness, l.Range, l.Shadows = C.warm, 1.2, 18, true
    l.Parent = h
end
local function outpost(root,p)
    local m=group(root,"NorthernResearchOutpost")
    local x,y,z=p.X,p.Y,p.Z
    local blocks={
        {"MainLaboratory",Vector3.new(0,0,0),Vector3.new(34,15,25)},
        {"HabitatBlock",Vector3.new(-28,0,8),Vector3.new(22,12,20)},
        {"PowerAndComms",Vector3.new(27,0,-10),Vector3.new(18,11,18)},
    }
    for _,b in ipairs(blocks) do
        local s,o=b[3],b[2]
        local center=Vector3.new(x,y+s.Y/2,z)+o
        make(m,b[1],s,CFrame.new(center),C.red,Enum.Material.Metal)
        make(m,b[1].."_SnowRoof",Vector3.new(s.X+1,.8,s.Z+1),CFrame.new(center+Vector3.new(0,s.Y/2+.4,0)),C.snow,Enum.Material.Snow)
        for side=-1,1,2 do
            local w=make(m,"Window",Vector3.new(.18,3.2,4.5),CFrame.new(center+Vector3.new(side*(s.X/2+.1),1,0)),Color3.fromRGB(104,178,205),Enum.Material.Glass)
            w.Transparency=.25; w.CanCollide=false
        end
    end
    local walk=make(m,"RaisedWalkway",Vector3.new(34,.7,4),CFrame.new(x-10,y+4.2,z+15),C.metal,Enum.Material.DiamondPlate)
    for dx=-25,5,10 do make(m,"WalkwaySupport",Vector3.new(.55,4,.55),CFrame.new(x+dx,y+2,z+15),C.metal,Enum.Material.Metal) end
    for _,side in ipairs({-1,1}) do
        make(m,"WalkwayRail",Vector3.new(34,.25,.25),walk.CFrame*CFrame.new(0,1.1,side*1.8),C.lightMetal,Enum.Material.Metal)
    end
    make(m,"RadarBase",Vector3.new(8,2,8),CFrame.new(x+40,y+1,z-23),C.metal)
    local dome=make(m,"RadarDome",Vector3.new(8,5,8),CFrame.new(x+40,y+4.5,z-23),Color3.fromRGB(219,229,235),Enum.Material.SmoothPlastic,Enum.PartType.Ball)
    dome.CanCollide=false
    make(m,"RadarMast",Vector3.new(.45,13,.45),CFrame.new(x+48,y+6.5,z-23),C.metal)
    for _,dx in ipairs({-48,53}) do
        local tx,tz=x+dx,z-35
        make(m,"TurbineTower",Vector3.new(1.1,22,1.1),CFrame.new(tx,y+11,tz),C.lightMetal)
        make(m,"TurbineHub",Vector3.new(2,2,2),CFrame.new(tx,y+22,tz),C.lightMetal,Enum.Material.Metal,Enum.PartType.Ball)
        for blade=0,2 do
            local a=blade*math.pi*2/3
            local pos=Vector3.new(tx,y+22,tz)+Vector3.new(math.sin(a)*5.5,math.cos(a)*5.5,0)
            make(m,"TurbineBlade",Vector3.new(.65,11,.22),CFrame.new(pos)*CFrame.Angles(0,0,-a),C.snow)
        end
    end
    for i=1,3 do
        local cx=x+42+(i-1)*11
        make(m,"CargoContainer",Vector3.new(10,7,8),CFrame.new(cx,y+3.5,z+18),i==2 and C.metal or C.redDark,Enum.Material.Metal)
        for rib=-4,4,2 do make(m,"ContainerRib",Vector3.new(.18,6.5,.18),CFrame.new(cx+rib,y+3.5,z+13.9),C.lightMetal) end
    end
    lamp(m,x-18,y,z+25); lamp(m,x+18,y,z+25)
end
local function radio(root,p)
    local m=group(root,"HighlandRadioTower"); local x,y,z=p.X,p.Y,p.Z
    for dx=-1,1,2 do for dz=-1,1,2 do
        make(m,"TowerLeg",Vector3.new(.7,25,.7),CFrame.new(x+dx*4,y+12.5,z+dz*4),C.metal)
    end end
    for h=5,22,5 do
        for _,a in ipairs({35,-35}) do make(m,"CrossBrace",Vector3.new(11,.35,.35),CFrame.new(x,y+h,z)*CFrame.Angles(0,0,math.rad(a)),C.lightMetal) end
    end
    make(m,"Antenna",Vector3.new(.35,12,.35),CFrame.new(x,y+31,z),C.lightMetal)
    local b=make(m,"WarningBeacon",Vector3.new(.9,.9,.9),CFrame.new(x,y+33,z),Color3.fromRGB(255,70,55),Enum.Material.Neon,Enum.PartType.Ball)
    b.CanCollide=false
end
local function shipwreck(root,p)
    local m=group(root,"FrozenShipwreck"); local x,y,z=p.X,p.Y,p.Z
    local tilt=CFrame.new(x,y+2,z)*CFrame.Angles(0,math.rad(-18),math.rad(-8))
    make(m,"Hull",Vector3.new(34,7,11),tilt,C.darkWood,Enum.Material.WoodPlanks)
    make(m,"Deck",Vector3.new(29,.8,10),tilt*CFrame.new(0,3.8,0),C.wood,Enum.Material.WoodPlanks)
    make(m,"BrokenMast",Vector3.new(.8,18,.8),tilt*CFrame.new(-6,12,0)*CFrame.Angles(0,0,math.rad(24)),C.darkWood,Enum.Material.Wood)
    make(m,"Cabin",Vector3.new(9,6,7),tilt*CFrame.new(7,7,0),C.redDark,Enum.Material.WoodPlanks)
    for i=-1,1 do make(m,"HullRib",Vector3.new(.35,8,12),tilt*CFrame.new(i*9,0,0),C.wood,Enum.Material.Wood) end
    for i=1,5 do
        local q=make(m,"IceEncrustation",Vector3.new(5,1.1,3),CFrame.new(x-13+i*5,y+5.8,z+(i%2==0 and 4 or -4)),C.ice,Enum.Material.Ice)
        q.Transparency=.12; q.CanCollide=false
    end
end
local function lookout(root,p)
    local m=group(root,"MountainLookout"); local x,y,z=p.X,p.Y,p.Z
    make(m,"Platform",Vector3.new(20,1.2,16),CFrame.new(x,y+4,z),C.wood,Enum.Material.WoodPlanks)
    for dx=-8,8,16 do for dz=-6,6,12 do make(m,"PlatformLeg",Vector3.new(.8,4,.8),CFrame.new(x+dx,y+2,z+dz),C.darkWood,Enum.Material.Wood) end end
    make(m,"Shelter",Vector3.new(9,6,7),CFrame.new(x,y+7.5,z-2),C.redDark,Enum.Material.WoodPlanks)
    make(m,"SnowRoof",Vector3.new(11,.8,9),CFrame.new(x,y+10.9,z-2),C.snow,Enum.Material.Snow)
    for dx=-9,9,18 do make(m,"Railing",Vector3.new(.35,2.2,15),CFrame.new(x+dx,y+5.6,z),C.wood,Enum.Material.Wood) end
end
local function cabin(root,p)
    local m=group(root,"AbandonedRangerCabin"); local x,y,z=p.X,p.Y,p.Z
    make(m,"CabinBody",Vector3.new(17,9,14),CFrame.new(x,y+4.5,z),C.wood,Enum.Material.WoodPlanks)
    make(m,"SnowRoof",Vector3.new(20,1,17),CFrame.new(x,y+9.5,z),C.snow,Enum.Material.Snow)
    make(m,"Door",Vector3.new(3,6,.35),CFrame.new(x,y+3,z+7.2),C.darkWood,Enum.Material.Wood)
    for dx=-5,5,10 do
        local w=make(m,"FrostedWindow",Vector3.new(3,2.5,.2),CFrame.new(x+dx,y+5,z+7.25),C.ice,Enum.Material.Glass)
        w.Transparency=.35
    end
    make(m,"Chimney",Vector3.new(1.5,5,1.5),CFrame.new(x+5,y+12,z-3),C.rock,Enum.Material.Brick)
end
local function iceCave(root,p)
    local m=group(root,"BlueIceCaveEntrance"); local x,y,z=p.X,p.Y,p.Z
    for side=-1,1,2 do
        local q=make(m,"IceArchPillar",Vector3.new(5,16,7),CFrame.new(x+side*8,y+8,z),C.deepIce,Enum.Material.Ice)
        q.Transparency=.08
    end
    local arch=make(m,"IceArchTop",Vector3.new(21,5,7),CFrame.new(x,y+16,z),C.ice,Enum.Material.Ice); arch.Transparency=.08
    local dark=make(m,"CaveDarkness",Vector3.new(12,11,1),CFrame.new(x,y+6,z-.5),Color3.fromRGB(16,39,58),Enum.Material.SmoothPlastic)
    dark.Transparency=.12; dark.CanCollide=false
    for i=-1,1 do
        local q=make(m,"IceCrystal",Vector3.new(1.2,7+math.abs(i)*2,1.2),CFrame.new(x+i*5,y+3.5,z+4)*CFrame.Angles(0,0,math.rad(i*10)),C.ice,Enum.Material.Glass)
        q.Transparency=.22; q.CanCollide=false
    end
end
function M.Build(layout, groundFn)
    assert(type(layout)=="table" and type(layout.Landmarks)=="table","Expected generated layout.Landmarks")
    assert(type(groundFn)=="function","Expected ground height callback")
    local old=workspace:FindFirstChild("ArcticMilestone2"); if old then old:Destroy() end
    local root=Instance.new("Folder"); root.Name="ArcticMilestone2"; root.Parent=workspace
    local map={}
    for _,lm in ipairs(layout.Landmarks) do map[lm.Id]=lm end
    local function pos(id)
        local lm=map[id]
        if not lm then warn("[ArcticMilestone2] Missing landmark "..id); return nil end
        local x,z=lm.Position.X,lm.Position.Z
        local ok,y=pcall(groundFn,x,z)
        if not ok or type(y)~="number" then y=0 end
        return Vector3.new(x,y,z)
    end
    local p=pos("ResearchOutpost"); if p then outpost(root,p) end
    p=pos("RadioTower"); if p then radio(root,p) end
    p=pos("Shipwreck"); if p then shipwreck(root,p) end
    p=pos("MountainLookout"); if p then lookout(root,p) end
    p=pos("OldCabin"); if p then cabin(root,p) end
    p=pos("IceCave"); if p then iceCave(root,p) end
    root:SetAttribute("Milestone",2)
    root:SetAttribute("WorldSeed",tostring(layout.SeedString or "unknown"))
    print("[ArcticMilestone2] Additive landmark visuals built")
    return root
end
return M
