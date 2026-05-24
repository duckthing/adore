---@type AdoreInit
local Adore = require ""
local Control = Adore.Nodes("Control")

---A MarginBox insets its children away from its own borders
---@class MarginBox: Control
---@field super Control
---@overload fun(): MarginBox
---@overload fun(allMargins: integer): MarginBox
---@overload fun(xMargin: integer, yMargin: integer): MarginBox
---@overload fun(leftMargin: integer, topMargin: integer, rightMargin: integer, bottomMargin: integer): MarginBox
local MarginBox = Control:extend()
MarginBox.CLASS_NAME = "MarginBox"

---@param a integer?
---@param b integer?
---@param c integer?
---@param d integer?
function MarginBox:new(a, b, c, d)
	MarginBox.super.new(self)

	---@type integer
	self._marginLeft, self._marginTop, self._marginRight, self._marginBottom
		= 0, 0, 0, 0

	self:setMargins(a, b, c, d)
end

---Quickly sets all margin values, and then refreshes its contents
---@param a integer?
---@param b integer?
---@param c integer?
---@param d integer?
---@overload fun(self): MarginBox
---@overload fun(self, allMargins: integer): MarginBox
---@overload fun(self, xMargin: integer, yMargin: integer): MarginBox
---@overload fun(self, leftMargin: integer, topMargin: integer, rightMargin: integer, bottomMargin: integer?): MarginBox
function MarginBox:setMargins(a, b, c, d)
	if a then
		if b then
			if c then
				-- `a`, `b`, `c`, `d?`
				self._marginLeft, self._marginTop, self._marginRight, self._marginBottom
					= a, b, c, d or 0
			else
				-- Only `a` and `b`; `a` is horizontal, while `b` is vertical
				self._marginLeft, self._marginTop, self._marginRight, self._marginBottom
					= a, b, a, b
			end
		else
			-- Only `a`
			self._marginLeft, self._marginTop, self._marginRight, self._marginBottom
				= a, a, a, a
		end
	else
		-- No parameters
		self._marginLeft, self._marginTop, self._marginRight, self._marginBottom
			= 0, 0, 0, 0
	end

	self:deferRefresh()
end

function MarginBox:forceRefresh()
	-- Inset the rect, and undo after refresh is done
	local lcr = self._localContentRect

	local oldX, oldY, oldW, oldH =
		lcr.x, lcr.y, lcr.w, lcr.h

	lcr.x = lcr.x + self._marginLeft
	lcr.y = lcr.y + self._marginTop
	lcr.w = lcr.w - self._marginRight
	lcr.h = lcr.h - self._marginBottom

	MarginBox.super.forceRefresh(self)

	lcr.x, lcr.y, lcr.w, lcr.h = oldX, oldY, oldW, oldH
end

return MarginBox
