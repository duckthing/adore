---@type AdoreInit
local Adore = require ""
local DrawRequest = Adore.Resources("DrawRequest")
local FontLoader = Adore.Loader.getCollection("FontLoader")

---@class DrawRequest.TabBar: DrawRequest
---@overload fun(normalBackground: integer[], normalText: integer[], selectedBackground: integer[], selectedText: integer[]): DrawRequest.TabBar
local DrawTabBar = DrawRequest:extend()
DrawTabBar.CLASS_NAME = "DrawTabBar"

local DEFAULT_FONT = FontLoader:get("")
local DEFAULT_FONT_SIZE = 0

---@type any[] # Used for colored text
local TEMP_INFO = {false, false}

function DrawTabBar:new(normalBackground, normalText, selectedBackground, selectedText)
	DrawTabBar.super.new(self)

	---@type integer[] # The unmixed background color of a tab background
	self.normalBackground = normalBackground or {0.12, 0.12, 0.15}
	---@type integer[] # The unmixed background color of a tab's text
	self.normalText = normalText or {1, 1, 1, 0.5}

	---@type integer[] # The unmixed background color of a selected tab background
	self.selectedBackground = selectedBackground or {0.15, 0.15, 0.2}
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
	love.graphics.setColor(1, 0, 0)
	local lcr = tabBar._localContentRect
	local x, y, _, h = lcr:unpack()

	local tabs = tabBar._tabs
	local selectedIndex = tabBar._currentTab
	local selectedBackgroundColor, normalBackgroundColor =
		self.selectedBackground, self.normalBackground
	for i = 1, #tabs do
		local tab = tabs[i]
		love.graphics.setColor((i == selectedIndex and selectedBackgroundColor) or normalBackgroundColor)

		local lower, upper = tab.lowerBoundX, tab.upperBoundX
		love.graphics.rectangle("fill", x + lower, y, upper - lower, h)
	end

	love.graphics.setColor(1, 1, 1)
	love.graphics.draw(tabBar._textBatch, x, y)
end

return DrawTabBar
