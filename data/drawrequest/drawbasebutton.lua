---@type AdoreInit
local Adore = require ""
local DrawRequest = Adore.Resources("DrawRequest")
local Color = Adore.Common("Color")
local mixRGBA = Color.mixRGBA

---@class DrawRequest.BaseButton: DrawRequest
---@overload fun(color: number[]?, angle: number?): DrawRequest.BaseButton
local DrawBaseButton = DrawRequest:extend()
DrawBaseButton.CLASS_NAME = "DrawBaseButton"

function DrawBaseButton:new(color, angle)
	DrawBaseButton.super.new(self)

	---@type number[]
	self.baseColor = color or {1, 1, 1}
	---@type number
	self.angle = angle or 4
end

---@param button Button
function DrawBaseButton:draw(button)
	local lcr = button._localContentRect
	local r, g, b, a = love.graphics.getColor()
	local x, y, w, h = lcr.x, lcr.y, lcr.w, lcr.h
	love.graphics.setColor(mixRGBA(r, g, b, a, unpack(self.baseColor, 1, 4)))
	love.graphics.rectangle("fill", x, y, w, h, self.angle)
end

return DrawBaseButton
