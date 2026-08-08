---@type AdoreInit
local Adore = require ""
local Control = Adore.Nodes("Control")
local min, max = math.min, math.max

---@class VBox: Control
---@field super Control
---@overload fun(): VBox
local VBox = Control:extend()
VBox.CLASS_NAME = "VBox"
VBox.clipChildren = true
VBox.inputMode = "pass"
VBox.mouseInputMode = "pass"

---@type boolean # Whether we should resize this box to fit everything
VBox._resizeToContent = false
---@type boolean # Whether scrolling is allowed
VBox._allowScrolling = true
---@type VBox.SortMode # How the VBox sorts children
VBox._sortMode = "start"

---@alias VBox.SortMode
---| "start"
---| "center"
---| "end"

function VBox:new()
	VBox.super.new(self)

	self._offsetY = 0
	self._calculatedWidth = 0
	self._calculatedHeight = 0
	self._margin = 0
	self._padding = 0
	self._scrollSpeed = 40
end

function VBox:forceRefresh()
	local lcr = self._localContentRect
	local selfX, selfY, selfW, selfH =
		lcr.x, lcr.y, lcr.w, lcr.h
	local margin = self._margin
	local padding = self._padding
	local containerW = 0
	local containerH = padding * 2

	local resizeToContent = self._resizeToContent
	local sortMode = self._sortMode

	if resizeToContent then
		selfH = 0
	end

	-- Calculate the size required
	local children = self.children
	for i = 1, #children do
		local child = children[i]
		if child:is(Control) and child._visible then
			---@cast child Control
			local childX, _, childW, childH = child:_getRectFromParentSize(selfW, 0)
			containerW = max(containerW, childX + childW)
			containerH = containerH + childH
		end
	end
	containerH = containerH + (max(0, #children) - 1) * margin

	self._calculatedWidth = containerW
	self._calculatedHeight = containerH

	local chosenOffsetY
	if resizeToContent then
		selfH = containerH
		chosenOffsetY = 0
	else
		chosenOffsetY = max(0, min(self._offsetY, containerH - selfH))
	end

	local currY = selfY + -chosenOffsetY
	if sortMode == "start" then
		currY = currY + padding
	elseif sortMode == "center" then
		if containerH < selfH then
			currY = currY + (selfH - containerH) * 0.5
		end
	else
		if containerH < selfH then
			currY = currY + (selfH - containerH) - padding
		end
	end

	-- Set the positions of the children
	for i = 1, #children do
		local child = children[i]
		if child:is(Control) and child._visible then
			---@cast child Control
			local offsetX, _, childW, childH = child:_getRectFromParentSize(selfW, selfH)

			child:_setCanonRect(selfX + offsetX, currY, childW, childH)
			child:onRefreshed()
			currY = currY + childH + margin
		end
	end

	if resizeToContent then
		self._localContentRect.h = max(self._localContentRect.h, containerH)
	end

	self._offsetY = chosenOffsetY

	self:setAllowScrolling(self._allowScrolling)
end

function VBox:getMinimumSize()
	local minW, minH = VBox.super.getMinimumSize(self)
	if self._resizeToContent then
		minH = max(minH, self._calculatedHeight)
	end
	return minW, minH
end

function VBox:_focusOnChild(child)
	if self._allowScrolling then
		local lowerBounds = child._localContentRect.y - self._localContentRect.y + self._offsetY
		local upperBounds = lowerBounds - self._localContentRect.h + child._localContentRect.h
		-- lowerbounds is less than upperbounds (reversed)
		self._offsetY = max(upperBounds, min(self._offsetY, lowerBounds))
		self:deferRefresh()
	end
	VBox.super._focusOnChild(self, child)
end

---Sets whether scrolling is allowed on this VBox
---@param allow boolean
---@return self
function VBox:setAllowScrolling(allow)
	self._allowScrolling = allow
	if allow then
		self.wheelmoved = VBox._vboxWheelMoved
	else
		self.wheelmoved = nil
	end
	return self
end

---Sets whether this VBox will resize to fit all content
---@param resize boolean
---@return self
function VBox:setResizeToContent(resize)
	if self._resizeToContent ~= resize then
		self._resizeToContent = resize
		self:deferRefreshSelf()
	end
	return self
end

---Sets the margin between elements
---@param margin integer
---@return VBox
function VBox:setMargin(margin)
	if self._margin ~= margin then
		self._margin = margin
		self:deferRefreshSelf()
	end
	return self
end

---Sets the padding around the elements
---@param padding integer
---@return VBox
function VBox:setPadding(padding)
	if self._padding ~= padding then
		self._padding = padding
		self:deferRefreshSelf()
	end
	return self
end

---Sets the direction sorting occurs in
---@param sortMode VBox.SortMode
---@return VBox
function VBox:setSortMode(sortMode)
	if self._sortMode ~= sortMode then
		self._sortMode = sortMode
		self:deferRefreshSelf()
	end
	return self
end

---Set this to :wheelmoved() if scrolling is enabled
function VBox:_vboxWheelMoved(_, y)
	local newOffset = max(0, min(self._offsetY - y * self._scrollSpeed, self._calculatedHeight - self._localContentRect.h))
	if newOffset ~= self._offsetY then
		self._offsetY = newOffset
		self:deferRefresh()
		return true
	end
end

function VBox._addDefinition(entry)
	entry:newBoolean("_resizeToContent", false, "setResizeToContent")
	entry:newBoolean("_allowScrolling", true, "setAllowScrolling")
	local sortModes = {
		start = true,
		center = true,
		["end"] = true,
	}
	entry:newEnum("_sortMode", sortModes, "start", "setSortMode")
	entry:newNumber("_margin", 0, 0, nil, nil, "setMargin")
	entry:newNumber("_padding", 0, 0, nil, nil, "setPadding")
end

return VBox
