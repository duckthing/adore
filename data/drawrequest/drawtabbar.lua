---@type AdoreInit
local Adore = require ""
local DrawRequest = Adore.Resources("DrawRequest")
local FontLoader = Adore.Loader.getCollection("FontLoader")

---@class DrawRequest.TabBar: DrawRequest
---@overload fun(): DrawRequest.TabBar
local DrawTabBar = DrawRequest:extend()
DrawTabBar.CLASS_NAME = "DrawTabBar"

local DEFAULT_FONT = FontLoader:get("")
local DEFAULT_FONT_SIZE = 0

local SELECTED_COLOR = {1, 1, 1}
local DESELECTED_COLOR = {0.6, 0.6, 0.7}
---@type any[] # Used for colored text
local TEMP_INFO = {false, false}

function DrawTabBar:new()
end

---@param tabBar TabBar
function DrawTabBar:themeUpdate(tabBar)
	DrawTabBar.super.themeUpdate(self, tabBar)

	local textBatch = tabBar._textBatch
	local font = DEFAULT_FONT[DEFAULT_FONT_SIZE]
	textBatch:setFont(font)
	textBatch:clear()
	local tabs = tabBar._tabs
	local margin = tabBar._margin
	local offsetX = 0
	local offsetY = font:getHeight() * 0.5
	local selectedIndex = tabBar._currentTab

	for i = 1, #tabs do
		local tabInfo = tabs[i]

		TEMP_INFO[1], TEMP_INFO[2] =
			i == selectedIndex and SELECTED_COLOR or DESELECTED_COLOR,
			tabInfo.name
		textBatch:add(TEMP_INFO, offsetX, offsetY)

		tabInfo.lowerBoundX = offsetX
		offsetX = offsetX + textBatch:getWidth(i)
		tabInfo.upperBoundX = offsetX
		offsetX = offsetX + margin
	end
end

---@param tabBar TabBar
function DrawTabBar:draw(tabBar)
	love.graphics.setColor(1, 0, 0)
	local lcr = tabBar._localContentRect
	local x, y, w, h = lcr:unpack()
	love.graphics.rectangle("line", x, y, w, h)

	love.graphics.setColor(1, 1, 1)
	love.graphics.draw(tabBar._textBatch, x, y)
end

return DrawTabBar
