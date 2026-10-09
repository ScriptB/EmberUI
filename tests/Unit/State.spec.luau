local State = require("../../src/EmberUI/Core/State")

local state = State(1)
local events = 0
local unsubscribe = state:Subscribe(function(value)
	events += 1
	assert(value == 2 or value == 4)
end)

state:Set(2)
assert(state:Get() == 2)
assert(events == 1)

State.Batch(function()
	state:Set(3)
	state:Set(4)
end)
assert(state:Get() == 4)
assert(events == 2)

unsubscribe()
state:Set(5)
assert(events == 2)

local mapped = state:Map(function(value) return value * 2 end)
assert(mapped:Get() == 10)
state:Set(6)
assert(mapped:Get() == 12)
mapped:Destroy()
state:Set(7)
assert(mapped:Get() == 12)

state:Destroy()
state:Set(8)
assert(state:Get() == 7)
