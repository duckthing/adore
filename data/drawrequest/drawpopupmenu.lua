---@type AdoreInit
local Adore = require ""
local DrawRequest = Adore.Resources("DrawRequest")
local mixRGBA = Adore.Common("Color").mixRGBA

---@class DrawRequest.PopupMenu: DrawRequest
local DrawPopupMenu = DrawRequest:extend()
DrawPopupMenu.CLASS_NAME = "DrawPopupMenu"

function DrawPopupMenu:new(angle, normalBackground, hoveredBackground, pressedBackground, normalText, hoveredText, pressedText)
	DrawPopupMenu.super.new(self)

	self.angle = angle or 4

	---@type integer[] # The unmixed background color of the panel
	self.normalBackground = normalBackground or {0.22, 0.22, 0.25, 1}
	---@type integer[] # The unmixed background color of a hovered item; will be drawn across the whole background
	self.hoveredBackground = hoveredBackground or {0.5, 0.5, 0.7, 0.4}
	---@type integer[] # The unmixed background color of a pressed item; will be drawn across the whole background
	self.pressedBackground = pressedBackground or {0.12, 0.12, 0.2, 0.6}

	---@type integer[] # The unmixed text color of an unhovered item
	self.normalText = normalText or {1, 1, 1, 0.75}
	---@type integer[] # The unmixed text color of a hovered item
	self.hoveredText = hoveredText or {1, 1, 1, 1}
	---@type integer[] # The unmixed text color of a pressed item
	self.pressedText = pressedText or {1, 1, 1, 0.5}
end

local t1 = {0, 0, 0, 0}
local t2 = {0, 0, 0, 0}

---@param menu PopupMenu
function DrawPopupMenu:draw(menu)
	local r, g, b, a = love.graphics.getColor()

	-- Draw the PopupMenu background
	local lcr = menu._localContentRect
	local x, y, w, h = lcr.x, lcr.y, lcr.w, lcr.h
	love.graphics.setColor(mixRGBA(r, g, b, a, unpack(self.normalBackground, 1, 4)))
	love.graphics.rectangle("fill", x, y, w, h, self.angle)

	local padding, margin = menu._padding, menu._margin
	local halfMargin = margin * 0.5
	local items = menu._items
	local font = menu._font[menu._fontSize]
	local offsetX = padding + x
	local offsetY = padding + y
	local itemHeight = font:getHeight() + margin
	local itemOffsetY = halfMargin

	local normalText = t1
	t1[1], t1[2], t1[3], t1[4] = mixRGBA(r, g, b, a, unpack(self.normalText))

	local hoveredBackground = self.hoveredBackground
	local hoveredText = t2

	if menu._pressed then
		-- Draw the background a little different if something is pressed
		hoveredBackground  =self.pressedBackground
		hoveredText = self.pressedText
	end

	t2[1], t2[2], t2[3], t2[4] = mixRGBA(r, g, b, a, unpack(self.hoveredText))

	local hoveredIndex = menu._hoveredIndex
	do
		local hoveredItem = items[hoveredIndex]
		if not (hoveredItem and not hoveredItem.separator) then
			-- It can't be highlighted
			hoveredIndex = 0
		end
	end

	-- Draw each item
	for i = 1, #items do
		local item = items[i]
		local isHovered = hoveredIndex == i

		if isHovered then
			love.graphics.setColor(mixRGBA(r, g, b, a, unpack(hoveredBackground, 1, 4)))
			love.graphics.rectangle("fill", x, offsetY, w, itemHeight)
		end

		if item.label then
			love.graphics.setColor(unpack(not isHovered and normalText or hoveredText))
			love.graphics.print(item.label, font, offsetX, offsetY + itemOffsetY)
		end
		offsetY = offsetY + itemHeight
	end
end

return DrawPopupMenu
