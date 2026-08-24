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

	---@type integer # How much wider a tab should be
	self._tabPadding = 12

	---@type TabBar.TabInfo[]
	self._tabs = {}
	---@type integer # The current tab index
	self._currentTab = 0
	---@type love.Text
	self._textBatch = love.graphics.newText(love.graphics.getFont())

	---@type Signal # Fires on tab de/selection
	self.tabSelected = self:newSignal()
end

function TabBar:forceRefresh()
	HBox.super.forceRefresh(self)
	local tabCount = #self._tabs
	if tabCount > 0 then
		-- Go to the last tab and make the width equal to its farthest point + padding
		self._calculatedWidth = self._tabs[tabCount].upperBoundX + self._padding
	else
		self._calculatedWidth = 0
	end
	self:setAllowScrolling(self._allowScrolling)
end

---Call this if the tab info changed
---@return self
function TabBar:onTabInfoUpdated()
	local selectedTab = self._currentTab
	local tabs = self._tabs
	if selectedTab == 0 and #tabs ~= 0 then
		-- Select a default tab when there isn't one
		self:selectTab(1)
	elseif #tabs == 0 then
		-- No tabs to select
		self:selectTab(0)
	elseif #tabs < selectedTab then
		-- Selected tab is greater than the existing tab count
		self:selectTab(#tabs)
	else
		-- Fire the selection event
		self._currentTab = 0
		self:selectTab(selectedTab)
	end
	self:deferRefreshSelf()
	return self
end

---Selects a certain tab index
---@param index integer
---@return self
function TabBar:selectTab(index)
	local newIndex = min(#self._tabs, index)
	if newIndex ~= self._currentTab then
		local newTab = self._tabs[newIndex]
		if newTab then
			-- Valid tab
			self._currentTab = newIndex
			self.tabSelected:fire(self, newIndex, newTab)
			-- TODO: Why is queue necessary?
			self:queue(self.focusOnTabIndex, newIndex)
			self:deferRefreshSelf()
		else
			-- Invalid tab
			self._currentTab = 0
			self.tabSelected:fire(self, 0, nil)
			self._offsetX = 0
			self:deferRefreshSelf()
		end
	end
	return self
end

---Moves the visible region to show a certain tab index
---@param index integer
function TabBar:focusOnTabIndex(index)
	local tab = self._tabs[index]
	if tab and tab.lowerBoundX then
		local width = self._localContentRect.w
		self._offsetX = max(
			-- min(to show the left side of the tab)
			-- min(the scroll position, the left edge of the tab, and to prevent scrolling past the edge)
			min(self._offsetX, tab.lowerBoundX, self._calculatedWidth - width),
			-- The right edge of the tab
			tab.upperBoundX - width,
			-- The lowest scroll
			0
		)
	end
end

function TabBar:mousepressed(mx, my, button, isTouch, pressCount)
	local tabs = self._tabs
	local lcr = self._localContentRect
	local offsetX = lcr.x
	local lx = mx - offsetX + self._offsetX
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
