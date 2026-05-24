---@type AdoreInit
local Adore = require ""
local DrawRequest = Adore.Resources("DrawRequest")

---@class DrawRequest.Box: DrawRequest
local DrawBox = DrawRequest:extend()
DrawBox.CLASS_NAME = "DrawBox"

function DrawBox:draw(control)
	local lcr = control._localContentRect
	love.graphics.rectangle("fill", lcr.x, lcr.y, lcr.w, lcr.h)
end

return DrawBox
