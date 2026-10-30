local Signal = {}
Signal.__index = Signal
function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end
function Signal:Connect(fn)
	local conn = { Fn = fn, Connected = true }
	function conn:Disconnect()
		self.Connected = false
	end
	table.insert(self._handlers, conn)
	return conn
end
function Signal:Fire(...)
	for _, conn in ipairs(self._handlers) do
		if conn.Connected then
			conn.Fn(...)
		end
	end
end
return Signal
