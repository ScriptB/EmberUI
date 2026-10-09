--!strict

local VirtualList = {}
VirtualList.__index = VirtualList

function VirtualList.new(itemHeight, overscan)
	if type(itemHeight) ~= "number" or itemHeight <= 0 then error("EmberUI VirtualList itemHeight must be positive", 2) end
	return setmetatable({ _itemHeight = itemHeight, _overscan = overscan or 3 }, VirtualList)
end

function VirtualList:GetCanvasHeight(count)
	return math.max(0, count) * self._itemHeight
end

function VirtualList:GetRange(count, scrollY, viewportHeight)
	if count <= 0 or viewportHeight <= 0 then return 1, 0 end
	local first = math.max(1, math.floor(math.max(0, scrollY) / self._itemHeight) + 1 - self._overscan)
	local last = math.min(count, math.ceil((math.max(0, scrollY) + viewportHeight) / self._itemHeight) + self._overscan)
	return first, math.max(first - 1, last)
end

function VirtualList:GetOffset(index)
	return math.max(0, index - 1) * self._itemHeight
end

return VirtualList
