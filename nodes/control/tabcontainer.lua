---@type AdoreInit
local Adore = require ""
local Control = Adore.Nodes("Control")
local TabBar = Adore.Nodes("TabBar")
local tclear = Adore.Common("Structures").tableClear
local max = math.max

---@class TabContainer: Control
---@field super Control
---@overload fun(): TabContainer
local TabContainer = Control:extend()
TabContainer.CLASS_NAME = "TabContainer"
TabContainer.clipChildren = true
TabContainer.inputMode = "pass"
TabContainer.mouseInputMode = "pass"

---@type boolean # Shows a clickable tab bar that allows the user to switch tabs
TabContainer._showTabBar = true
---@type boolean # Should hidden tabs be used to calculate the minimum size?
TabContainer._useHiddenTabsForMinSize = false
---@type integer # The height of the tab bar
TabContainer._tabBarHeight = 26

function TabContainer:new()
	TabContainer.super.new(self)

	---@type integer # The current tab index
	self._currentTab = 0
	---@type integer # The padding around all elements
	self._padding = 0

	---@type TabBar # The internal tab bar
	self._internalTabBar = TabBar()
	self._internalTabBar:setAnchorsAndOffsets(
		0, 0, 1, 0,
		0, 0, 0, self._tabBarHeight
	)
	self._internalTabBar._adorePersist = false
	self._internalTabBar.tabSelected:connect(self, "_onTabSelected")
	self:addChild(self._internalTabBar)

	self.tabSelected = self:newSignal()
end

---Creates TabBar.TabInfo for the internal TabBar
---@param index integer
---@param child Node
---@return TabBar.TabInfo
function TabContainer:createTabInfo(index, child)
	return {
		name = child.name,
		node = child,
	}
end

---Updates the internal TabBar TabInfo array by repeatedly calling `:createTabInfo`
function TabContainer:updateTabs()
	local tabBar = self._internalTabBar
	local tabs = tabBar._tabs
	tclear(tabs)

	local children = self.children
	local nextIndex = 1
	local selectedTab = self._currentTab

	for i = 1, #children do
		local child = children[i]
		if child ~= tabBar then
			tabs[nextIndex] = self:createTabInfo(nextIndex, child)
			child:setVisible(selectedTab == nextIndex)
			nextIndex = nextIndex + 1
		end
	end

	if selectedTab == 0 and #tabs ~= 0 then
		-- Select a default tab
		tabBar:onTabInfoUpdated()
		self._internalTabBar:selectTab(1)
	elseif #tabs == 0 then
		self._internalTabBar:selectTab(0)
	end
end

function TabContainer:addChild(child)
	TabContainer.super.addChild(self, child)
	self:updateTabs()
	return self
end

function TabContainer:removeChildAtIndex(index, shouldDestroy)
	TabContainer.super.removeChildAtIndex(self, index, shouldDestroy)
	self:updateTabs()
end

function TabContainer:clearChildren(shouldDestroy)
	TabContainer.super.clearChildren(self, shouldDestroy)
	self:updateTabs()
end

function TabContainer:getMinimumSize()
	local minW, minH = TabContainer.super.getMinimumSize(self)
	if self._useHiddenTabsForMinSize then
		-- Use all children to get the minimum size
		local children = self.children
		for i = 1, #children do
			local child = children[i]
			if child:is(Control) then
				---@cast child Control
				local childMinW, childMinH = child:getMinimumSize()
				minW, minH = max(minW, childMinW), max(minH, childMinH)
			end
		end
	else
		-- Use the active child to get the minimum size
		local child = self.children[self._currentTab]
		if child and child:is(Control) then
			---@cast child Control
			local childMinW, childMinH = child:getMinimumSize()
			minW, minH = max(minW, childMinW), max(minH, childMinH)
		end
	end

	if self._showTabBar then
		minH = minH + TabContainer._tabBarHeight
	end

	local padding = self._padding * 2
	return minW + padding, minH + padding
end

function TabContainer:_simpleRefresh(child, w, h)
	local offsetY = 0
	if self._showTabBar and child ~= self._internalTabBar then
		offsetY = self._tabBarHeight
		h = max(0, h - offsetY)
	end
	local lcr = self._localContentRect
	local childX, childY, childW, childH = child:_getRectFromParentSize(w, h)
	child:_setCanonRect(childX + lcr.x, childY + lcr.y + offsetY, childW, childH)
	child:onRefreshed()
end

---Returns the Node that is active
---@return Node?
function TabContainer:getActiveTab()
	local index = self._currentTab
	local info = self._internalTabBar._tabs[index]
	if not info then return end
	---@type Node
	local node = info.node
	local children = self.children
	for i = 1, #children do
		if children[i] == node then return node end
	end
end

---Returns `true` if the specified tab index can be selected
---@param index integer
---@return boolean canSelect
function TabContainer:isSelectable(index)
	local child = self.children[index]
	if not child or not child:is(Control) or child == self._internalTabBar then return false end
	return true
end

---Called on the `tabSelected` signal fired by the internal TabBar
---@param _ TabBar
---@param index integer
---@return TabContainer
function TabContainer:_onTabSelected(_, index)
	self._currentTab = index
	local tabInfo = self._internalTabBar._tabs[index]
	self.tabSelected:fire(self, index, tabInfo)

	if tabInfo then
		local selectedChild = tabInfo.node

		local children = self.children
		for i = 1, #children do
			local child = children[i]
			child:setVisible(child == selectedChild)
		end
		self._internalTabBar:setVisible(self._showTabBar)
	end

	self:deferRefreshSelf()

	return self
end

---Sets the new active tab
---@param index integer | Node
---@return TabContainer
function TabContainer:selectTab(index)
	if type(index) == "table" then
		-- Find the child and set the index
		local tabs = self._internalTabBar._tabs
		for i = 1, #tabs do
			local tabInfo = tabs[i]
			if tabInfo.node == index then
				index = i
				break
			end
		end

	end
	---@cast index integer

	if type(index) ~= "number" then
		-- Didn't find it, select nothing
		self._internalTabBar:selectTab(1)
	else
		-- Found the index
		self._internalTabBar:selectTab(index)
	end
	return self
end

---Sets the padding around the elements
---@param padding integer
---@return TabContainer
function TabContainer:setPadding(padding)
	if self._padding ~= padding then
		self._padding = padding
		self:deferRefreshSelf()
	end
	return self
end

return TabContainer
