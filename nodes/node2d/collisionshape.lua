---@type AdoreInit
local Adore = require ""
local Nodes = Adore.Nodes
local Node2d = Nodes("Node2d")
local Physical2d = Nodes("Physical2d")
local Vec2 = Adore.Common("Vec2")
local min = math.min

---`CollisionShape` nodes add a `love.Shape` to a parent `Physical2d` node.
---Any changes to the local transform will not be reflected; you must
---create a new `love.Shape` with the desired transform and set it.
---@class CollisionShape: Node2d
---@field super Node2d
---@overload fun(shape: love.Shape, density: number?): CollisionShape
local CollisionShape = Node2d:extend()
CollisionShape.CLASS_NAME = "CollisionShape"

---@type Vec2 # The "up" direction used for one-way collisions; anything moving "down" will be blocked
CollisionShape.upDirection = Vec2(0, -1)

---@param shape love.Shape?
---@param density number?
function CollisionShape:new(shape, density)
	CollisionShape.super.new(self)

	---@type number # The default density of the shape
	self._density = density or 1
	---@type boolean # Whether physics objects can only collide with objects above this
	self.oneWayCollision = false

	---@type love.Shape? # The default shape of this CollisionShape
	self._shape = shape
	---@type love.Shape? # The transformed shape
	self._transformedShape = nil

	---@type love.Fixture? # The created fixture
	self._fixture = nil
end

function CollisionShape:_transformShape()
	local shape = self._shape
	if self._transformedShape then
		-- Remove the old shape
		if self._transformedShape ~= shape then
			self._transformedShape:release()
		end
		self._transformedShape = nil
	end
	if not shape then return end

	local shapeType = shape:getType()
	local finalShape

	if shapeType == "polygon" then
		-- Transform every point
		---@cast shape love.PolygonShape
		local transform = self._localTransform
		local newPoints = {}
		local oldPoints = {shape:getPoints()}

		for i = 1, #oldPoints, 2 do
			local ox, oy = oldPoints[i], oldPoints[i+1]
			newPoints[i], newPoints[i+1]
				= transform:transformPoint(ox, oy)
		end

		finalShape = love.physics.newPolygonShape(newPoints)
	elseif shapeType == "circle" then
		-- Transform only the position
		---@cast shape love.CircleShape
		local x, y = self:getPosition()
		finalShape = love.physics.newCircleShape(x, y,
			shape:getRadius() * min(self._scale.x, self._scale.y))
	else
		finalShape = shape
	end
	self._transformedShape = finalShape
end

---Sets the `love.Shape` this `CollisionShape` will use
---@param shape love.Shape
function CollisionShape:setShape(shape)
	self._shape = shape
	self:_addFixture()
end

---Sets the density the `love.Shape` will have
---@param amount number?
function CollisionShape:setDensity(amount)
	amount = amount or 1
	if self._density ~= amount then
		self._density = amount
		local fixture = self._fixture
		if fixture then
			fixture:setDensity(amount)
			fixture:getBody():resetMassData()
		end
	end
end

---Creates a new `love.Fixture` with its contained shape onto the parent
---@private
function CollisionShape:_addFixture()
	local parent = self.parent
	if parent and parent:is(Physical2d) then
		---@cast parent Physical2d
		self:_destroyFixture()
		local pBody = parent.body
		if pBody and not pBody:isDestroyed() then
			self:_transformShape()
			local shape = self._transformedShape
			if shape then
				self._fixture = parent:_addShape(shape, self._density)
				self._fixture:setUserData(self)
				self:_updateGlobalBounds()
			end
		end
	end
end

function CollisionShape:_onLocalTransformUpdated()
	CollisionShape.super._onLocalTransformUpdated(self)
	if self._fixture then
		self:_addFixture()
	end
end

function CollisionShape:_updateGlobalBounds()
	local fixture = self._fixture
	if fixture then
		local parent = self.parent
		---@cast parent Physical2d
		if parent.body:isActive() then
			self._globalContentRect:iSetFromPoints(fixture:getBoundingBox())
		end
	end
end

---Destroys a `love.Fixture` created by this CollisionShape, if it exists
---@private
function CollisionShape:_destroyFixture()
	local oldFixture = self._fixture
	if oldFixture then
		if not oldFixture:isDestroyed() then
			oldFixture:destroy()
		end
		self._fixture = nil
		oldFixture:release()
	end
end

function CollisionShape:onViewportAdded(newViewport)
	CollisionShape.super.onViewportAdded(self, newViewport)
	self:_addFixture()
end

function CollisionShape:onViewportRemoved(oldViewport)
	CollisionShape.super.onViewportRemoved(self, oldViewport)
	self:_destroyFixture()
end

function CollisionShape:doesPointOverlap(worldX, worldY)
	local fixture = self._fixture
	if fixture then
		return fixture:testPoint(worldX, worldY)
	end
	return false
end

function CollisionShape._addDefinition(entry)
	entry:newNumber("_density", 1, 0, nil, nil, "setDensity")
	entry:newLoveObject("_shape", "Shape", "setShape")
	entry:newBoolean("oneWayCollision", false)
	entry:newVec2("upDirection", CollisionShape.upDirection)
end

return CollisionShape
