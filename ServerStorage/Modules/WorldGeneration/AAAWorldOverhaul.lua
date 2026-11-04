local Lighting=game:GetService("Lighting")
local CollectionService=game:GetService("CollectionService")
local Workspace=game:GetService("Workspace")
local M={}
local C={MaxOutcrops=90,MaxDrifts=110,MaxForestDetails=140,EnablePalette=true,EnablePostFX=true}
local palette={
 [Enum.Material.Snow]=Color3.fromRGB(226,237,246),
 [Enum.Material.Ice]=Color3.fromRGB(137,190,215),
 [Enum.Material.Glacier]=Color3.fromRGB(119,177,207),
 [Enum.Material.Rock]=Color3.fromRGB(92,105,117),
 [Enum.Material.Slate]=Color3.fromRGB(75,91,105),
 [Enum.Material.Ground]=Color3.fromRGB(83,91,88),
}
local function hash(s) local n=17 for i=1,#s do n=(n*31+string.byte(s,i))%2147483647 end return n end
local function d2(x,z,a,b) return (x-a)^2+(z-b)^2 end
local function ground(fn,x,z) local ok,y=pcall(fn,x,z) if ok and type(y)=="number" then return y end return 0 end
local function excluded(l,x,z,r)
 if x*x+z*z<100^2 then return true end
 if l.Lake and d2(x,z,l.Lake.X,l.Lake.Z)<(l.Lake.Radius+r)^2 then return true end
 if l.Mountain and d2(x,z,l.Mountain.X,l.Mountain.Z)<(l.Mountain.Radius*.72)^2 then return true end
 for _,v in ipairs(l.Landmarks or {}) do local p=v.Position if p and d2(x,z,p.X,p.Z)<(105+r)^2 then return true end end
 for i=1,#(l.River or {})-1 do local a,b=l.River[i],l.River[i+1] local ax,az=a.X,a.Y local bx,bz=b.X,b.Y local dx,dz=bx-ax,bz-az local q=dx*dx+dz*dz local t=0 if q>0 then t=math.clamp(((x-ax)*dx+(z-az)*dz)/q,0,1) end if d2(x,z,ax+dx*t,az+dz*t)<(34+r)^2 then return true end end
 return false
end
local function part(parent,name,size,cf,color,mat,shape)
 local p=Instance.new("Part") p.Name=name p.Size=size p.CFrame=cf p.Color=color p.Material=mat p.Anchored=true
 p.CanCollide=false p.CanTouch=false p.CanQuery=false p.CastShadow=false p.TopSurface=Enum.SurfaceType.Smooth p.BottomSurface=Enum.SurfaceType.Smooth
 if shape then p.Shape=shape end p.Parent=parent CollectionService:AddTag(p,"ArcticAAADecor") return p
end
local function postFX()
 if not C.EnablePostFX then return end
 if not Lighting:FindFirstChild("ArcticAAA_Bloom") then local x=Instance.new("BloomEffect") x.Name="ArcticAAA_Bloom" x.Intensity=.12 x.Size=18 x.Threshold=1.8 x.Parent=Lighting end
 if not Lighting:FindFirstChild("ArcticAAA_Color") then local x=Instance.new("ColorCorrectionEffect") x.Name="ArcticAAA_Color" x.Brightness=-.015 x.Contrast=.08 x.Saturation=-.06 x.TintColor=Color3.fromRGB(222,235,246) x.Parent=Lighting end
 if not Lighting:FindFirstChild("ArcticAAA_SunRays") then local x=Instance.new("SunRaysEffect") x.Name="ArcticAAA_SunRays" x.Intensity=.025 x.Spread=.72 x.Parent=Lighting end
