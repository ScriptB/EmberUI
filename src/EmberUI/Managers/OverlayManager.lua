--!strict

local UserInputService = game:GetService("UserInputService")

local OverlayManager = {}
OverlayManager.__index = OverlayManager

function OverlayManager.new(maid)
	local self = setmetatable({ _top = nil }, OverlayManager)
	maid:Give(UserInputService.InputBegan:Connect(function(input)
		local current = self._top
		if not current then return end
		if input.KeyCode == Enum.KeyCode.Escape then
			self:CloseTop()
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		task.defer(function()
			current = self._top
			if not current or not current.frame.Parent then return end
			local point, position, size = input.Position, current.frame.AbsolutePosition, current.frame.AbsoluteSize
			if point.X < position.X or point.X > position.X + size.X or point.Y < position.Y or point.Y > position.Y + size.Y then
				self:CloseTop()
			end
		end)
	end))
	return self
end

function OverlayManager:Open(frame, close)
	self:CloseTop()
	self._top = { frame = frame, close = close }
end

function OverlayManager:Clear(frame)
	if self._top and self._top.frame == frame then self._top = nil end
end

function OverlayManager:CloseTop()
	local current = self._top
	if not current then return end
	self._top = nil
	current.close()
end

return OverlayManager
