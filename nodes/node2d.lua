---@type AdoreInit
local Adore = require ""
local Common = Adore.Common

local Node = Adore.Nodes("Node")
local Vec2 = Common("Vec2")
local Rect2 = Common("Rect2")

---@class Node2d: Node
---@field super Node
---@overload fun(x: number?, y: number?): Node2d
local Node2d = Node:extend()
Node2d.CLASS_NAME = "Node2d"
---@type integer[] # The color of this Node2d
Node2d.albedo = {1, 1, 1, 1}

local DEFAULT_TRANSFORM = love.math.newTransform(0, 0)
local PI = math.pi
local PI2 = PI * 2

---@param x number?
---@param y number?
function Node2d:new(x, y)
	Node2d.super.new(self)
	x, y =
		x or 0,
		y or 0

	---@type love.Transform # The result of making a position
	self._localTransform = love.math.newTransform(x, y)
	---@type love.Transform # The result of the previous transforms by ancestors plus this one
	self._globalTransform = love.math.newTransform()
	---@type boolean
	self._transformRelativeToParent = true

	---@type Vec2 # Relative position, use :getPosition() instead
	self._position = Vec2(x, y)

	---@type number # Relative rotation in radians, use :getRotation() instead
	self._rotation = 0
	---@type number # The sum of the parent's rotation and its ancestor rotation
	self._ancestorRotation = 0

	---@type Rect2
	self._localContentRect = Rect2(0, 0, 0, 0)
	---@type Rect2
	self._globalContentRect = Rect2(0, 0, 0, 0)
end

---Returns the global transform of the parent, if it exists
---@return love.Transform
function Node2d:getParentGlobalTransform()
	local parent = self.parent
	if self._transformRelativeToParent and parent and parent:is(Node2d) then
		---@cast parent Node2d
		return parent._globalTransform
	else
		return DEFAULT_TRANSFORM
	end
end

---Resets the transform to the parent's transform
---@return self self
function Node2d:resetToGlobal()
	self._localTransform:reset()
	self._globalTransform:setMatrix("row", self:getParentGlobalTransform():getMatrix())
	self:_onLocalTransformUpdated()
	return self
end

---Returns the world position and rotation from the current global transformation
---@return number x
---@return number y
---@return number angle
function Node2d:getWorldPositionAndRotation()
	local gx, gy = self._globalTransform:transformPoint(0, 0)
	return gx, gy, (self._rotation + self._ancestorRotation) % PI2
end

---Called via emit when the parent's global transform updates
---@param parentGlobalTransform love.Transform
function Node2d:_eParentGlobalTransformUpdated(parentGlobalTransform)
	if self._transformRelativeToParent then
		self._globalTransform:setMatrix(parentGlobalTransform:getMatrix())
			:apply(self._localTransform)
		local parent = self.parent
		local parentRotation = parent._rotation
		if parentRotation then
			self._ancestorRotation = (parentRotation + parent._ancestorRotation) % PI2
		else
			self._ancestorRotation = 0
		end
		self:_onGlobalTransformChanged()
	else
		-- Transform INDEPENDENT, not related to the parent
		self._position.x, self._position.y =
			self._localTransform:setMatrix(parentGlobalTransform:inverse():getMatrix())
				:apply(self._globalTransform)
				:transformPoint(0, 0)
	end
end

---Called whenever the global axis-aligned bounds of the content inside this Node2d *should* change.
---Can occur when:
---* Local bounds change
---* This Node2d moves in global space
function Node2d:_onGlobalBoundsChanged()
	-- TODO: Rename, is not called when changed, is called when *currently* changing
	self._globalContentRect:iSetRect(self._localContentRect):iTransformBox(self._globalTransform)
end

---Called whenever this Node2d's global transform changes/moves AT ALL. (Not from an emit)
---Remember to do super._onGlobalTransformChanged() if you're overriding it to pass the transform downwards.
function Node2d:_onGlobalTransformChanged()
	self:_onGlobalBoundsChanged()
	self:shallowEmit("_eParentGlobalTransformUpdated", self._globalTransform)
end

---Called when this Node2d's local transform updates, which, in turn, updates the global transform. (Not from an emit)
---If you're looking to check when this Node2d moves at all, use :_onGlobalTransformChanged()
function Node2d:_onLocalTransformUpdated()
	self._localTransform:setTransformation(self._position.x, self._position.y, self._rotation)
	self._globalTransform:setMatrix(self:getParentGlobalTransform():getMatrix()):apply(self._localTransform)
	self:_onGlobalTransformChanged()
end

