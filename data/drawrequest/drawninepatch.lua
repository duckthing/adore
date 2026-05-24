---@type AdoreInit
local Adore = require ""
local DrawRequest = Adore.Resources("DrawRequest")
local Color = Adore.Common("Color")
local mixRGBA = Color.mixRGBA

---@class DrawRequest.NinePatch: DrawRequest
---@overload fun(color: integer[]?, ninepatch: NinePatch, scale: number?): DrawRequest.NinePatch
local DrawNinePatch = DrawRequest:extend()
DrawNinePatch.CLASS_NAME = "DrawNinePatch"

function DrawNinePatch:new(color, ninepatch, scale)
	DrawNinePatch.super.new(self)

	---@type integer[] # The base color, will be mixed with the Control's albedo
	self.baseColor = color or {1, 1, 1, 1}

	---@type NinePatch
	self.np = ninepatch
	---@type number
	self.scale = scale or 1
end

---@param control Control
function DrawNinePatch:draw(control)
	local r, g, b, a = love.graphics.getColor()
	love.graphics.setColor(mixRGBA(r, g, b, a, unpack(self.baseColor, 1, 4)))

	local np = self.np
	local lcr = control._localContentRect
	np:draw(lcr.x, lcr.y, lcr.w, lcr.h, self.scale)
end

return DrawNinePatch
