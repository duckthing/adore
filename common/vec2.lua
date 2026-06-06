---@type ffilib
local ffi
local min, max = math.min, math.max
local sqrt = math.sqrt
local sin, cos = math.sin, math.cos
local atan2 = math.atan2

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

local Vec2MT
local equalCheck
if usingFFI then
ffi.cdef [[
typedef struct { double x, y; } avec2_t;
]]
	---@param self Vec2
	---@param other any
	---@return boolean
	equalCheck = function(self, other)
		if ffi.istype("avec2_t", other) then
			return self.x == other.x and self.y == other.y
		end
		return false
	end
else
	---@param self Vec2
	---@param other any
	---@return boolean
	equalCheck = function(self, other)
		if getmetatable(other) == Vec2MT then
			return self.x == other.x and self.y == other.y
		end
		return false
	end
end

---@type Vec2 # Calling this returns a new Vec2 (ex. `Vec2C(0, 0)`)
local Vec2C
---@type number # How close two Vec2s can be to be approximately equal
local DEFAULT_PRECISION_MARGIN = 0.001
---@type Vec2 # Used for calculations where an extra Vec2 is useful
local tempVec2

---@class Vec2: ffi.cdata*
---@field x number
---@field y number
---@operator add(Vec2): Vec2
---@operator sub(Vec2): Vec2
---@operator mul(Vec2): Vec2
---@operator mul(number): Vec2
---@operator div(Vec2): Vec2
---@operator div(number): Vec2
---@operator unm(): Vec2
---@overload fun(x: number?, y: number?): Vec2
local Vec2 = {}
-- There is no __call metamethod; it's annotated so the LSP stops complaining
Vec2MT = {
	__index = Vec2,
	__add = function(self, other)
		return Vec2C(self.x + other.x, self.y + other.y)
	end,
	__sub = function(self, other)
		return Vec2C(self.x - other.x, self.y - other.y)
	end,
	__mul = function(self, other)
		if type(other) == "number" then
			return Vec2C(self.x * other, self.y * other)
		else
			return Vec2C(self.x * other.x, self.y * other.y)
		end
	end,
	__div = function(self, other)
		if type(other) == "number" then
			return Vec2C(self.x / other, self.y / other)
		else
			return Vec2C(self.x / other.x, self.y / other.y)
		end
	end,
	__unm = function(self)
		return Vec2C(-self.x, -self.y)
	end,
	__eq = equalCheck,
	__tostring = function(self)
		return ("Vec2(%f, %f)"):format(self.x, self.y)
	end,
	__newindex = function(_, k, _)
		error(("Attempt to set index '%s' on type Vec2"):format(k))
	end,
}

---Returns the length squared
---@return number
function Vec2:getLength2()
	return self.x * self.x + self.y * self.y
end

---Returns the length
---@return number
function Vec2:getLength()
	return sqrt(self.x * self.x + self.y * self.y)
end

---Gets the distance to the other vector, squared
---@param other Vec2
---@return number distance
function Vec2:getDistance2(other)
	local dx, dy =
		(other.x - self.x),
		(other.y - self.y)
	return dx*dx + dy*dy
end

---Gets the distance to the other vector
---@param other Vec2
---@return number distance
function Vec2:getDistance(other)
	local dx, dy =
		(other.x - self.x),
		(other.y - self.y)
	return sqrt(dx*dx + dy*dy)
end

---Creates a new Vec2 that heads in the same direction as this one, but with a length of 1
---@return Vec2
function Vec2:getNormalized()
	local l = sqrt(self.x * self.x + self.y * self.y)
	if l > 0 then
		local factor = 1 / l
		return Vec2C(self.x * factor, self.y * factor)
	else
		return Vec2C(0, 0)
	end
end

---Returns true if this vector has a length of 1
---@return boolean normalized
function Vec2:isNormalized()
	local origin = self.x * self.x + self.y * self.y - 1
	return origin < DEFAULT_PRECISION_MARGIN and origin > -DEFAULT_PRECISION_MARGIN
end

---Returns true if this Vec2 has 0 in both components
---@return boolean isZero
function Vec2:isZero()
	return self.x == 0 and self.y == 0
end

---Returns true if this Vec2 is close to zero
---@param precision number?
---@return boolean isApproxZero
function Vec2:isApproxZero(precision)
	if not precision then precision = DEFAULT_PRECISION_MARGIN end
	return
		self.x > -precision and self.x < precision
		and
		self.y > -precision and self.y < precision
end

---Compares this Vec2 to X/Y components, if you can't use the basic comparison (vec == other)
---@param x number
---@param y number
---@return boolean areEqual
function Vec2:isEqual(x, y)
	return self.x == x and self.y == y
end

