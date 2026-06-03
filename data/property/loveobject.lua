local Property = require "data.property"

---@class Property.LoveObject: Property
local LObject = Property:extend()
LObject.TYPE = "LoveObject"
LObject.DEFER_MODE = "shared"

---@type {[string]: (fun(obj: love.Object): table)} # A map of Love2D types to a function that returns the parameters needed to remake later
local getParamMap = {}
---@type {[string]: (fun(params: table): love.Object)} # A map of Love2D types to a function that recreates the object from its parameters
local createObjectMap = {}

function LObject:new(class, property, baseClass, defaultValue, setter)
	LObject.super.new(self, class, property, defaultValue or class[property])

	---@type string
	self.baseClass = baseClass or "Object"

	if setter then self:withSetter(setter) end
end

function LObject:newValue()
	return nil
end

function LObject:add(a, b)
	return a
end

function LObject:sanitize(val)
	return (self:isValid(val) and val) or nil
end

function LObject:isValid(val)
	return type(val) == "userdata" and val:typeOf(self.baseClass)
end

function LObject:serialize(obj, propertyName, value, resources)
	-- TODO: Search tables for shared resources too
	local index, ref = self:getSharedMatch(obj, propertyName, value, resources)
	if not index then
		index = #resources + 1
		resources[index] = ref
	end
	return index
end

function LObject:deserialize(obj, propertyName, value, resources)
	-- Do nothing; we unpack the buffer later
	-- When deferred, this function gets called later.
	-- When deferred and reliant on a shared resource, the `value` parameter will be whatever `:serialize()` returned.
	-- (which tends to be the ID to a resource)

	-- TLDR
	-- * `value` is the ID to the table in `resources`
	-- * `resources[id]/resources[value]` gets the reference
	-- * `reference.value` gets the decoded table

	local val = resources[value]
	local instanced = val.instanced

	if not instanced then
		-- Create it if it doesn't exist
		instanced = createObjectMap[val.loveType](val.params)
		val.instanced = instanced
	end

	self:set(obj, propertyName, instanced)
end

function LObject:getReference(obj, propertyName, value, resources)
	---@cast value love.Object
	local valType = value:type()
	return setmetatable({
		TYPE = self.TYPE,
		loveType = valType,
		params = getParamMap[valType](value)
	},
	{
			__index = {value = value}
	})
end

getParamMap.World = function(obj)
	---@cast obj love.World
	local xg, yg = obj:getGravity()
	return {
		xg = xg,
		yg = yg,
		sleep = obj:isSleepingAllowed(),
	}
end

createObjectMap.World = function(params)
	return love.physics.newWorld(params.xg, params.yg, params.sleep)
end

getParamMap.PolygonShape = function(obj)
	---@cast obj love.PolygonShape
	return {
		points = {obj:getPoints()}
	}
end

createObjectMap.PolygonShape = function(params)
	return love.physics.newPolygonShape(unpack(params.points))
end

getParamMap.CircleShape = function(obj)
	---@cast obj love.CircleShape
	local x, y = obj:getPoint()
	return {
		x = x,
		y = y,
		radius = obj:getRadius()
	}
end

createObjectMap.CircleShape = function(params)
	return love.physics.newCircleShape(params.x, params.y, params.radius)
end

return LObject
