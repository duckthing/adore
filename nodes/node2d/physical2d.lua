---@type AdoreInit
local Adore = require ""
local Nodes = Adore.Nodes
local Common = Adore.Common
local Node2d = Nodes("Node2d")

local VecMath = Common("VecMath")
local Vec2 = Common("Vec2")
local bit = Common("bitlib")

---@alias Physical2d.MotionMode
---| "grounded"
---| "floating"

---@class Physical2d: Node2d
---@field super Physical2d
---@overload fun(x: number?, y: number?): Physical2d
local Physical2d = Node2d:extend()
Physical2d.CLASS_NAME = "Physical2d"
Physical2d.defaultCategory = 1
Physical2d.defaultMask = 1
Physical2d.defaultGroupIndex = 0

-- These should be set in your class definition, not inside of :new()
Physical2d.defaultBodyType = "dynamic"
Physical2d.defaultLinearDamping = 0
Physical2d.defaultAngularDamping = 0
Physical2d.defaultFixedRotation = false
Physical2d.defaultFriction = 0
Physical2d.defaultRestitution = 0

---@type Vec2 # A unit vector that points "upwards". This is used for :isOnFloor() and the like.
Physical2d.upDirection = Vec2(0, -1)
---@type number # What is the maximum angle we can count as the "floor". Default is slightly above 45 degrees.
Physical2d.floorMaxAngle = 0.786
---@type Physical2d.MotionMode # Is this a floating or grounded body? Used for :isOnFloor() and the like.
Physical2d.motionMode = "grounded"

---@type love.World
local defaultWorld = nil

---@type {[love.World]: Physical2d[]} # A map of `love.World`s to an array of all `Physical2d`s in them
local bodyList = {}
-- Makes the `love.World` a weak reference
setmetatable(bodyList, {__mode = "k"})

---When a love.World is created, you should call this
---@param world love.World
function Physical2d.addWorldList(world)
	bodyList[world] = {}
end

---When a love.World is released, you should call this
---@param world love.World
function Physical2d.removeWorldList(world)
	bodyList[world] = nil
end

---Returns the list of all `Physical2d`s in the corresponding `love.World`
function Physical2d.getWorldList(world)
	return bodyList[world]
end

---@param x number?
---@param y number?
function Physical2d:new(x, y)
	Physical2d.super.new(self, x, y)

	---@type love.Body? # The love.Body of this Physical2d; created when added to the tree.
	self.body = nil

	---@type boolean # Whether this body can be used in the physics simulation (if it's in the tree); use :setActive() for this
	self._active = true

	-- Move this Transform over to the body's transform
	-- self._localTransform:setTransformation(self.body:getTransform())
	self._globalTransform:setMatrix(self:getParentGlobalTransform():getMatrix())
		:apply(self._localTransform)
end

---Sets whether this Physical2d will be used for physics and collisions.
---Use this instead of `body:setActive()`, as it will simulate the body if its in the tree.
---@param status boolean
function Physical2d:setActive(status)
	if self._active ~= status then
		self._active = status
		self.body:setActive(self._inTree and self._valid and status)
	end
end

---Called whenever a love.Body is added to the love.World (usually when added to the tree)
---@param body love.Body
function Physical2d:onBodyAdded(body)
	body:setActive(self._active and self._inTree) -- this will be set depending on `self._active` + tree status
	body:setLinearDamping(self.defaultLinearDamping)
	body:setAngularDamping(self.defaultAngularDamping)
	body:setFixedRotation(self.defaultFixedRotation)
	body:setTransform(self:getWorldPositionAndRotation())
end

