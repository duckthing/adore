---@type AdoreInit
local Adore = require ""
local Control = Adore.Nodes("Control")
local max = math.max

---@class GridBox: Control
---@field super Control
---@overload fun(): GridBox
local GridBox = Control:extend()
GridBox.CLASS_NAME = "GridBox"

function GridBox:new()
	GridBox.super.new(self)

	self._calculatedWidth = 0
	self._calculatedHeight = 0
end

function GridBox:forceRefresh()
	local lcr = self._localContentRect
	local selfX, selfY, selfW, selfH =
		lcr.x, lcr.y, lcr.w, lcr.h
	local children = self.children

	---@type number # The X position inside this row
	local rowX = 0
	---@type number # How far "down" we are
	local rowY = 0
	---@type number
	local largestW = 0
	---@type number # The tallest Control in this row
	local largestH = 0

	for i = 1, #children do
		local child = children[i]
		if child:is(Control) then
			---@cast child Control
			local _, _, cw, ch = child:_getRectFromParentSize(selfW, selfH)
			if rowX + cw > selfW and rowX ~= 0 then
				-- Move to the next row
				-- * If we're not at the start of it
				-- * And if there's not enough space for this child
				largestW = max(largestW, rowX)
				rowX = 0
				rowY = rowY + largestH
			end
			child:_setCanonRect(selfX + rowX, selfY + rowY, cw, ch)
			child:onRefreshed()
			rowX = rowX + cw
			largestH = max(largestH, ch)
		end
	end

	self._calculatedWidth, self._calculatedHeight =
		max(rowX, largestW),
		rowY + largestH
end

function GridBox:getMinimumSize()
	local minW, minH = GridBox.super.getMinimumSize(self)
	return max(minW, self._calculatedWidth), max(minH, self._calculatedHeight)
end

return GridBox
