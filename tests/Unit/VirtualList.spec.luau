local VirtualList = require("../../src/EmberUI/Layout/VirtualList")

local list = VirtualList.new(30, 2)
assert(list:GetCanvasHeight(1000) == 30000)
assert(list:GetOffset(4) == 90)

local first, last = list:GetRange(1000, 300, 180)
assert(first == 9 and last == 18)

local emptyFirst, emptyLast = list:GetRange(0, 0, 180)
assert(emptyFirst == 1 and emptyLast == 0)
