local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Net = {}
Net.__index = Net
local IS_SERVER = RunService:IsServer()
local MAX_PAYLOAD_BYTES = 10000
local MAX_TABLE_KEYS = 64
local function payloadSize(value, depth)
	depth = depth or 0
	if depth > 4 then
		return 999999
	end
	local kind = typeof(value)
	if kind == "string" then
		return #value
	elseif kind == "number" or kind == "boolean" then
		return 8
	elseif kind == "Vector3" or kind == "CFrame" then
		return 48
	elseif kind == "table" then
		local total, keys = 0, 0
		for k, v in pairs(value) do
			keys += 1
			if keys > MAX_TABLE_KEYS then
				return 999999
			end
			total += payloadSize(k, depth + 1) + payloadSize(v, depth + 1)
			if total > MAX_PAYLOAD_BYTES then
				return total
			end
		end
		return total
	end
	return 999999
end
local function validPayload(data)
	if data == nil then
		return true
	end
	if typeof(data) ~= "table" then
		return false
	end
	return payloadSize(data) <= MAX_PAYLOAD_BYTES
end
local function newRemote(name, unreliable)
	local existing = nil
	if unreliable then
		local ok, remote = pcall(function()
			return Instance.new("UnreliableRemoteEvent")
		end)
		if ok and remote then
			remote.Name = name
			return remote
		end
	end
	existing = Instance.new("RemoteEvent")
	existing.Name = name
	return existing
end
function Net:InitServer(onSuspicious)
	if not IS_SERVER then
		return self
	end
	self._onSuspicious = onSuspicious
	self._serverHandlers = {}
	self._requestHandlers = {}
	self._rate = {}
	self._seenIds = {}
	self._seq = 0
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	local function getRemote(name, unreliable)
		local r = remotes:FindFirstChild(name)
		if not r then
			r = newRemote(name, unreliable)
			r.Parent = remotes
		end
		return r
	end
	self._toClient = getRemote("NetServerToClient", false)
	self._toClientFast = getRemote("NetServerToClientFast", true)
	self._fromClient = getRemote("NetClientToServer", false)
	self._fromClientFast = getRemote("NetClientToServerFast", true)
	local function handle(player, event, data, isFast)
		self:_onClientPacket(player, event, data, isFast)
	end
	self._fromClient.OnServerEvent:Connect(function(player, event, data)
		handle(player, event, data, false)
	end)
	self._fromClientFast.OnServerEvent:Connect(function(player, event, data)
		handle(player, event, data, true)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self._rate[player] = nil
		self._seenIds[player] = nil
	end)
	return self
end
function Net:_suspicious(player, event, reason)
	warn(("[Net] dropped packet from %s: %s (%s)"):format(player.Name, event, reason))
	if self._onSuspicious then
		pcall(self._onSuspicious, player, event, reason)
	end
end
function Net:_rateOk(player, event, opts)
	local limit = (opts and opts.RateLimit) or 20
	local now = os.clock()
	local perPlayer = self._rate[player]
	if not perPlayer then
		perPlayer = {}
		self._rate[player] = perPlayer
	end
	local bucket = perPlayer[event]
	if not bucket or now - bucket.WindowStart >= 1 then
		bucket = { Count = 0, WindowStart = now }
		perPlayer[event] = bucket
	end
	bucket.Count += 1
	return bucket.Count <= limit
end
function Net:_onClientPacket(player, event, data)
	if typeof(event) ~= "string" or event == "" then
		return
	end
	if event:sub(1, 8) == "__reply:" then
		return
	end
	local handler = self._serverHandlers[event]
	if not handler then
		self:_suspicious(player, event, "no handler (not whitelisted)")
		return
	end
	if not validPayload(data) then
		self:_suspicious(player, event, "bad payload")
		return
	end
	if not self:_rateOk(player, event, handler.Opts) then
		self:_suspicious(player, event, "rate limit")
		return
	end
	if handler.Opts and handler.Opts.Idempotent and typeof(data) == "table" then
		local requestId = data.__requestId
		if typeof(requestId) ~= "string" or requestId == "" then
			self:_suspicious(player, event, "idempotent packet without requestId")
			return
		end
		local seen = self._seenIds[player]
		if not seen then
			seen = {}
			self._seenIds[player] = seen
		end
		local now = os.clock()
		if seen[requestId] then
			return
		end
		seen[requestId] = now
		for id, at in pairs(seen) do
			if now - at > 120 then
				seen[id] = nil
			end
		end
	end
	if handler.IsRequest then
		local reply = nil
		local ok, result = pcall(handler.Fn, player, data)
		if ok then
			reply = result
		end
		if typeof(data) == "table" and typeof(data.__requestId) == "string" then
			self:SendToClient(player, "__reply:" .. data.__requestId, reply or {})
		end
		return
	end
	local ok, err = pcall(handler.Fn, player, data)
	if not ok then
		warn(("[Net] handler error for %s: %s"):format(event, tostring(err)))
	end
