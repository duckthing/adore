---@type AdoreInit
local Adore = require ""
local SimpleObject = Adore.Libraries("SimpleObject")

---The basic DrawRequest should be overridden. If not, you can instance it with a custom draw function.
---@class DrawRequest: SimpleObject
---@field super DrawRequest
---@overload fun(drawFunc: fun(drawReq: DrawRequest, control: Control)?): DrawRequest
local DrawRequest = SimpleObject:extend()
DrawRequest.CLASS_NAME = "DrawRequest"

function DrawRequest:new(drawFunc)
	DrawRequest.super.new(self)

	---@type integer, integer # The offset applied to the Control's minimum size
	self.minOffsetW, self.minOffsetH =
		0, 0

	if drawFunc then
		self.draw = drawFunc
	end
end

---@param control Control
function DrawRequest:draw(control)
end

---Called whenever a theme-dependent value was changed.
---Usually called after a Control resizes, but might also be called ex. after a label's text changes and the Request manages drawing it.
---
---You may call `Control:_setCanonRect()` in here, and it will trigger a refresh if needed.
---@param control Control
function DrawRequest:themeUpdate(control)
end

---Sets the values that will be added to the Control's minimum size.
---If a parameter is `nil`, it doesn't affect the existing value.
---@generic T: DrawRequest
---@param self T | DrawRequest
---@param ow integer?
---@param oh integer?
---@return T
function DrawRequest:setContentMargin(ow, oh)
	self.minOffsetW, self.minOffsetH =
		ow or self.minOffsetW,
		oh or self.minOffsetH
	return self
end

---Returns the values that should be added to the Control's minimum size when calculating its content rect
---@return integer w
---@return integer h
function DrawRequest:getContentMargin()
	return self.minOffsetW, self.minOffsetH
end

function DrawRequest:__tostring()
	return self.CLASS_NAME
end

return DrawRequest