end
function M.Build(layout,groundY)
 assert(type(layout)=="table" and type(groundY)=="function","layout and groundY required")
 local old=Workspace:FindFirstChild("ArcticAAAOverhaul") if old then old:Destroy() end
 local root=Instance.new("Folder") root.Name="ArcticAAAOverhaul" root.Parent=Workspace root:SetAttribute("BaseBranch","GPT")
 local rng=Random.new(hash(tostring(layout.SeedString or "arctic"))+707)
 if C.EnablePalette then local terrain=Workspace:FindFirstChildOfClass("Terrain") if terrain then for mat,col in pairs(palette) do pcall(function() terrain:SetMaterialColor(mat,col) end) end end end
 local ridge=Instance.new("Folder") ridge.Name="MountainOutcrops" ridge.Parent=root
 local drift=Instance.new("Folder") drift.Name="WindSculptedSnow" drift.Parent=root
 local out=0
 for _,peak in ipairs(layout.Peaks or {}) do for j=1,5 do if out>=C.MaxOutcrops then break end
  local a=rng:NextNumber(0,math.pi*2) local r=peak.Radius*rng:NextNumber(.68,1.02) local x,z=peak.X+math.cos(a)*r,peak.Z+math.sin(a)*r
  if not excluded(layout,x,z,12) then local y=ground(groundY,x,z) local sx,sy,sz=rng:NextNumber(8,19),rng:NextNumber(3,8),rng:NextNumber(7,16)
   local rock=part(ridge,"AngularMountainOutcrop",Vector3.new(sx,sy,sz),CFrame.new(x,y+sy*.28,z)*CFrame.Angles(rng:NextNumber(-.18,.18),a,rng:NextNumber(-.16,.16)),Color3.fromRGB(83,99,113),Enum.Material.Slate)
   if rng:NextNumber()<.58 then part(ridge,"SnowLip",Vector3.new(sx*.72,.65,sz*.68),rock.CFrame*CFrame.new(0,sy*.43,0),Color3.fromRGB(222,235,244),Enum.Material.Snow) end out+=1
  end
 end end
 local drifts=0
 for i=1,C.MaxDrifts do local a=rng:NextNumber(0,math.pi*2) local r=math.sqrt(rng:NextNumber())*math.max(350,(layout.WorldRadius or 1850)-100) local x,z=math.cos(a)*r,math.sin(a)*r
  if not excluded(layout,x,z,8) then local y=ground(groundY,x,z) local sx,sy,sz=rng:NextNumber(7,17),rng:NextNumber(.45,1.1),rng:NextNumber(3,8)
   part(drift,"WindCarvedSnowBank",Vector3.new(sx,sy,sz),CFrame.new(x,y+sy*.35,z)*CFrame.Angles(0,rng:NextNumber(0,math.pi*2),rng:NextNumber(-.07,.07)),Color3.fromRGB(225,237,246),Enum.Material.Snow) drifts+=1
  end
 end
 local forest=Instance.new("Folder") forest.Name="ForestFloorDetail" forest.Parent=root local forestN=0
 for _,tree in ipairs(layout.Trees or {}) do if forestN>=C.MaxForestDetails then break end if rng:NextNumber()<.28 then
  local a=rng:NextNumber(0,math.pi*2) local r=rng:NextNumber(4,10) local x,z=tree.X+math.cos(a)*r,tree.Z+math.sin(a)*r
  if not excluded(layout,x,z,5) then local y=ground(groundY,x,z) local sx,sy,sz=rng:NextNumber(2.5,5),rng:NextNumber(.8,1.8),rng:NextNumber(2,4.5)
   local rock=part(forest,"ForestStone",Vector3.new(sx,sy,sz),CFrame.new(x,y+sy*.32,z)*CFrame.Angles(0,a,0),Color3.fromRGB(105,119,130),Enum.Material.Slate,Enum.PartType.Ball)
   if rng:NextNumber()<.65 then part(forest,"StoneSnowCap",Vector3.new(sx*.75,.28,sz*.7),rock.CFrame*CFrame.new(0,sy*.45,0),Color3.fromRGB(222,234,243),Enum.Material.Snow) end forestN+=1
  end
 end end
 local lmFolder=Instance.new("Folder") lmFolder.Name="LandmarkArtPass" lmFolder.Parent=root local lmN=0
 for _,lm in ipairs(layout.Landmarks or {}) do local p=lm.Position if p then local y=ground(groundY,p.X,p.Z)
  if lm.Id=="ResearchOutpost" then for side=-1,1,2 do part(lmFolder,"OutpostSnowBarrier",Vector3.new(13,.7,1.2),CFrame.new(p.X+side*24,y+.35,p.Z+20),Color3.fromRGB(197,213,224),Enum.Material.Metal) lmN+=1 end
  elseif lm.Id=="RadioTower" then for i=1,3 do local a=i*math.pi*2/3 local x,z=p.X+math.cos(a)*17,p.Z+math.sin(a)*17 part(lmFolder,"TowerAnchorSnowMound",Vector3.new(4,1.1,3),CFrame.new(x,ground(groundY,x,z)+.35,z),Color3.fromRGB(218,231,241),Enum.Material.Snow) lmN+=1 end
  elseif lm.Id=="Shipwreck" then for i=1,4 do part(lmFolder,"ShipwreckIceRidge",Vector3.new(7,.9,2.5),CFrame.new(p.X-18+i*9,y+1.2,p.Z+(i%2==0 and 7 or -7)),Color3.fromRGB(145,194,218),Enum.Material.Ice) lmN+=1 end
  elseif lm.Id=="IceCave" then for i=1,5 do local a=i*math.pi*2/5 local x,z=p.X+math.cos(a)*22,p.Z+math.sin(a)*22 part(lmFolder,"CaveIceShard",Vector3.new(1.4,rng:NextNumber(4,8),1.5),CFrame.new(x,y+2.5,z)*CFrame.Angles(0,a,rng:NextNumber(-.12,.12)),Color3.fromRGB(111,181,214),Enum.Material.Ice) lmN+=1 end end
 end end
 postFX()
 local n=0 for _,v in ipairs(root:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide=false v.CanTouch=false v.CanQuery=false v.CastShadow=false n+=1 end end
 root:SetAttribute("Outcrops",out) root:SetAttribute("SnowDrifts",drifts) root:SetAttribute("ForestAccents",forestN) root:SetAttribute("LandmarkAccents",lmN) root:SetAttribute("DecorPartCount",n)
 root:SetAttribute("OptimizationProfile","NoCollision_NoShadow_BoundedDecor")
 print(("[Arctic AAA] %d outcrops, %d drifts, %d forest details, %d landmark details"):format(out,drifts,forestN,lmN))
 return root
end
return M
