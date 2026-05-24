---@type AdoreInit
local Adore = require ""
local DrawRequest = Adore.Resources("DrawRequest")

---@class DrawRequest.DebugBox: DrawRequest
local DrawBox = DrawRequest:extend()
DrawBox.CLASS_NAME = "DrawDebugBox"

---@param t table
---@return string
local function getPointer(t)
	local mt = getmetatable(t)
	local pointer = tostring(setmetatable(t, nil))
	setmetatable(t, mt)
	return pointer
end

local factor = 0.00392156862745098

local lineWidth = 2
local doubleLineWidth = lineWidth * 2

function DrawBox:draw(control)
	local lcr = control._localContentRect

	local pointer = getPointer(control)
	local sum = 0
	for i = 1, #pointer do
		sum = sum + pointer:byte(i, i)
	end

	local r, g, b =
		factor * ((sum *  3) % 255),
		factor * ((sum *  7) % 255),
		factor * ((sum * 13) % 255)

	love.graphics.setColor(r, g, b, 0.6)
	love.graphics.setLineWidth(lineWidth)
	love.graphics.rectangle("line", lcr.x + lineWidth, lcr.y + lineWidth, lcr.w - doubleLineWidth, lcr.h - doubleLineWidth)
end

return DrawBox
