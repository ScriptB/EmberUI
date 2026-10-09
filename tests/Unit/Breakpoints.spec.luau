local Breakpoints = require("../../src/EmberUI/Layout/Breakpoints")

assert(Breakpoints.Get(320) == "Compact")
assert(Breakpoints.Get(520) == "Standard")
assert(Breakpoints.Get(1100) == "Wide")
assert(Breakpoints.Get(1600) == "Expanded")
