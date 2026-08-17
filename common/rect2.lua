---@type ffilib
local ffi
local min, max = math.min, math.max

local usingFFI = false

if ADORE_FORCE_FFI == nil then
	-- Global option to force FFI doesn't exist
	local success, jit = pcall(require, "_G.jit")
	if success then
		local enabled = jit.status()
		usingFFI = enabled
		ffi = require "_G.ffi"
	else
		-- Failed to load JIT
		usingFFI = false
	end
else
	usingFFI = ADORE_FORCE_FFI
end

if usingFFI then
ffi.cdef [[
typedef struct { double x, y, w, h; } arect2_t;
]]
end

---@type Rect2 # Calling this returns a new Rect2 (ex. `Rect2C(0, 0, 0, 0)`)
local Rect2C
---@type Rect2 # Used for calculations where an extra Rect2 is useful
local tempRect2

---@class Rect2: ffi.cdata*
---@field x number
---@field y number
---@field w number
---@field h number
---@overload fun(x: number?, y: number?, w: number?, h: number?): Rect2
local Rect2 = {}
local Rect2MT = {
	__index = Rect2,
	__tostring = function(self)
		return ("Rect2(%f, %f, %f, %f)"):format(self.x, self.y, self.w, self.h)
	end,
}

---Returns the bounds of the Rect2
---@return number left
---@return number top
---@return number right
---@return number bottom
function Rect2:getBounds()
	local x, y, w, h = self.x, self.y, self.w, self.h
	local left, top, right, bottom = x, y, x + w, y + h
	if right < left then left, right = right, left end
	if bottom < top then top, bottom = bottom, top end
	return left, top, right, bottom
end

---Returns a new Rect2 with the width and height made positive
---@return Rect2
function Rect2:getAbs()
	local x, y, w, h = self.x, self.y, self.w, self.h
	if w < 0 then x, w = x + w, -w end
	if h < 0 then y, h = y + h, -h end
	return Rect2C(x, y, w, h)
end

---Returns the center of the Rect2
---@return number cx
---@return number cy
function Rect2:getCenter()
	local x, y, w, h = self.x, self.y, self.w, self.h
	return x + w * 0.5, y + h * 0.5
end

---Returns the transformed points of this Rect2. Useful for getting the bounding box of a rotated and scaled object.
---@param globalTransform love.Transform
---@return number x
---@return number y
---@return number w
---@return number h
function Rect2:transformBox(globalTransform)
	local ox, oy, ow, oh =
		self.x, self.y, self.w, self.h
	local oRight, oBottom =
		ox + ow,
		oy + oh

	-- Top left
	local ax, ay = globalTransform:transformPoint(ox, oy)
	-- Top right
	local bx, by = globalTransform:transformPoint(oRight, oy)
	-- Bottom left
	local cx, cy = globalTransform:transformPoint(ox, oBottom)
	-- Bottom right
	local dx, dy = globalTransform:transformPoint(oRight, oBottom)

	-- Get the new bounding box + size
	local newLeft, newTop, newRight, newBottom =
		min(ax, bx, cx, dx),
		min(ay, by, cy, dy),
		max(ax, bx, cx, dx),
		max(ay, by, cy, dy)
	local newW, newH =
		newRight - newLeft,
		newBottom - newTop

	return newLeft, newTop, newW, newH
end

---Applies the inverse of a transform to this Rect2. Useful for getting the bounding box of a rotated and scaled object.
---@param globalTransform love.Transform
---@return number x
---@return number y
---@return number w
---@return number h
function Rect2:inverseTransformBox(globalTransform)
	local ox, oy, ow, oh =
		self.x, self.y, self.w, self.h
	local oRight, oBottom =
		ox + ow,
		oy + oh

	-- Top left
	local ax, ay = globalTransform:inverseTransformPoint(ox, oy)
	-- Top right
	local bx, by = globalTransform:inverseTransformPoint(oRight, oy)
	-- Bottom left
	local cx, cy = globalTransform:inverseTransformPoint(ox, oBottom)
	-- Bottom right
	local dx, dy = globalTransform:inverseTransformPoint(oRight, oBottom)

	-- Get the new bounding box + size
	local newLeft, newTop, newRight, newBottom =
		min(ax, bx, cx, dx),
		min(ay, by, cy, dy),
		max(ax, bx, cx, dx),
		max(ay, by, cy, dy)
	local newW, newH =
		newRight - newLeft,
		newBottom - newTop

	return newLeft, newTop, newW, newH
end

---[IN PLACE] Sets the components of this Rect2
---@param x number
---@param y number
---@param w number
---@param h number
---@return self
function Rect2:iSetComponents(x, y, w, h)
	self.x, self.y, self.w, self.h =
		x, y, w, h
	return self
end

---[IN PLACE] Sets the components of this Rect2
---@param topLeftX number
---@param topLeftY number
---@param bottomRightX number
---@param bottomRightY number
---@return self
function Rect2:iSetFromPoints(topLeftX, topLeftY, bottomRightX, bottomRightY)
	local w, h = bottomRightX - topLeftX, bottomRightY - topLeftY
	self.x, self.y, self.w, self.h =
		topLeftX, topLeftY, w, h
	return self
