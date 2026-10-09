--!strict

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _listeners = {}, _destroyed = false }, Signal)
end

function Signal:Connect(callback)
	if self._destroyed then return function() end end
	table.insert(self._listeners, callback)
	local connected = true
	return function()
		if not connected then return end
		connected = false
		for index, listener in ipairs(self._listeners) do
			if listener == callback then table.remove(self._listeners, index); break end
		end
	end
end

function Signal:Fire(...)
	if self._destroyed then return end
	local args = table.pack(...)
	for _, callback in ipairs(self._listeners) do
		local ok, err = xpcall(function() callback(table.unpack(args, 1, args.n)) end, debug.traceback)
		if not ok then warn("[EmberUI] Signal listener failed: " .. tostring(err)) end
	end
end

function Signal:Destroy()
	if self._destroyed then return end
	self._destroyed = true
	table.clear(self._listeners)
end

return Signal