---Returns true if this Vec2 is approximately the same to another Vec2
---@param other Vec2
---@param precision number?
---@return boolean isApprox
function Vec2:isApprox(other, precision)
	if not precision then precision = DEFAULT_PRECISION_MARGIN end
	local dx, dy =
		self.x - other.x,
		self.y - other.y
	return
		dx > -precision and dx < precision
		and
		dy > -precision and dy < precision
end

---Returns both X and Y
---@return number x
---@return number y
function Vec2:getComponents()
	return self.x, self.y
end

---Returns the angle of this vector in radians, AS LONG AS IT'S NORMALIZED!
---@return number angle
function Vec2:getAngle()
	return atan2(self.y, self.x)
end

---(Normalizes this vector if required, and) returns its angle in radians
---@return number angle
function Vec2:getNormalizedAngle()
	if not self:isNormalized() then
		local v = self:getNormalized()
		return atan2(v.y, v.x)
	else
		return atan2(self.y, self.x)
	end
end

---Returns a new Vec2 that is equal to this Vec2's reflection off of Vec2 'n'
---@param n Vec2
---@return Vec2
function Vec2:getReflection(n)
	return self - 2 * (self:dot(n)) * n
end

---Returns a new Vec2 that is the inverse of this Vec2
---@return Vec2
function Vec2:getInverse()
	return Vec2C(1 / self.x, 1 / self.y)
end

---Returns a new Vec2 that is equal to this Vec2 rotated by an angle, in radians
---@param angle number
---@return Vec2 rotated
function Vec2:getRotated(angle)
	local sinResult, cosResult =
		sin(angle),
		cos(angle)
	return Vec2C(
		self.x * cosResult - self.y * sinResult,
		self.x * sinResult + self.y * cosResult
	)
end

---Returns a new Vec2 that is moved towards `to` by `amount`
---@param to Vec2
---@param amount number
---@return Vec2
function Vec2:getSteppedTowards(to, amount)
	tempVec2:iCopyVector(to):iSub(self)
	local length = tempVec2:getLength()
	if length ~= 0 then
		amount = max(0, min(amount, length))
		return self + tempVec2:iMult(amount / length)
	else
		-- Length is 0, can't step
		return Vec2C(0, 0)
	end
end

---Returns a new Vec2 that is `percent` between `self` and `to`
---@param to Vec2
---@param percent number
---@return Vec2
function Vec2:getLerped(to, percent)
	local diff = tempVec2:iCopyVector(to):iSub(self)
	return self + diff:iMult(max(0, min(percent, 1)))
end

---Returns the dot product between two normals/unit vectors.
---'1' means both normals are parallel and going the same direction, and '0' means they are perpendicular.
---@param other Vec2
---@return number
function Vec2:dot(other)
	return self.x * other.x + self.y * other.y
end

---[IN PLACE] Sets this Vec2's values to the other Vec2's values
---@param other Vec2
---@return Vec2 self
function Vec2:iCopyVector(other)
	self.x, self.y =
		other.x, other.y
	return self
end

---[IN PLACE] Sets this Vec2's values to the other Vec2's values
---@param x number
---@param y number
---@return Vec2 self
function Vec2:iSetComponents(x, y)
	self.x, self.y =
		x, y
	return self
end

---[IN PLACE] Adds two numbers to this Vec2
---@param x number
---@param y number
---@return Vec2 self
function Vec2:iAddComponents(x, y)
	self.x, self.y =
		self.x + x, self.y + y
	return self
end

---[IN PLACE] Subtracts two numbers from this Vec2
---@param x number
---@param y number
---@return Vec2 self
function Vec2:iSubComponents(x, y)
	self.x, self.y =
		self.x - x, self.y - y
	return self
end

---[IN PLACE] Multiplies two numbers into this Vec2
---@param x number
---@param y number
---@return Vec2 self
function Vec2:iMultComponents(x, y)
	self.x, self.y =
		self.x * x, self.y * y
	return self
end

---[IN PLACE] Divides two numbers from this Vec2
---(ex: `x, y = originalX / passedX, originalY / passedY`)
---@param x number
---@param y number
---@return Vec2 self
function Vec2:iDivComponents(x, y)
	self.x, self.y =
		self.x / x, self.y / y
	return self
end

---[IN PLACE] Adds another Vec2 onto this Vec2
---@param other Vec2
---@return Vec2 self
function Vec2:iAdd(other)
	self.x, self.y =
		self.x + other.x,
		self.y + other.y
	return self
end

---[IN PLACE] Subtracts another Vec2 from this Vec2
---@param other Vec2
---@return Vec2 self
function Vec2:iSub(other)
	self.x, self.y =
		self.x - other.x,
		self.y - other.y
	return self
end

---[IN PLACE] Multiplies this Vec2 against another Vec2 or number
---@param other Vec2 | number
---@return Vec2 self
function Vec2:iMult(other)
	if type(other) == "number" then
		self.x, self.y =
			self.x * other,
			self.y * other
	else
		self.x, self.y =
			self.x * other.x,
			self.y * other.y
	end
	return self
