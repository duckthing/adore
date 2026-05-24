---@type AdoreInit
local Adore = require ""
local Property = require "property"
local Vec2 = Adore.Common("Vec2")
---@type Property.Number
local NumberProperty = require "property.number"

---@class Property.Vec2: Property
local Vec2P = Property:extend()
Vec2P.TYPE = "Vec2"
Vec2P.subproperties = {
	x = NumberProperty(Vec2, "x", 0),
	y = NumberProperty(Vec2, "y", 0)
}

local tempVec2 = Vec2(0, 0)

function Vec2P:new(class, property, defaultValue, setter)
	Vec2P.super.new(self, class, property, defaultValue or class[property] or Vec2(0, 0))
	if setter then self:withSetter(setter) end
end

function Vec2P:newValue()
	return self.defaultValue:clone()
end

function Vec2P:set(obj, property, value)
	local vec = rawget(obj, property)
	if not vec then
		vec = self:newValue()
		obj[property] = vec
	end
	vec:iCopyVector(value)
end
Vec2P.rawSet = Vec2P.set

function Vec2P:add(a, b)
	return tempVec2:iCopyVector(a):iAdd(b)
end

function Vec2P:sanitize(vec)
	return vec
end

function Vec2P:isValid(num)
	return num == self:sanitize(num)
end

function Vec2P:stepTowards(from, to, amount)
	return tempVec2:iCopyVector(from):iStep(to, amount)
end

function Vec2P:lerp(from, to, percent)
	return tempVec2:iCopyVector(from):iLerp(to, percent)
end

function Vec2P:serialize(obj, propertyName, value)
	return {x = value.x, y = value.y}
end

function Vec2P:deserialize(obj, propertyName, value)
	self:set(obj, propertyName, self:sanitize(Vec2(value.x, value.y)))
end

return Vec2P
