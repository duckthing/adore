---@type AdoreInit
local Adore = require ""
local DrawRequest = Adore.Resources("DrawRequest")
local Color = Adore.Common("Color")
local mixRGBA = Color.mixRGBA

---Unlike `DrawRequest.NinePatch`, this one draws a contained
---@class DrawRequest.NinePatchRect: DrawRequest
---@overload fun(scale: number?): DrawRequest.NinePatchRect
local DrawNinePatchRect = DrawRequest:extend()
DrawNinePatchRect.CLASS_NAME = "DrawNinePatchRect"

function DrawNinePatchRect:new(scale)
	DrawNinePatchRect.super.new(self)

	---@type number # The scale of the NinePatch
	self.scale = scale or 1
end

---@param nprControl NinePatchRect
function DrawNinePatchRect:draw(nprControl)
	local np = nprControl.ninepatch
	local lcr = nprControl._localContentRect
	np:draw(lcr.x, lcr.y, lcr.w, lcr.h, rawget(nprControl, "ninepatchScale") or self.scale)
end

return DrawNinePatchRect
