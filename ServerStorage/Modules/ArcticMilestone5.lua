local Players = game:GetService("Players")
local Treasury = require(script.Parent:WaitForChild("Treasury"))
local M = {}
local REWARDS = {
	ResearchOutpost = {Flakes=35, Title="Research Outpost"},
	RadioTower = {Flakes=20, Title="Radio Tower"},
	Shipwreck = {Flakes=25, Title="Frozen Shipwreck"},
	MountainLookout = {Flakes=20, Title="Mountain Lookout"},
	OldCabin = {Flakes=15, Title="Ranger Cabin"},
	IceCave = {Flakes=30, Title="Blue Ice Cave"},
}
local function notify(gameplay, player, message)
	if gameplay and type(gameplay.Notify)=="function" then
		pcall(function() gameplay:Notify(player,message) end)
	end
end
local function makePrompt(parent, action, object, distance)
	local prompt=Instance.new("ProximityPrompt")
	prompt.ActionText=action
	prompt.ObjectText=object
	prompt.HoldDuration=1
	prompt.MaxActivationDistance=12
	prompt.RequiresLineOfSight=false
	prompt.Parent=parent
	return prompt
end
function M.Init(gameplay, layout, groundFn)
	local function groundAt(x, z, fallback)
		if type(groundFn) == "function" then
			local ok, y = pcall(groundFn, x, z)
			if ok and type(y) == "number" then return y end
		end
		return fallback
	end
	local landmarks=layout and layout.Landmarks or {}
	if #landmarks==0 then warn("[ArcticMilestone5] No landmarks supplied"); return end
	local old=workspace:FindFirstChild("ArcticExpeditionPoints"); if old then old:Destroy() end
	local folder=Instance.new("Folder"); folder.Name="ArcticExpeditionPoints"; folder.Parent=workspace

	for _,landmark in ipairs(landmarks) do
		local reward=REWARDS[landmark.Id]
		if reward and landmark.Position then
			local anchor=Instance.new("Part")
			anchor.Name=landmark.Id.."_ExpeditionMarker"
			anchor.Size=Vector3.new(2,3,2)
			anchor.CFrame=CFrame.new(landmark.Position.X,groundAt(landmark.Position.X,landmark.Position.Z,landmark.Position.Y)+3,landmark.Position.Z)
			anchor.Anchored=true; anchor.Transparency=1
			anchor.CanCollide=false; anchor.CanTouch=false; anchor.CanQuery=false
			anchor.Parent=folder
			anchor:SetAttribute("LandmarkId",landmark.Id)
			local prompt=makePrompt(anchor,"Log expedition","Expedition: "..reward.Title,12)
			prompt.Triggered:Connect(function(player)
				local character=player.Character
				local root=character and character:FindFirstChild("HumanoidRootPart")
				if not root or (root.Position-anchor.Position).Magnitude>15 then return end
				local profile=Treasury.GetProfile(player)
				profile.Discoveries=profile.Discoveries or {}
				local key="Expedition_"..landmark.Id
				if profile.Discoveries[key] then
					notify(gameplay,player,"Expedition already recorded: "..reward.Title)
					return
				end
				profile.Discoveries[key]=true
				profile.Flakes=math.max(0,tonumber(profile.Flakes) or 0)+reward.Flakes
				player:SetAttribute("Flakes",profile.Flakes)
				Treasury.Save(player)
				notify(gameplay,player,("Expedition complete: %s (+%d Flakes)"):format(reward.Title,reward.Flakes))
			end)
		end
	end

	local outpost
	for _,lm in ipairs(landmarks) do if lm.Id=="ResearchOutpost" then outpost=lm break end end
	if outpost then
		local board=Instance.new("Part")
		board.Name="ExpeditionBoard"
		board.Size=Vector3.new(7,5,.6)
		board.CFrame=CFrame.new(outpost.Position.X+78,groundAt(outpost.Position.X+78,outpost.Position.Z+21,outpost.Position.Y)+3,outpost.Position.Z+21)
		board.Anchored=true; board.Color=Color3.fromRGB(22,48,62)
		board.Material=Enum.Material.Metal; board.Parent=folder
		local gui=Instance.new("SurfaceGui"); gui.Face=Enum.NormalId.Front; gui.Parent=board
		local label=Instance.new("TextLabel"); label.Size=UDim2.fromScale(1,1); label.BackgroundTransparency=1
		label.Text="ARCTIC EXPEDITIONS\\nVisit each landmark\\nRecord your field report"
		label.TextColor3=Color3.fromRGB(226,238,246); label.Font=Enum.Font.GothamBold
		label.TextScaled=true; label.Parent=gui
		local prompt=makePrompt(board,"Review","Expedition Board",12)
		prompt.Triggered:Connect(function(player)
			local profile=Treasury.GetProfile(player)
			local count=0
			for id in pairs(REWARDS) do
				if profile.Discoveries and profile.Discoveries["Expedition_"..id] then count+=1 end
			end
			notify(gameplay,player,("Field reports recorded: %d / %d"):format(count,#landmarks))
		end)
	end
	print("[ArcticMilestone5] Landmark expedition rewards initialized")
end
return M
