---@type AdoreInit
local Adore = require ""
local DrawRequest = Adore.Resources("DrawRequest")

---@class DrawRequest.PopupMenu: DrawRequest
local DrawPopupMenu = DrawRequest:extend()
DrawPopupMenu.CLASS_NAME = "DrawPopupMenu"

---@param menu PopupMenu
function DrawPopupMenu:draw(menu)
	love.graphics.setColor(0.1, 0.1, 0.15)
	local lcr = menu._localContentRect
	local x, y, w, h = lcr.x, lcr.y, lcr.w, lcr.h
	love.graphics.rectangle("fill", x, y, w, h)

	local padding, margin = menu._padding, menu._margin
	local items = menu._items
	local font = menu._font[menu._fontSize]
	local offsetX = padding + x
	local offsetY = padding + y
	local itemHeight = font:getHeight() + margin
	local itemOffsetY = 0

	love.graphics.setColor(1, 1, 1)
	for i = 1, #items do
		local item = items[i]
		if item.label then
			love.graphics.print(item.label, font, offsetX, offsetY + itemOffsetY)
		end
		offsetY = offsetY + itemHeight
	end
end

return DrawPopupMenu
