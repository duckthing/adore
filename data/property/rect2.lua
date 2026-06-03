---@type AdoreInit
local Adore = require ""
local Property = require "data.property"
local Rect2 = Adore.Common("Rect2")
---@type Property.Number
local NumberProperty = require "data.property.number"

---@class Property.Rect2: Property
local Rect2P = Property:extend()
Rect2P.TYPE = "Rect2"
Rect2P.subproperties = {
	x = NumberProperty(Rect2, "x", 0),
	y = NumberProperty(Rect2, "y", 0),
	w = NumberProperty(Rect2, "w", 0),
	h = NumberProperty(Rect2, "h", 0)
}

local tempRect2 = Rect2(0, 0)

function Rect2P:new(class, property, defaultValue, setter)
	Rect2P.super.new(self, class, property, defaultValue or class[property] or Rect2(0, 0, 0, 0))
	if setter then self:withSetter(setter) end
end

function Rect2P:newValue()
	return self.defaultValue:clone()
end

function Rect2P:set(obj, property, value)
	local vec = rawget(obj, property)
	if not vec then
		vec = self:newValue()
		obj[property] = vec
	end
	vec:iCopyRect(value)
end
Rect2P.rawSet = Rect2P.set

function Rect2P:add(a, b)
	return a
end

function Rect2P:sanitize(rect)
	return rect
end

function Rect2P:isValid(num)
	return num == self:sanitize(num)
end

function Rect2P:stepTowards(from, to, amount)
	return from
end

function Rect2P:lerp(from, to, percent)
	if percent < 1 then
		return from
	else
		return to
	end
end

function Rect2P:serialize(obj, propertyName, value)
	if value then
		return {x = value.x, y = value.y, w = value.w, h = value.h}
	end
	return nil
end

function Rect2P:deserialize(obj, propertyName, value)
	self:set(obj, propertyName, self:sanitize(Rect2(value.x, value.y, value.w, value.h)))
end

return Rect2P
