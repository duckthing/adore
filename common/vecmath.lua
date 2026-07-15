---@class VecMath
local VecMath = {}
local sqrt = math.sqrt
local min, max = math.min, math.max
local sin, cos = math.sin, math.cos

---Returns the squared length of a vector. Faster, due to not square rooting the result.
---@param x number
---@param y number length2
---@return number length2
local function length2(x, y)
	return x*x + y*y
end

---Returns the length of a vector. Slower than length2.
---@param x number
---@param y number
---@return number length
local function length(x, y)
	return sqrt(x*x + y*y)
end

---Returns the squared distance from one vector to another
---@param ax number
---@param ay number
---@param bx number
---@param by number
---@return number distance2
local function distance2(ax, ay, bx, by)
	local dx, dy =
		(bx - ax),
		(by - ay)
	return dx*dx + dy*dy
end

---Returns the distance from one vector to another
---@param ax number
---@param ay number
---@param bx number
---@param by number
---@return number distance
local function distance(ax, ay, bx, by)
	local dx, dy =
		(bx - ax),
		(by - ay)
	return sqrt(dx*dx + dy*dy)
end

---Returns true if the vector has a length of 1
---@param x number
---@param y number
---@param deadzone number? # Used for approximation
---@return boolean
local function isUnit(x, y, deadzone)
	deadzone = deadzone or 0.01
	local l = x*x + y*y
	return l > 1 - deadzone and l < 1 + deadzone
end

---Converts any vector into a unit vector (length of 1)
---@param x number
---@param y number
---@return number ux
---@return number uy
local function normalize(x, y)
	local l = sqrt(x*x + y*y)
	if l > 0 then
		local factor = 1 / l
		return x * factor, y * factor
	else
		return 0, 0
	end
end

---Returns the dot product between two normals/unit vectors.
---'1' means both normals are parallel and going the same direction, and '0' means they are perpendicular.
---@param ax number
---@param ay number
---@param bx number
---@param by number
local function dot(ax, ay, bx, by)
	return ax * bx + ay * by
end

---Steps from (ax, ay) to (bx, by) by `amount`
---@param ax number
---@param ay number
---@param bx number
---@param by number
---@param amount number
---@return number x
---@return number y
local function step(ax, ay, bx, by, amount)
	local dx, dy =
		bx - ax,
		by - ay
	local len2 = length2(dx, dy)
	if len2 ~= 0 then
		-- Length is not 0, we can step
		local len = sqrt(len2)
		amount = max(0, min(amount, len))
		local percent = amount / len
		return
			ax + (dx * percent),
			ay + (dy * percent)
	end
	return ax, ay
end

---Returns the coordinates that is `percent` between `(ax, ay)` and `(bx, by)`
---@param ax number
---@param ay number
---@param bx number
---@param by number
---@param percent number
---@return number x
---@return number y
local function lerp(ax, ay, bx, by, percent)
	local dx, dy =
		bx - ax,
		by - ay
	return
		ax + dx * percent,
		ay + dy * percent
end

---Reflects vector (x, y) off of (nx, ny)
---@param x number
---@param y number
---@param nx number
---@param ny number
---@return number rx
---@return number ry
local function reflect(x, y, nx, ny)
	local dnx, dny = dot(x, y, nx, ny)
	return x - 2 * dnx * nx,
		y - 2 * dny * ny
end

---Returns the inverse of (x, y), which will equal (1, 1) when multiplied by (x, y)
local function inverse(x, y)
	local ix, iy = 0, 0
	if x ~= 0 then
		ix = 1 / x
	end
	if y ~= 0 then
		iy = 1 / y
	end
	return ix, iy
end

---Rotates a vector (x, y) by `angle`, in radians
---@param x number
---@param y number
---@param angle number
local function rotated(x, y, angle)
	local sinResult, cosResult =
		sin(angle),
		cos(angle)
	return x * cosResult - y * sinResult,
		x * sinResult + y * cosResult
end

VecMath.length2 = length2
VecMath.length = length
VecMath.distance2 = distance2
VecMath.distance = distance
VecMath.isUnit = isUnit
VecMath.normalize = normalize
VecMath.dot = dot
VecMath.step = step
VecMath.lerp = lerp
VecMath.reflect = reflect
VecMath.inverse = inverse
VecMath.rotated = rotated

return VecMath
