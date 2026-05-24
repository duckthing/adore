---@type AdoreInit
local Adore = require ""

---@class VecMath
local VecMath = {}
---@type Vec2
local Vec2 = Adore.Common("Vec2")
local sqrt = math.sqrt
local min, max = math.min, math.max

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
			ax + (bx * percent),
			ay + (bx * percent)
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

VecMath.length2 = length2
VecMath.length = length
VecMath.distance2 = distance2
VecMath.distance = distance
VecMath.isUnit = isUnit
VecMath.normalize = normalize
VecMath.dot = dot
VecMath.step = step
VecMath.lerp = lerp

return VecMath