---Translates the Node2D locally
---@param x number
---@param y number
---@return self self
function Node2d:translate(x, y)
	self._position.x, self._position.y =
		self._position.x + x,
		self._position.y + y
	self:_onLocalTransformUpdated()
	return self
end

---Translates this Node2d in global space
---@param x number
---@param y number
---@return Node2d
function Node2d:globalTranslate(x, y)
	local gx, gy = self:getPosition(true)
	self:setGlobalPosition(gx + x, gy + y)
	return self
end

---Sets the relative position
---@param x number
---@param y number
---@return self self
function Node2d:setPosition(x, y)
	self._position.x, self._position.y =
		x, y
	self:_onLocalTransformUpdated()
	return self
end

---Copies the values of the passed Vec2 into the position
---@param vector Vec2
---@return self self
function Node2d:setPositionVector(vector)
	self._position:iCopyVector(vector)
	self:_onLocalTransformUpdated()
	return self
end

---Sets the global position of this Node2d
---@param gx number
---@param gy number
---@return Node2d
function Node2d:setGlobalPosition(gx, gy)
	self:setPosition(self:getParentGlobalTransform():inverseTransformPoint(gx, gy))
	return self
end

---Gets the local position of this Node2D
---@param doGlobal boolean?
---@return number x
---@return number y
function Node2d:getPosition(doGlobal)
	if doGlobal then
		return self._globalTransform:transformPoint(0, 0)
	else
		return self._position.x, self._position.y
	end
end

---Rotates this Node2d, in radians
---@param angle number
---@return self self
function Node2d:rotate(angle)
	self._rotation = (self._rotation + angle) % PI2
	self:_onLocalTransformUpdated()
	return self
end

---Sets the local rotation of this Node2d, in radians
---@param angle number
---@return self self
function Node2d:setRotation(angle)
	self._rotation = angle % PI2
	self:_onLocalTransformUpdated()
	return self
end

---Sets the global rotation of this Node2d, in radians
---@param angle number
---@return self
function Node2d:setGlobalRotation(angle)
	return self:setRotation(angle - self._ancestorRotation)
end

---Gets the local rotation of this Node2D
---@param doGlobal boolean?
---@return number angle
function Node2d:getRotation(doGlobal)
	return (doGlobal and (self._rotation + self._ancestorRotation) % PI2)
		or self._rotation
end

---Gets the difference between this Node2d's +X axis towards the global point
---@param gx number
---@param gy number
---@return number angle
function Node2d:getAngleTo(gx, gy)
	local lx, ly = self:toLocal(gx, gy)
	return math.atan2(ly, lx)
end

---Makes this Node2d point its +X axis towards the global point
---@param gx number
---@param gy number
function Node2d:lookAt(gx, gy)
	self:rotate(self:getAngleTo(gx, gy))
end

---Converts global coordinates to the local space
---@param gx number
---@param gy number
---@return number lx
---@return number ly
function Node2d:toLocal(gx, gy)
	return self._globalTransform:inverseTransformPoint(gx, gy)
end

---Converts local coordinates to the global space
---@param lx number
---@param ly number
---@return number gx
---@return number gy
function Node2d:toGlobal(lx, ly)
	return self._globalTransform:transformPoint(lx, ly)
end

---Sets the local rotation of this Node2d, in radians
---@param x number
---@param y number
---@param angle number
---@return self self
function Node2d:setPositionAndRotation(x, y, angle)
	self._position.x, self._position.y, self._rotation =
		x, y, angle
	self:_onLocalTransformUpdated()
	return self
end

---Sets whether this Node2d will transform relative to the parent
---@param relative boolean
---@return self
function Node2d:setRelativeTransform(relative)
	if self._transformRelativeToParent == relative then return self end
	self._transformRelativeToParent = relative
	self:_eParentGlobalTransformUpdated(self:getParentGlobalTransform())
	return self
end

function Node2d:_beforeDraw()
	love.graphics.push("all")
	love.graphics.setColor(self.albedo)
	love.graphics.applyTransform(self._localTransform)
end

function Node2d:draw()
end

function Node2d:_afterDraw()
	love.graphics.pop()
end

function Node2d:onAddedToParent(parent)
	Node2d.super.onAddedToParent(self, parent)
	self:_eParentGlobalTransformUpdated(self:getParentGlobalTransform())
end

function Node2d._addDefinition(entry)
	entry:newVec2("_position", nil, "setPositionVector")
	entry:newNumber("_rotation", 0, nil, nil, nil, "setRotation")
	entry:newBoolean("_transformRelativeToParent", true, "setRelativeTransform")
	entry:newColor("albedo")
end
Node2d:getClassDBEntry()

return Node2d
