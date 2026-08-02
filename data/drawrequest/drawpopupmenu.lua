---@type AdoreInit
local Adore = require ""
local DrawRequest = Adore.Resources("DrawRequest")
local mixRGBA = Adore.Common("Color").mixRGBA

---@class DrawRequest.PopupMenu: DrawRequest
---@overload fun(angle: number, panelBackground: number[], hoveredBackground: number[], pressedBackground: number[], normalText: number[], hoveredText: number[], pressedText: number[]): DrawRequest.PopupMenu
local DrawPopupMenu = DrawRequest:extend()
DrawPopupMenu.CLASS_NAME = "DrawPopupMenu"

function DrawPopupMenu:new(angle, panelBackground, hoveredBackground, pressedBackground, normalText, hoveredText, pressedText)
	DrawPopupMenu.super.new(self)

	self.angle = angle or 4

	---@type number[] # The background color of the entire panel
	self.panelBackground = panelBackground or {0.22, 0.22, 0.25, 1}

	---@type number[] # The background color of a hovered item; will be drawn over the background
	self.hoveredBackground = hoveredBackground or {0.5, 0.5, 0.7, 0.4}
	---@type number[] # The background color of a pressed item; will be drawn over the background
	self.pressedBackground = pressedBackground or {0.12, 0.12, 0.2, 0.6}

	---@type number[] # The text color of an unhovered item
	self.normalText = normalText or {1, 1, 1, 0.75}
	---@type number[] # The text color of a hovered item
	self.hoveredText = hoveredText or {1, 1, 1, 1}
	---@type number[] # The text color of a pressed item
	self.pressedText = pressedText or {1, 1, 1, 0.5}
end

local t1 = {0, 0, 0, 0}
local t2 = {0, 0, 0, 0}
local t3 = {0, 0, 0, 0}

---@param menu PopupMenu
function DrawPopupMenu:draw(menu)
	local r, g, b, a = love.graphics.getColor()

	-- Draw the PopupMenu background
	local lcr = menu._localContentRect
	local x, y, w, h = lcr.x, lcr.y, lcr.w, lcr.h
	love.graphics.setColor(mixRGBA(r, g, b, a, unpack(self.panelBackground, 1, 4)))
	love.graphics.rectangle("fill", x, y, w, h, self.angle)

	local padding, margin = menu._padding, menu._margin
	local halfMargin = margin * 0.5
	local items = menu._items
	local font = menu._font[menu._fontSize]
	local offsetX = padding + x
	local offsetY = padding + y
	local itemHeight = font:getHeight() + margin
	local itemOffsetY = halfMargin

	---@type number[] # The color of unhovered text
	local normalText = t1
	t1[1], t1[2], t1[3], t1[4] = mixRGBA(r, g, b, a, unpack(self.normalText))

	---@type number[] # The color of the hovered item background
	local hoveredBackground = t2
	---@type number[] # The color of hovered text
	local hoveredText = t3

	do
		-- Add the hovered colors into the table
		local rawBackground = self.hoveredBackground
		local rawText = self.hoveredText

		if menu._pressed then
			-- Recolor the item a little different if the hovered item is pressed down
			rawBackground = self.pressedBackground
			rawText = self.pressedText
		end

		t2[1], t2[2], t2[3], t2[4] = mixRGBA(r, g, b, a, unpack(rawBackground))
		t3[1], t3[2], t3[3], t3[4] = mixRGBA(r, g, b, a, unpack(rawText))
	end


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
			love.graphics.setColor(hoveredBackground)
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
