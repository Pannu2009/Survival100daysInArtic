-- Network (Net): the game's single packet layer.
--
-- One module, both sides, four remotes total -- instead of a
-- new RemoteEvent per feature:
--   NetServerToClient (reliable)   server -> client
--   NetClientToServer (reliable)   client -> server
--   NetServerToClientFast (unreliable, loss-tolerant)
--   NetClientToServerFast (unreliable, loss-tolerant)
--
-- Client API (exactly the shape you asked for):
--   Net:ListenToServer("UpdateInventory", function(itemData) ... end)
--   Net:SendToServer("SackAction", { Action = "Store" })
--   Net:RequestServer("MerchantBuy", { Item = "Food" }, function(reply) ... end)
--   Net:SendToServerFast("FishingSync", { Bar = 0.5 })
--
-- Server API:
--   Net:SendToClient(player, "UpdateInventory", itemData)
--   Net:SendToAll("StormWarning", { Storm = true })
--   Net:SendToAllExcept(player, "UpdateInventory", itemData)
--   Net:ListenToClient("SackAction", function(player, data) ... end)
--   Net:OnRequest("MerchantBuy", function(player, data) return { Ok = true } end)
--
-- Why this helps dupes and exploits (read this before
-- trusting any client packet):
-- 1. WHITELIST: the server only accepts an event a handler
--    was registered for. An exploiter inventing a new event
--    name gets dropped and logged, never routed anywhere.
-- 2. SERVER IS THE AUTHORITY: Net only transports. A packet
--    is a REQUEST, never a fact. The handler must re-check
--    server state (coins, stock, distance, ownership) before
--    changing anything. Never do Coins += data.Amount.
-- 3. NO INSTANCES IN PAYLOADS: payloads are tables of
--    numbers, strings, booleans, Vector3 and CFrame only.
--    The client sends an ID ("Food", a sack slot), the
--    server resolves it. An Instance smuggled in a packet
--    is rejected outright.
-- 4. RATE LIMITS: every client event is rate-limited per
--    player (default 20/sec, configurable per event).
--    Spamming a buy/craft/store packet gets dropped.
-- 5. IDEMPOTENCY: send with { Idempotent = true } and the
--    server drops a replayed requestId. Replaying a
--    "buy" packet twice cannot buy twice.
-- 6. UNRELIABLE IS FOR LOSABLE DATA ONLY: fishing bars,
--    drag positions, wind. Never coins, items, or kills.
--
-- Existing remotes stay as they are for now -- they are
-- already Aegis-secured, and migrating them all in one go
-- would risk the just-tested Batch 1. New features use
-- Net, and old systems move to it one at a time.
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
	-- Instance, function, userdata, anything else: not allowed.
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
	self._rate = {} -- player -> event -> { Count, WindowStart }
	self._seenIds = {} -- player -> requestId -> time
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
	-- Replies to server requests are routed by requestId,
	-- they are not client events.
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
	-- Idempotency: the same requestId twice is one action.
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
			return -- replayed packet: silently dropped, no second effect
		end
		seen[requestId] = now
		-- Prune old ids so the table cannot grow forever.
		for id, at in pairs(seen) do
			if now - at > 120 then
				seen[id] = nil
			end
		end
	end
	-- Request/response: handler returns a reply payload.
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

-- Server: register a client -> server event.
-- opts: { RateLimit = 20, Idempotent = true }
function Net:ListenToClient(event, fn, opts)
	if not IS_SERVER then
		return
	end
	if not self._serverHandlers then
		self._serverHandlers = {}
	end
	self._serverHandlers[event] = { Fn = fn, Opts = opts or {}, IsRequest = false }
end

-- Server: register a request handler (client RequestServer).
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

-- ---------- client side ----------

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

-- Client request/response: the server handler's return
-- value arrives in the callback, or nil after 5 seconds.
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

-- Future event names, kept here so new features share
-- one list instead of inventing remote names each time.
-- Registering a handler is what whitelists an event;
-- this table is documentation, not enforcement.
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
