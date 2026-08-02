---@type AdoreInit
local Adore = require ""
local DrawRequest = Adore.Resources("DrawRequest")
local FontLoader = Adore.Loader.getCollection("FontLoader")
local mixRGBA = Adore.Common("Color").mixRGBA

---@class DrawRequest.TabBar: DrawRequest
---@overload fun(barBackground: integer[], normalBackground: integer[], normalText: integer[], selectedBackground: integer[], selectedText: integer[]): DrawRequest.TabBar
local DrawTabBar = DrawRequest:extend()
DrawTabBar.CLASS_NAME = "DrawTabBar"

local DEFAULT_FONT = FontLoader:get("")
local DEFAULT_FONT_SIZE = 0

---@type any[] # Used for colored text
local TEMP_INFO = {false, false}

function DrawTabBar:new(barBackground, normalBackground, normalText, selectedBackground, selectedText)
	DrawTabBar.super.new(self)

	---@type integer[] # The unmixed background color of the tab bar
	self.barBackground = barBackground or {0.1, 0.1, 0.1, 1}

	---@type integer[] # The unmixed background color of a tab background
	self.normalBackground = normalBackground or {0.12, 0.12, 0.15, 1}
	---@type integer[] # The unmixed background color of a tab's text
	self.normalText = normalText or {1, 1, 1, 0.5}

	---@type integer[] # The unmixed background color of a selected tab background
	self.selectedBackground = selectedBackground or {0.15, 0.15, 0.2, 1}
	---@type integer[] # The unmixed background color of a selected tab's text
	self.selectedText = selectedText or {1, 1, 1, 0.75}
end

---@param tabBar TabBar
function DrawTabBar:themeUpdate(tabBar)
	DrawTabBar.super.themeUpdate(self, tabBar)

	local barH = tabBar._localContentRect.h
	local textBatch = tabBar._textBatch
	local font = DEFAULT_FONT[DEFAULT_FONT_SIZE]
	textBatch:setFont(font)
	textBatch:clear()
	local tabs = tabBar._tabs
	local margin = tabBar._margin
	local tabPadding = tabBar._tabPadding
	local offsetX = 0
	local offsetY = (barH - font:getHeight()) * 0.5
	local selectedIndex = tabBar._currentTab
	local selectedTextColor, normalTextColor =
		self.selectedText, self.normalText

	for i = 1, #tabs do
		local tabInfo = tabs[i]

		TEMP_INFO[1], TEMP_INFO[2] =
			i == selectedIndex and selectedTextColor or normalTextColor,
			tabInfo.name
		textBatch:add(TEMP_INFO, offsetX + tabPadding, offsetY)

		tabInfo.lowerBoundX = offsetX
		offsetX = offsetX + textBatch:getWidth(i) + tabPadding * 2
		tabInfo.upperBoundX = offsetX
		offsetX = offsetX + margin
	end
end

---@param tabBar TabBar
function DrawTabBar:draw(tabBar)
	local lcr = tabBar._localContentRect
	local x, y, w, h = lcr:unpack()
	local r, g, b, a = love.graphics.getColor()

	x = x - tabBar._offsetX

	-- Bar background
	love.graphics.setColor(mixRGBA(r, g, b, a, unpack(self.barBackground)))
	love.graphics.rectangle("fill", x, y, w, h)

	local tabs = tabBar._tabs
	local selectedIndex = tabBar._currentTab

	-- The selected background color
	local sr, sg, sb, sa = mixRGBA(r, g, b, a, unpack(self.selectedBackground))
	-- The unselected background color
	local nr, ng, nb, na = mixRGBA(r, g, b, a, unpack(self.normalBackground))

	for i = 1, #tabs do
		local tab = tabs[i]
		if i == selectedIndex then
			-- Selected color
			love.graphics.setColor(sr, sg, sb, sa)
		else
			-- Normal color
			love.graphics.setColor(nr, ng, nb, na)
		end

		local lower, upper = tab.lowerBoundX, tab.upperBoundX
		love.graphics.rectangle("fill", x + lower, y, upper - lower, h)
	end

	love.graphics.setColor(1, 1, 1)
	love.graphics.draw(tabBar._textBatch, x, y)
end

return DrawTabBar
