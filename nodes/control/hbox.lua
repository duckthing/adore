---@type AdoreInit
local Adore = require ""
local Control = Adore.Nodes("Control")
local max = math.max

---@class HBox: Control
---@field super Control
---@overload fun(): HBox
local HBox = Control:extend()
HBox.CLASS_NAME = "HBox"
HBox.clipChildren = true
HBox.inputMode = "pass"
HBox.mouseInputMode = "pass"

---@type boolean # Whether we should resize this box to fit everything
HBox._resizeToContent = false
---@type boolean # Whether scrolling is allowed
HBox._allowScrolling = true
---@type VBox.SortMode # How the HBox sorts children
HBox._sortMode = "start"

function HBox:new()
	HBox.super.new(self)

	self._offsetX = 0
	self._calculatedWidth = 0
	self._calculatedHeight = 0
	self._margin = 0
	self._padding = 0
	self._scrollSpeed = 40
end

function HBox:forceRefresh()
	local lcr = self._localContentRect
	local selfX, selfY, selfW, selfH =
		lcr.x, lcr.y, lcr.w, lcr.h
	local margin = self._margin
	local padding = self._padding
	local containerW = self._padding * 2
	local containerH = 0

	local resizeToContent = self._resizeToContent
	local sortMode = self._sortMode

	if resizeToContent then
		selfH = 0
	end

	-- Calculate the size required
	for i = 1, #self.children do
		local child = self.children[i]
		if child:is(Control) and child._visible then
			---@cast child Control
			local _, childY, childW, childH = child:_getRectFromParentSize(selfW, selfH)
			containerW = containerW + childW
			containerH = math.max(containerH, childY + childH)
		end
	end
	containerW = containerW + (max(0, #self.children) - 1) * margin

	self._calculatedWidth = containerW
	self._calculatedHeight = containerH

	local chosenOffsetX
	if resizeToContent then
		selfH = containerH
		chosenOffsetX = 0
	else
		chosenOffsetX = math.max(0, math.min(self._offsetX, containerW - selfW))
	end

	local currX = selfX + -chosenOffsetX
	if sortMode == "start" then
		currX = currX + padding
	elseif sortMode == "center" then
		if containerW < selfW then
			currX = currX + (selfW - containerW) * 0.5
		end
	else
		if containerW < selfW then
			currX = currX + (selfW - containerW) - padding
		end
	end

	-- Set the positions of the children
	for _, child in ipairs(self.children) do
		if child:is(Control) and child._visible then
			---@cast child Control
			local _, offsetY, childW, childH = child:_getRectFromParentSize(selfW, selfH)

			child:_setCanonRect(currX, selfY + offsetY, childW, childH)
			child:onRefreshed()
			currX = currX + childW + margin
		end
	end

	if resizeToContent then
		self._localContentRect.h = containerW
	end

	self._offsetX = chosenOffsetX

	self:setAllowScrolling(self._allowScrolling)
end

function HBox:getMinimumSize()
	local minW, minH = HBox.super.getMinimumSize(self)
	if self._resizeToContent then
		minW = max(minW, self._calculatedWidth)
	end
	return minW, minH
end

function HBox:_focusOnChild(child)
	if self._allowScrolling then
		local lowerBounds = child._localContentRect.x - self._localContentRect.x + self._offsetX
		local upperBounds = lowerBounds - self._localContentRect.w + child._localContentRect.w
		self._offsetX = math.max(upperBounds, math.min(self._offsetX, lowerBounds))
		self:deferRefresh()
	end
	HBox.super._focusOnChild(self, child)
end

---Sets whether scrolling is allowed on this HBox
---@param allow boolean
---@return self
function HBox:setAllowScrolling(allow)
	self._allowScrolling = allow
	if allow then
		self.wheelmoved = HBox._hboxWheelMoved
	else
		self.wheelmoved = nil
	end
	return self
end

---Sets whether scrolling is allowed on this HBox
---@param resize boolean
---@return self
function HBox:setResizeToContent(resize)
	self._resizeToContent = resize
	self:deferRefreshSelf()
	return self
end

---Sets the margin between elements
---@param margin integer
---@return HBox
function HBox:setMargin(margin)
	self._margin = margin
	self:deferRefreshSelf()
	return self
end

---Sets the padding around the elements
---@param padding integer
---@return HBox
function HBox:setPadding(padding)
	self._padding = padding
	self:deferRefreshSelf()
	return self
end

---Sets the direction sorting occurs in
---@param sortMode VBox.SortMode
---@return HBox
function HBox:setSortMode(sortMode)
	if self._sortMode ~= sortMode then
		self._sortMode = sortMode
		self:deferRefreshSelf()
	end
	return self
end

---Set this to :wheelmoved() if scrolling is enabled
function HBox:_hboxWheelMoved(x, y)
	local newOffset = math.max(0, math.min(self._offsetX + (x - y) * self._scrollSpeed, self._calculatedWidth - self._localContentRect.h))
	if newOffset ~= self._offsetX then
		self._offsetX = newOffset
		self:deferRefresh()
		return true
	end
end

return HBox
