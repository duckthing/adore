---@type AdoreInit
local Adore = require ""
local DrawRequest = Adore.Resources("DrawRequest")
local Color = Adore.Common("Color")
local mixRGBA = Color.mixRGBA

---@class DrawRequest.WindowPopup: DrawRequest
---@overload fun(bodyColor: number[]?, tabColor: number[]?, angle: number?): DrawRequest.WindowPopup
local DrawWindowPopup = DrawRequest:extend()
DrawWindowPopup.CLASS_NAME = "DrawWindowPopup"

function DrawWindowPopup:new(bodyColor, tabColor, angle)
	DrawWindowPopup.super.new(self)

	---@type number[]
	self.bodyColor = bodyColor or {0.14, 0.14, 0.16, 1}
	---@type number
	self.angle = angle or 0
end

---@param button Button
function DrawWindowPopup:draw(button)
	local lcr = button._localContentRect
	local r, g, b, a = love.graphics.getColor()
	local x, y, w, h = lcr.x, lcr.y, lcr.w, lcr.h
	love.graphics.setColor(mixRGBA(r, g, b, a, unpack(self.bodyColor, 1, 4)))
	love.graphics.rectangle("fill", x, y, w, h, self.angle)
end

return DrawWindowPopup