end
function Net:ListenToClient(event, fn, opts)
	if not IS_SERVER then
		return
	end
	if not self._serverHandlers then
		self._serverHandlers = {}
	end
	self._serverHandlers[event] = { Fn = fn, Opts = opts or {}, IsRequest = false }
end
function Net:OnRequest(event, fn, opts)
	if not IS_SERVER then
		return
	end
	if not self._serverHandlers then
		self._serverHandlers = {}
	end
	self._serverHandlers[event] = { Fn = fn, Opts = opts or {}, IsRequest = true }
end
function Net:SendToClient(player, event, data)
	if not IS_SERVER or not self._toClient then
		return
	end
	self._toClient:FireClient(player, event, data)
end
function Net:SendToClientFast(player, event, data)
	if not IS_SERVER or not self._toClientFast then
		return
	end
	self._toClientFast:FireClient(player, event, data)
end
function Net:SendToAll(event, data)
	if not IS_SERVER then
		return
	end
	for _, player in ipairs(Players:GetPlayers()) do
		self:SendToClient(player, event, data)
	end
end
function Net:SendToAllExcept(exceptPlayer, event, data)
	if not IS_SERVER then
		return
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= exceptPlayer then
			self:SendToClient(player, event, data)
		end
	end
end
function Net:SendToPlayers(list, event, data)
	if not IS_SERVER then
		return
	end
	for _, player in ipairs(list) do
		self:SendToClient(player, event, data)
	end
end
function Net:InitClient()
	if IS_SERVER then
		return self
	end
	self._clientHandlers = {}
	self._pendingRequests = {}
	self._seq = 0
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	if not remotes then
		warn("[Net] no Remotes folder -- server Net:InitServer() has not run")
		return self
	end
	self._toServer = remotes:WaitForChild("NetClientToServer", 10)
	self._toServerFast = remotes:WaitForChild("NetClientToServerFast", 10)
	self._fromServer = remotes:WaitForChild("NetServerToClient", 10)
	self._fromServerFast = remotes:WaitForChild("NetServerToClientFast", 10)
	local function handle(event, data)
		if typeof(event) == "string" and event:sub(1, 8) == "__reply:" then
			local requestId = event:sub(9)
			local callback = self._pendingRequests[requestId]
			if callback then
				self._pendingRequests[requestId] = nil
				callback(data)
			end
			return
		end
		local handler = self._clientHandlers[event]
		if handler then
			pcall(handler, data)
		end
	end
	if self._fromServer then
		self._fromServer.OnClientEvent:Connect(handle)
	end
	if self._fromServerFast then
		self._fromServerFast.OnClientEvent:Connect(handle)
	end
	return self
end
function Net:ListenToServer(event, fn)
	if IS_SERVER then
		return
	end
	if not self._clientHandlers then
		self._clientHandlers = {}
	end
	self._clientHandlers[event] = fn
end
function Net:SendToServer(event, data, opts)
	if IS_SERVER or not self._toServer then
		return
	end
	if opts and opts.Idempotent then
		if typeof(data) ~= "table" then
			data = {}
		end
		self._seq += 1
		data.__requestId = tostring(os.clock()) .. "-" .. tostring(self._seq)
	end
	self._toServer:FireServer(event, data)
end
function Net:SendToServerFast(event, data)
	if IS_SERVER or not self._toServerFast then
		return
	end
	self._toServerFast:FireServer(event, data)
end
function Net:RequestServer(event, data, callback)
	if IS_SERVER or not self._toServer then
		if callback then
			callback(nil)
		end
		return
	end
	if typeof(data) ~= "table" then
		data = {}
	end
	self._seq += 1
	local requestId = tostring(os.clock()) .. "-" .. tostring(self._seq)
	data.__requestId = requestId
	self._pendingRequests[requestId] = callback
	self._toServer:FireServer(event, data)
	task.delay(5, function()
		local pending = self._pendingRequests[requestId]
		if pending then
			self._pendingRequests[requestId] = nil
			pending(nil)
		end
	end)
end
Net.Events = {
	"UpdateInventory",
	"SackAction",
	"EatMeat",
	"WolfCommand",
	"WolfBehaviour",
	"MerchantBuy",
	"MerchantSell",
	"ClassShopBuy",
	"ClassShopEquip",
	"StormWarning",
	"FishingSync",
	"DragSync",
}
return Net