end

---[IN PLACE] Divides this Vec2 with another Vec2 or number
---@param other Vec2 | number
---@return Vec2 self
function Vec2:iDiv(other)
	if type(other) == "number" then
		local factor = 1 / other
		self.x, self.y =
			self.x * factor,
			self.y * factor
	else
		self.x, self.y =
			self.x / other.x,
			self.y / other.y
	end
	return self
end

---[IN PLACE] Negates each component, like putting a minus sign at the start of the Vec2
---@return Vec2 self
function Vec2:iUnary()
	self.x, self.y =
		-self.x,
		-self.y
	return self
end

---[IN PLACE] Normalizes this Vec2 by making its length equal to 1
---@return Vec2 self
function Vec2:iNormalize()
	local length = sqrt(self.x*self.x + self.y*self.y)
	if length == 0 then
		self.x, self.y = 0, 0
	else
		local factor = 1 / length
		self.x, self.y =
			self.x * factor,
			self.y * factor
	end
	return self
end

---[IN PLACE] Reflects this Vec2 off of Vec2 'n'
---@param n Vec2
---@return Vec2 self
function Vec2:iReflect(n)
	tempVec2:iCopyVector(n)
		:iMult(2 * self:dot(n))
	self:iSub(tempVec2)
	-- return self - 2 * (self:dot(n)) * n
	return self
end

---[IN PLACE] Sets this Vec2 to the reflection of `dir` off of 'n'
---@param dir Vec2
---@param n Vec2
---@return Vec2 self
function Vec2:iReflected(dir, n)
	tempVec2:iCopyVector(n)
		:iMult(2 * self:dot(n))
	self:iCopyVector(dir):iSub(tempVec2)
	-- return self - 2 * (self:dot(n)) * n
	return self
end

---[IN PLACE] Turns this Vec2 into an inverse of itself. (1 / vector)
---@return Vec2 self
function Vec2:iInverse()
	self.x, self.y =
		1 / self.x,
		1 / self.y
	return self
end

---[IN PLACE] Rotates this Vec2 by `angle`, in radians
---@param angle number
---@return Vec2 self
function Vec2:iRotate(angle)
	local sinResult, cosResult =
		sin(angle),
		cos(angle)
	self.x, self.y =
		self.x * cosResult - self.y * sinResult,
		self.x * sinResult + self.y * cosResult
	return self
end

---[IN PLACE] Sets this Vec2 to the rotation of `vec` by `angle`, in radians
---@param vec Vec2
---@param angle number
---@return Vec2 self
function Vec2:iRotated(vec, angle)
	local sinResult, cosResult =
		sin(angle),
		cos(angle)
	self.x, self.y =
		vec.x * cosResult - vec.y * sinResult,
		vec.x * sinResult + vec.y * cosResult
	return self
end

---[IN PLACE] Sets this Vec2 to the result of starting at `self` moving towards `to` by `amount`
---@param to Vec2
---@param amount number
---@return Vec2 self
function Vec2:iStep(to, amount)
	tempVec2:iCopyVector(to):iSub(self) -- the difference
	local length2 = tempVec2:getLength2()
	if length2 ~= 0 then
		-- Length is not 0, we can step
		local length = sqrt(length2)
		amount = max(0, min(amount, length))
		self:iAdd(tempVec2:iMult(amount / length))
	end
	return self
end

---[IN PLACE] Sets this Vec2 to a point that is `percent` between `self` and `to`
---@param to Vec2
---@param percent number
---@return Vec2 self
function Vec2:iLerp(to, percent)
	-- TODO: Figure out if we should clamp this and :step
	local diff = tempVec2:iCopyVector(to):iSub(self)
	diff:iMult(percent)
	self:iAdd(diff)
	return self
end

---Returns a clone of this Vec2
---@return Vec2
function Vec2:clone()
	return Vec2C(self.x, self.y)
end

---Returns the X and Y values as a tuple; opposite of `:iSetComponents()`
---@return number x
---@return number y
function Vec2:unpack()
	return self.x, self.y
end

if usingFFI then
	---Returns `true` if this value is a Vec2
	---@param vec any
	---@return boolean isVec2
	function Vec2.isVec2(vec)
		return ffi.istype(Vec2C, vec)
	end

	Vec2C = ffi.metatype("avec2_t", Vec2MT)
else
	function Vec2.isVec2(vec)
		return getmetatable(vec) == Vec2
	end

	---@diagnostic disable-next-line: cast-local-type
	Vec2C = function(x, y)
		return setmetatable({
			x = x or 0,
			y = y or 0
		}, Vec2MT)
	end
end

---@diagnostic disable-next-line: cast-local-type
tempVec2 = Vec2C(0, 0)
return Vec2C