end

---[IN PLACE] Sets this Rect2's components equal to another Rect2
---@param other Rect2
---@return self
function Rect2:iCopyRect(other)
	self.x, self.y, self.w, self.h =
		other.x, other.y, other.w, other.h
	return self
end

---[IN PLACE] Applies a transform to this Rect2. Useful for getting the bounding box of a rotated and scaled object.
---@param globalTransform love.Transform
---@return self
function Rect2:iTransformBox(globalTransform)
	self.x, self.y, self.w, self.h =
		self:transformBox(globalTransform)
	return self
end

---[IN PLACE] Applies the inverse of a transform to this Rect2. Useful for getting the bounding box of a rotated and scaled object.
---@param globalTransform love.Transform
---@return self
function Rect2:iInverseTransformBox(globalTransform)
	self.x, self.y, self.w, self.h =
		self:inverseTransformBox(globalTransform)
	return self
end

---[IN PLACE] Makes this Rect2's width and height positive while keeping the original dimensions.
---@return self
function Rect2:iAbs()
	local x, y, w, h = self.x, self.y, self.w, self.h
	if w < 0 then x, w = x + w, -w end
	if h < 0 then y, h = y + h, -h end
	self.x, self.y, self.w, self.h = x, y, w, h
	return self
end

---[IN PLACE] Sets this Rect2 to a dimension that is `percent` between `self` and `to`
---@param to Rect2
---@param percent number
---@return Rect2 self
function Rect2:iLerp(to, percent)
	local diff = tempRect2:iCopyRect(to)
	diff.x, diff.y, diff.w, diff.h =
		(to.x - diff.x) * percent,
		(to.y - diff.y) * percent,
		(to.w - diff.w) * percent,
		(to.h - diff.h) * percent

	self.x, self.y, self.w, self.h =
		self.x + diff.x,
		self.y + diff.y,
		self.w + diff.w,
		self.h + diff.h
	return self
end

---[IN PLACE] Expands the Rect2 to include (px, py). If the point is outside of the bounds, this method does nothing.
---@param px number
---@param py number
function Rect2:iExpandTowards(px, py)
	local x, y, w, h = self.x, self.y, self.w, self.h
	local right, bottom =
		x + w,
		y + h

	if px < x then
		-- Add the difference...
		self.w = w + x - px
		-- And set x to px
		self.x = px
	elseif px > right then
		-- Add the difference
		self.w = w + px - right
	end

	if py < y then
		-- Add the difference...
		self.h = h + y - py
		-- And set y to py
		self.y = py
	elseif py > bottom then
		-- Add the difference
		self.h = h + py - bottom
	end

	return self
end

---Returns a clone of this Rect2
---@return Rect2
function Rect2:clone()
	return Rect2C(self.x, self.y, self.w, self.h)
end

---Returns all components as a tuple
---@return number x
---@return number y
---@return number w
---@return number h
function Rect2:unpack()
	return self.x, self.y, self.w, self.h
end

---Returns `true` if `other` overlaps with this Rect2
---@param other Rect2
---@return boolean overlapping
function Rect2:overlapping(other)
	local selfX, selfY = self.x, self.y
	local otherX, otherY = other.x, other.y

	return
		selfX < otherX + other.w and selfX + self.w > otherX
	and selfY < otherY + other.h and selfY + self.h > otherY
end

---Returns `true` if `other` is completely inside of this Rect2.
---A clone of this Rect2 will return `true`, as comparisons can be equal.
---@param other Rect2
---@return boolean encloses
function Rect2:encloses(other)
	local selfX, selfY = self.x, self.y
	local otherX, otherY = other.x, other.y
	return
		selfX <= otherX and selfX + self.w >= otherX + other.w
	and selfY <= otherY and selfY + self.h >= otherY + other.h
end

---Returns `true` if the point lies on or inside of the Rect2
---@param x number
---@param y number
---@return boolean contained
function Rect2:containsPoint(x, y)
	local sx, sy = self.x, self.y
	return
		x >= sx and x <= sx + self.w
		and
		y >= sy and y <= sy + self.h
end

if usingFFI then
	---Returns `true` if this value is a Rect2
	---@param rect any
	---@return boolean isRect2
	function Rect2.isRect2(rect)
		return ffi.istype(Rect2C, rect)
	end

	Rect2C = ffi.metatype("arect2_t", Rect2MT)
else
	function Rect2.isRect2(rect)
		return getmetatable(rect) == Rect2
	end

	---@diagnostic disable-next-line: cast-local-type
	Rect2C = function(x, y, w, h)
		return setmetatable({
			x = x or 0,
			y = y or 0,
			w = w or 0,
			h = h or 0
		}, Rect2MT)
	end
end

tempVec2 = Rect2C(0, 0, 0, 0)
return Rect2C
