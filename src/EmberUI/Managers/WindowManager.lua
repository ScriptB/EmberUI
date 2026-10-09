--!strict

local WindowManager = {}
WindowManager.__index = WindowManager

export type WindowLike = {
	_gui: ScreenGui,
	Id: string?,
}

function WindowManager.new()
	return setmetatable({ _windows = {}, _displayOrder = 0 }, WindowManager)
end

function WindowManager:Get(id: string): WindowLike?
	return self._windows[id]
end

function WindowManager:Register(id: string?, window: WindowLike)
	if id then
		if self._windows[id] then error(("EmberUI duplicate window Id '%s'"):format(id), 3) end
		self._windows[id] = window
		window.Id = id
	end
	self:BringToFront(window)
end

function WindowManager:Unregister(window: WindowLike)
	if window.Id and self._windows[window.Id] == window then
		self._windows[window.Id] = nil
	end
end

function WindowManager:BringToFront(window: WindowLike)
	self._displayOrder += 1
	window._gui.DisplayOrder = self._displayOrder
end

return WindowManager
