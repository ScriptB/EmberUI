--!strict

export type Unsubscribe = () -> ()
export type State<T> = {
	Get: (self: State<T>) -> T,
	Set: (self: State<T>, value: T) -> (),
	Update: (self: State<T>, updater: (T) -> T) -> (),
	Subscribe: (self: State<T>, callback: (T) -> ()) -> Unsubscribe,
	Sub: (self: State<T>, callback: (T) -> ()) -> Unsubscribe,
	Once: (self: State<T>, callback: (T) -> ()) -> Unsubscribe,
	Map: (self: State<T>, mapper: (T) -> any) -> State<any>,
	Destroy: (self: State<T>) -> (),
}

local batchDepth = 0
local pending: { [any]: () -> () } = {}

local function flush()
	local work = pending
	pending = {}
	for _, emit in pairs(work) do emit() end
end

local State: any

local function createState<T>(default: T, equals: ((T, T) -> boolean)?): State<T>
	local value = default
	local subscribers: { (T) -> () } = {}
	local destroyed = false
	local self = {} :: any
	local compare = equals or function(a, b) return a == b end
	local function emit()
		if destroyed then return end
		for _, callback in ipairs(subscribers) do
			local ok, err = xpcall(function() callback(value) end, debug.traceback)
			if not ok then warn("[EmberUI] State subscriber failed: " .. tostring(err)) end
		end
	end

	function self:Get(): T
		return value
	end
	function self:Set(nextValue: T)
		if destroyed or compare(nextValue, value) then return end
		value = nextValue
		if batchDepth > 0 then pending[self] = emit else emit() end
	end
	function self:Update(updater: (T) -> T)
		self:Set(updater(value))
	end
	function self:Subscribe(callback: (T) -> ()): Unsubscribe
		if destroyed then return function() end end
		table.insert(subscribers, callback)
		local subscribed = true
		return function()
			if not subscribed then return end
			subscribed = false
			for index, current in ipairs(subscribers) do
				if current == callback then table.remove(subscribers, index); break end
			end
		end
	end
	self.Sub = self.Subscribe
	function self:Once(callback: (T) -> ()): Unsubscribe
		local unsubscribe: Unsubscribe
		unsubscribe = self:Subscribe(function(nextValue)
			unsubscribe()
			callback(nextValue)
		end)
		return unsubscribe
	end
	function self:Map(mapper: (T) -> any)
		local mapped = State(mapper(value))
		local unsubscribe = self:Subscribe(function(nextValue) mapped:Set(mapper(nextValue)) end)
		local mappedDestroy = mapped.Destroy
		function mapped:Destroy()
			unsubscribe()
			mappedDestroy(self)
		end
		return mapped
	end
	function self:Destroy()
		if destroyed then return end
		destroyed = true
		table.clear(subscribers)
	end
	return self
end

State = setmetatable({}, {
	__call = function(_, default, equals)
		return createState(default, equals)
	end,
})

function State.Batch(callback: () -> ())
	batchDepth += 1
	local ok, err = xpcall(callback, debug.traceback)
	batchDepth -= 1
	if batchDepth == 0 then flush() end
	if not ok then error(err, 0) end
end

function State.Computed(dependencies: { any }, compute: () -> any)
	local result = State(compute())
	local unsubscribers = {}
	for _, dependency in ipairs(dependencies) do
		table.insert(unsubscribers, dependency:Subscribe(function()
			result:Set(compute())
		end))
	end
	local resultDestroy = result.Destroy
	function result:Destroy()
		for _, unsubscribe in ipairs(unsubscribers) do unsubscribe() end
		table.clear(unsubscribers)
		resultDestroy(self)
	end
	return result
end

return State
