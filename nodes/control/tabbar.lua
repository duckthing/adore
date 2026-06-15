---@type AdoreInit
local Adore = require ""
local HBox = Adore.Nodes("HBox")
local min, max = math.min, math.max

---@class TabBar: HBox
---@override fun(): TabBar
local TabBar = HBox:extend()
TabBar.CLASS_NAME = "TabBar"

---@class TabBar.TabInfo
---@field name string?
---@field icon TextureSource?
---@field lowerBoundX integer? # Used for checking overlap with mouse
---@field upperBoundX integer? # Used for checking overlap with mouse

function TabBar:new()
	TabBar.super.new(self)
	self._margin = 4

	---@type TabBar.TabInfo[]
	self._tabs = {}
	---@type integer # The current tab index
	self._currentTab = 0
	---@type love.Text
	self._textBatch = love.graphics.newText(love.graphics.getFont())

	---@type Signal # Fires on tab de/selection
	self.tabSelected = self:newSignal()
end

---Call this if the tab info changed
---@return self
function TabBar:updateTabs()
	self:deferRefreshSelf()
	return self
end

---Selects a certain tab index
---@param index integer
---@return self
function TabBar:selectTab(index)
	local newIndex = min(#self._tabs, index)
	if newIndex ~= self._currentTab then
		self._currentTab = newIndex
		local newTab = self._tabs[newIndex]
		self.tabSelected:fire(self, newIndex, newTab)
		self:deferRefreshSelf()
	end
	return self
end

function TabBar:mousepressed(mx, my, button, isTouch, pressCount)
	local tabs = self._tabs
	local lcr = self._localContentRect
	local offsetX = lcr.x
	local lx = mx - offsetX
	for i = 1, #tabs do
		local tabInfo = tabs[i]
		if lx > tabInfo.lowerBoundX then
			if lx < tabInfo.upperBoundX then
				self:selectTab(i)
				return true
			end
		else
			-- Nothing later than this will be selected by this click
			return false
		end
	end

	-- Nothing to select
	return false
end

return TabBar
