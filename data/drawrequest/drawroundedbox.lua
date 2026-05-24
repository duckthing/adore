---@type AdoreInit
local Adore = require ""
local DrawRequest = Adore.Resources("DrawRequest")

---@class DrawRequest.RoundedBox: DrawRequest
local DrawRoundedBox = DrawRequest:extend()
DrawRoundedBox.CLASS_NAME = "DrawRoundedBox"
DrawRoundedBox.angle = 4

function DrawRoundedBox:new(angle)
	DrawRoundedBox.super.new(self)
	if angle then self.angle = angle end
end

function DrawRoundedBox:draw(control)
	local angle = self.angle
	local x, y, w, h = control._localContentRect:unpack()
	love.graphics.rectangle("fill", x, y, w, h, angle, angle)
end

return DrawRoundedBox
