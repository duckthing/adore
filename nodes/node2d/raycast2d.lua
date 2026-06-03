---@type AdoreInit
local Adore = require ""
local Nodes = Adore.Nodes
local Node2d = Nodes("Node2d")
local bit = Adore.Common("bitlib")

---@class Raycast2d: Node2d
---@field super Node2d
---@overload fun(x: number?, y: number?, rotation: number?, distance: number?): Raycast2d
local Raycast2d = Node2d:extend()
Raycast2d.CLASS_NAME = "Raycast2d"
Raycast2d.mask = 1
Raycast2d.groupIndex = 0

function Raycast2d:new(x, y, rotation, distance)
	Raycast2d.super.new(self, x, y)

	---@type number # How far to cast at the specified rotation
	self._distance = distance or 25

	---@type number # How far into the ray the last hit was. -1 means there was no hit.
	self._fraction = -1
	---@type Signal
	self.bodyEntered = self:newSignal()
	---@type Signal
	self.bodyLeft = self:newSignal()
	---@type Physical2d?
	self.collidingObject = nil
	---@type boolean # If the ray should collide with children parented to it. False will ignore any collisions.
	self.detectOwnChildren = false

	if rotation then
		self:setRotation(rotation)
	end
end

---Sets the distance this Raycast2d will go
---@param newDistance number
function Raycast2d:setDistance(newDistance)
	self._distance = newDistance
end

---Points this Raycast2d towards the global position and sets the distance to end at said point.
---Includes an optional max distance.
---@param gx number
---@param gy number
---@param maxDistance number?
function Raycast2d:castTo(gx, gy, maxDistance)
	maxDistance = maxDistance or self._distance
	self:lookAt(gx, gy)
	-- Should be roughly equal to (distance, 0)
	local rightX = self:toLocal(gx, gy)
	self:setDistance(math.min(rightX, maxDistance))
end

local hitObject = nil
local fraction = 0

---@param mask number # What to collide with
---@param groupIndex number # Our group index
---@param detectOwnChildren boolean
---@param fixture love.Fixture
---@param x number # Global intersection point
---@param y number # Global intersection point
---@param xn number # Normal vector
---@param yn number # Normal vector
---@param frac number # How far we've gone in the ray
---@return number? # Positive number sets the new ray length, 0 stops the ray, a negative value ignores the intersection
function Raycast2d:_raycastCallback(
	mask, groupIndex, detectOwnChildren,
	fixture, x, y, xn, yn, frac
)
	local oCategory, _, oGroupIndex = fixture:getFilterData()

	if oGroupIndex == groupIndex and groupIndex ~= 0 then
		-- Group index matches
		-- + Positive matches always collide
		-- + Negative values never collide
		if groupIndex < 0 then
			-- Negative value, didn't collide
			return -1
		end
	else
		-- Check if our mask matches the other category
		if bit.band(oCategory, mask) == 0 then
			-- A bitwise value of 0 means no collision
			return -1
		end
	end

	---@type Physical2d
	local hit = fixture:getBody():getUserData()

	if not detectOwnChildren and hit:hasAncestor(self) then
		-- Ignoring collisions with own child
		return -1
	end

	-- Return the values
	hitObject = hit
	fraction = frac
	return 0
end

---Handles the results from the raycast, with both positions being in global space
---@param world love.World
---@param startX number
---@param startY number
---@param endX number
---@param endY number
function Raycast2d:_raycastPerform(world, startX, startY, endX, endY)
	local mask, groupIndex, detectOwnChildren =
		self.mask,
		self.groupIndex,
		self.detectOwnChildren

	local oldObject = self.collidingObject
	hitObject = nil
	fraction = -1

	if not (startX == endX and startY == endY) then
		-- We can cast, as the length isn't 0
		local cb = function(...)
			return self:_raycastCallback(mask, groupIndex, detectOwnChildren, ...)
		end

		world:rayCast(startX, startY, endX, endY, cb)
	end

	self._fraction = fraction

	if not hitObject and oldObject then
		-- Object left the raycast
		self.bodyLeft:fire(oldObject)
		self.collidingObject = nil
	elseif hitObject ~= oldObject then
		-- New object entered the raycast
		if oldObject then
			-- There was something different last update
			self.bodyLeft:fire(oldObject)
		end

		self.collidingObject = hitObject
		self.bodyEntered:fire(hitObject)
	end
end

function Raycast2d:update(dt)
	---@type love.World
	local world = self:getViewport()._physicsWorld

	-- The start point
	local ax, ay = self:getPosition(true)
	-- The end point
	local bx, by = self:toGlobal(self._distance, 0)
	self:_raycastPerform(world, ax, ay, bx, by)
end

function Raycast2d:forceDestroy(...)
	Raycast2d.super.forceDestroy(self, ...)
	self.bodyEntered:release()
	self.bodyLeft:release()

	self.bodyEntered = nil
	self.bodyLeft = nil
end

function Raycast2d._addDefinition(entry)
	entry:newNumber("_distance", 25, 0, nil, nil, "setDistance")
	entry:newBoolean("detectOwnChildren", false)
end

return Raycast2d
