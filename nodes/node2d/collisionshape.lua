---@type AdoreInit
local Adore = require ""
local Nodes = Adore.Nodes
local Node2d = Nodes("Node2d")
local Physical2d = Nodes("Physical2d")

---`CollisionShape` nodes add a `love.Shape` to a parent `Physical2d` node.
---Any changes to the local transform will not be reflected; you must
---create a new `love.Shape` with the desired transform and set it.
---@class CollisionShape: Node2d
---@field super Node2d
---@overload fun(shape: love.Shape, density: number?): CollisionShape
local CollisionShape = Node2d:extend()
CollisionShape.CLASS_NAME = "CollisionShape"

---@param shape love.Shape?
---@param density number?
function CollisionShape:new(shape, density)
	CollisionShape.super.new(self)

	---@type number # The default density of the shape
	self._density = density or 1
	---@type love.Shape? # The default shape of this CollisionShape
	self._shape = shape
	---@type love.Fixture? # The created fixture
	self._fixture = nil
end

---Sets the `love.Shape` this `CollisionShape` will use
---@param shape love.Shape
function CollisionShape:setShape(shape)
	local oldShape = self._shape
	if oldShape ~= shape then
		self._shape = oldShape
		self:_destroyFixture()
		self:_addFixture()
	end
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
			local shape = self._shape
			if shape then
				self._fixture = parent:_addShape(shape, self._density)
			end
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

function CollisionShape._addDefinition(entry)
	entry:newNumber("_density", 1, 0, nil, nil, "setDensity")
	entry:newAny("_shape", nil, "setShape")
end
CollisionShape:getClassDBEntry()

return CollisionShape