function Physical2d:_createBody()
	---@type Viewport
	---@diagnostic disable-next-line: assign-type-mismatch
	local newViewport = self:getViewport()

	local world = newViewport._physicsWorld
	local newBody = love.physics.newBody(
		world,
		0, 0,
		self.defaultBodyType
	)
	local list = bodyList[world]
	list[#list+1] = self

	newBody:setUserData(self)
	newBody:setTransform(self:getWorldPositionAndRotation())
	self.body = newBody
	self:onBodyAdded(newBody)
end

function Physical2d:_releaseBody()
	local body = self.body
	if body then
		self.body = nil

		-- Remove this body from the list
		local list = bodyList[body:getWorld()]
		for i = #list, 1, -1 do
			if list[i] == self then
				table.remove(list, i)
				break
			end
		end

		if body then
			body:destroy()
			body:release()
		end
	end
end

function Physical2d:onViewportAdded(newViewport)
	Physical2d.super.onViewportAdded(self, newViewport)
	if self._inTree then
		self:_createBody()
	end
end

function Physical2d:onViewportRemoved(oldViewport)
	Physical2d.super.onViewportRemoved(self, oldViewport)
	self:_releaseBody()
end

function Physical2d:_eAncestorTreeStatusUpdated(...)
	Physical2d.super._eAncestorTreeStatusUpdated(self, ...)
	if not self._inTree then
		self:_releaseBody()
	elseif not self.body then
		-- In the tree, no body
		self:_createBody()
	end
end

---Adds a shape to this Physical2d, and returns the Fixture made.
---Don't use this directly; use CollisionShapes or `:newCollisionShape()` instead.
---
---The latter methods will work when parenting this Physical2d to new physics worlds.
---@param shape love.Shape
---@param density number?
---@return love.Fixture
function Physical2d:_addShape(shape, density)
	local fixture = love.physics.newFixture(
		self.body,
		shape,
		density
	)
	fixture:setFriction(self.defaultFriction)
	fixture:setRestitution(self.defaultRestitution)
	fixture:setFilterData(self.defaultCategory, self.defaultMask, self.defaultGroupIndex)
	return fixture
end

---Creates a CollisionShape node and parents it to this Physical2d.
---Generally a bad practice in production.
---@param shape love.Shape
---@param density number?
---@return CollisionShape cshape
function Physical2d:newCollisionShape(shape, density)
	local node = Nodes("CollisionShape")(shape, density)
	self:addChild(node)
	return node
end

function Physical2d:_eParentGlobalTransformUpdated(parentGlobalTransform)
	Physical2d.super._eParentGlobalTransformUpdated(self, parentGlobalTransform)
	if self._transformRelativeToParent then
		-- Transform RELATIVE to the parent
		local body = self.body
		if body then
			body:setTransform(self:getWorldPositionAndRotation())
			body:setAwake(true)
		end
		-- If the transform is INDEPENDENT (not relative to the parent), it's handled in
		-- Node2d._eParentGlobalTransformUpdated(...)
	end
end

function Physical2d:update(dt)
	if self.body:isAwake() then
		-- TODO: _transformRelativeToParent inside of Physical2d
		-- If the parent does NOT move, and the Physical2d does, it would NOT tell the Node2ds below it.
		-- If the parent does move, it tells the Node2ds below twice.
		-- Physical2d with a relative transform are an edge case anyways, and haven't been useful to me.
		-- It could be removed if it's a big problem.

		if not self._transformRelativeToParent then
			-- Transform INDEPENDENT, not related to the parent
			local x, y, angle = self.body:getTransform()
			self._position.x, self._position.y, self._rotation =
				x, y, angle

			self._globalTransform:setTransformation(x, y, angle)

			local parentGlobalXform = self.parent._globalTransform
			if parentGlobalXform then
				self._localTransform = parentGlobalXform:inverse() * self._globalTransform
			else
				self._localTransform:setMatrix(self._globalTransform:getMatrix())
			end
			self:shallowEmit("_eParentGlobalTransformUpdated", self._globalTransform)
		-- else
			-- Transform RELATIVE to the parent
			-- ...so we do nothing, as relative + static bodies are updated in :_eParentGlobalTransformUpdated()
		end
	end
end

---Similar to `:update()`, but any forces applied to the body should occur here.
---May be called multiple times per frame, but will always have a fixed delta time.
---@param dt number
function Physical2d:physicsUpdate(dt)
end

--TODO: Simplify :isOn*() methods

---Returns true if any Contact's dot(-upDirection, normal) is below the `floorMaxAngle`
---@return boolean onFloor
function Physical2d:isOnFloor()
	if self.motionMode == "floating" then return false end

	---@type love.Contact[]
	local contacts = self.body:getContacts()
	local dx, dy =
		-self.upDirection.x,
		-self.upDirection.y
	local maxAngle = self.floorMaxAngle

	for i = 1, #contacts do
		local contact = contacts[i]
		if contact:isTouching() then
			local nx, ny = contact:getNormal()
			local angle = VecMath.dot(dx, dy, nx, ny)
			if angle > maxAngle then
				return true
			end
		end
	end

	return false
end

---Returns true if any Contact's dot(upDirection, normal) is between +-`floorMaxAngle`
---@return boolean onFloor
function Physical2d:isOnWall()
	---@type love.Contact[]
	local contacts = self.body:getContacts()

	-- Any contact is considered a wall if floating
	if self.motionMode == "floating" then return #contacts > 0 end

	local dx, dy =
		self.upDirection.x,
		self.upDirection.y
	local maxAngle = self.floorMaxAngle

	for i = 1, #contacts do
		local contact = contacts[i]
		if contact:isTouching() then
			local nx, ny = contact:getNormal()
			local angle = VecMath.dot(dx, dy, nx, ny)
			if math.abs(angle) < maxAngle then
				return true
			end
		end
	end

	return false
end

---Returns true if any Contact's dot(upDirection, normal) is below `floorMaxAngle`
---@return boolean onFloor
function Physical2d:isOnCeiling()
	if self.motionMode == "floating" then return false end

	---@type love.Contact[]
	local contacts = self.body:getContacts()

	local dx, dy =
		self.upDirection.x,
		self.upDirection.y
	local maxAngle = self.floorMaxAngle

	for i = 1, #contacts do
		local contact = contacts[i]
		if contact:isTouching() then
			local nx, ny = contact:getNormal()
			local angle = VecMath.dot(dx, dy, nx, ny)
			if angle > maxAngle then
				return true
			end
		end
	end

	return false
end

---Returns true if any Contact's dot(-upDirection, normal) is below the `floorMaxAngle`, and nothing else
---@return boolean onFloor
function Physical2d:isOnFloorOnly()
	if self.motionMode == "floating" then return false end

	---@type love.Contact[]
	local contacts = self.body:getContacts()

	local dx, dy =
		-self.upDirection.x,
		-self.upDirection.y
	local maxAngle = self.floorMaxAngle
	local touchingAnything = false

	for i = 1, #contacts do
		local contact = contacts[i]
		if contact:isTouching() then
			touchingAnything = true
			local nx, ny = contact:getNormal()
			local angle = VecMath.dot(dx, dy, nx, ny)
			if not (angle > maxAngle) then
				return false
			end
		end
	end

	return touchingAnything
end

---Returns true if any Contact's dot(upDirection, normal) is between +-`floorMaxAngle`, and nothing else
---@return boolean onFloor
function Physical2d:isOnWallOnly()
	---@type love.Contact[]
	local contacts = self.body:getContacts()

	-- Any contact is considered a wall if floating
	if self.motionMode == "floating" then return #contacts > 0 end
	if #contacts == 0 then return false end

	local dx, dy =
		self.upDirection.x,
		self.upDirection.y
	local maxAngle = self.floorMaxAngle
	local touchingAnything = false

	for i = 1, #contacts do
		local contact = contacts[i]
		if contact:isTouching() then
			touchingAnything = true
			local nx, ny = contact:getNormal()
			local angle = VecMath.dot(dx, dy, nx, ny)
			if not (math.abs(angle) < maxAngle) then
				return false
			end
		end
	end

	return touchingAnything
end

---Returns true if any Contact's dot(upDirection, normal) is below `floorMaxAngle`, and nothing else
---@return boolean onFloor
function Physical2d:isOnCeilingOnly()
	if self.motionMode == "floating" then return false end

	---@type love.Contact[]
	local contacts = self.body:getContacts()

	local dx, dy =
		self.upDirection.x,
		self.upDirection.y
	local maxAngle = self.floorMaxAngle
	local touchingAnything = false

	for i = 1, #contacts do
		local contact = contacts[i]
		if contact:isTouching() then
			touchingAnything = true
			local nx, ny = contact:getNormal()
			local angle = VecMath.dot(dx, dy, nx, ny)
			if not (angle > maxAngle) then
				return false
			end
		end
	end

	return touchingAnything
end

---@param ownFixture love.Fixture
---@param otherFixture love.Fixture
---@param contact love.Contact
function Physical2d:beginContact(ownFixture, otherFixture, contact)
end

---@param ownFixture love.Fixture
---@param otherFixture love.Fixture
---@param contact love.Contact
function Physical2d:endContact(ownFixture, otherFixture, contact)
end

function Physical2d:forceDestroy(...)
	Physical2d.super.forceDestroy(self, ...)
	if self.body then
		for _, contact in ipairs(self.body:getContacts()) do
			---@cast contact love.Contact
			local a, b = contact:getFixtures()
			a:getBody():setAwake(true)
			b:getBody():setAwake(true)
		end
		self.body:destroy()
		self.body = nil
	end
end

---Sets the love.World to use for physics
---@param w love.World
function Physical2d.setWorld(w)
	defaultWorld = w
end

---Returns the current love.World that is set for physics.
---When called as a method, returns the love.World that is used for this body.
---When called as a function, returns the default love.World.
---@param self Physical2d?
---@return love.World
function Physical2d:getWorld()
	return (self and self.body:getWorld()) or defaultWorld
end

do
local simpleMask = 65535
local simpleGroupIndex = 0

local simpleHitFixture = nil
local simpleX, simpleY, simpleXN, simpleYN, simpleFrac =
	nil, nil, nil, nil, nil

---@param fixture love.Fixture
---@param x number # Global intersection point
---@param y number # Global intersection point
---@param xn number # Normal vector
---@param yn number # Normal vector
---@param frac number # How far we've gone in the ray
---@return number? # Positive number sets the new ray length, 0 stops the ray, a negative value ignores the intersection
local function simpleRaycastCallback(fixture, x, y, xn, yn, frac)
	local oCategory, _, oGroupIndex = fixture:getFilterData()

	if oGroupIndex == simpleGroupIndex and simpleGroupIndex ~= 0 then
		-- Group index matches
		-- + Positive matches always collide
		-- + Negative values never collide
		if simpleGroupIndex < 0 then
			-- Negative value, didn't collide
			return -1
		end
	else
		-- Check if our mask matches the other category
		if bit.band(oCategory, simpleMask) == 0 then
			-- A bitwise value of 0 means no collision
			return -1
		end
	end

	-- Return the values
	simpleHitFixture = fixture
	simpleX, simpleY, simpleXN, simpleYN, simpleFrac =
		x, y, xn, yn, frac
	return 0
end

---Performs a simple raycast and returns the hit object, starting from global A to global B.
---Includes an optional mask and group index for object filtering.
---@param ax number
---@param ay number
---@param bx number
---@param by number
---@param mask integer?
---@param groupIndex integer?
---@param world love.World?
---@return Physical2d? hitObject
---@return love.Fixture? hitFixture
---@return number? x
---@return number? y
---@return number? xn
---@return number? yn
---@return number? frac
function Physical2d.simpleRaycast(ax, ay, bx, by, mask, groupIndex, world)
	simpleHitFixture = nil
	simpleMask = mask or 65535 -- Everything
	simpleGroupIndex = groupIndex or 0 -- No special group
	simpleX, simpleY, simpleXN, simpleYN, simpleFrac =
		nil, nil, nil, nil, nil

	(world or defaultWorld):rayCast(ax, ay, bx, by, simpleRaycastCallback)

	return
		(simpleHitFixture and simpleHitFixture:getBody():getUserData()),
		simpleHitFixture,
		simpleX, simpleY, simpleXN, simpleYN, simpleFrac
end
end

do
-- When these methods are called, we should update the body's POSITION
local methodsThatUpdatePosition = {
	"translate",
	"setPosition",
	"setPositionVector",
}

-- When these methods are called, we should update the body's ROTATION
local methodsThatUpdateRotation = {
	"rotate",
	"setRotation",
}

-- When these methods are called, we should update the body's TRANSFORM
local methodsThatUpdateTransform = {
	"setTransform"
}

for _, method in ipairs(methodsThatUpdatePosition) do
	local superMethod = Physical2d.super[method]

	---@param self Physical2d
	---@param ... unknown
	Physical2d[method] = function(self, ...)
		superMethod(self, ...)
		local body = self.body
		if not body then return end
		body:setPosition(self:getPosition(true))
		body:setAwake(true)

		for _, contact in ipairs(body:getContacts()) do
			---@cast contact love.Contact
			local a, b = contact:getFixtures()
			a:getBody():setAwake(true)
			b:getBody():setAwake(true)
		end
	end
end

for _, method in ipairs(methodsThatUpdateRotation) do
	local superMethod = Physical2d.super[method]

	---@param self Physical2d
	---@param ... unknown
	Physical2d[method] = function(self, ...)
		superMethod(self, ...)
		local body = self.body
		if not body then return end
		body:setAngle(self:getRotation(true))
		body:setAwake(true)

		for _, contact in ipairs(body:getContacts()) do
			---@cast contact love.Contact
			local a, b = contact:getFixtures()
			a:getBody():setAwake(true)
			b:getBody():setAwake(true)
		end
	end
end

for _, method in ipairs(methodsThatUpdateTransform) do
	local superMethod = Physical2d.super[method]

	---@param self Physical2d
	---@param ... unknown
	Physical2d[method] = function(self, ...)
		superMethod(self, ...)
		local body = self.body
		if not body then return end
		body:setTransform(self:getWorldPositionAndRotation())
		body:setAwake(true)

		for _, contact in ipairs(body:getContacts()) do
			---@cast contact love.Contact
			local a, b = contact:getFixtures()
			a:getBody():setAwake(true)
			b:getBody():setAwake(true)
		end
	end
end
end

---@alias Physical2d.WorldCallback
---| fun(a: love.Fixture, b: love.Fixture, coll: love.Contact)

---Returns the callbacks that should be set for the love.World object
---@return Physical2d.WorldCallback beginContact
---@return Physical2d.WorldCallback endContact
---@return Physical2d.WorldCallback beginContact
function Physical2d.getWorldCallbacks()
	-- A table with weak keys
	---@type {[love.Contact]: true} # Maps to `true` if we should ignore a Contact in preSolve, for one-way platforms
	local ignoreMap = setmetatable({}, {__mode = "k"})

	---@type Physical2d.WorldCallback
	local function beginContact(a, b, coll)
		---@type Physical2d, Physical2d
		local ao, bo = a:getBody():getUserData(), b:getBody():getUserData()
		ao:beginContact(a, b, coll)
		bo:beginContact(b, a, coll)

		-- Disable collisions for one-way platforms
		---@type CollisionShape, CollisionShape
		local aShape, bShape = a:getUserData(), b:getUserData()

		if bShape and bShape.oneWayCollision then
			-- A is colliding into B
			local upDir = bShape.upDirection
			local upX, upY = -upDir.x, -upDir.y
			local nx, ny = coll:getNormal()

			if VecMath.dot(upX, upY, nx, ny) <= 0 then
				coll:setEnabled(false)
				ignoreMap[coll] = true
				return
			end
		end

		if aShape and aShape.oneWayCollision then
			-- B is colliding into A
			local upDir = aShape.upDirection
			local upX, upY = upDir.x, upDir.y
			local nx, ny = coll:getNormal()

			if VecMath.dot(upX, upY, nx, ny) <= 0 then
				coll:setEnabled(false)
				ignoreMap[coll] = true
				return
			end
		end
	end

	---@type Physical2d.WorldCallback
	local function endContact(a, b, coll)
		---@type Physical2d, Physical2d
		local ao, bo = a:getBody():getUserData(), b:getBody():getUserData()
		ao:endContact(a, b, coll)
		bo:endContact(b, a, coll)
		ignoreMap[coll] = nil
	end

	---@type Physical2d.WorldCallback
	local function preSolve(a, b, coll)
		if not coll:isTouching() or ignoreMap[coll] then
			coll:setEnabled(false)
			return
		end
	end

	return
		beginContact,
		endContact,
		preSolve
end

function Physical2d._addDefinition(entry)
	entry:newBoolean("_active", true, "setActive")
	entry:newVec2("upDirection")

	-- Common override
	entry:newBoolean("_transformRelativeToParent", false, "setRelativeTransform")

	-- Disable problematic properties
	entry:newVec2("_scale", nil, "setScaleVector")
		:hide()
end

return Physical2d
