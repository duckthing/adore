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

function DrawRequest:__tostring()
	return self.CLASS_NAME
end

return DrawRequest
