local Property = require "data.property"

---@class Property.Boolean: Property
local Boolean = Property:extend()
Boolean.TYPE = "boolean"

function Boolean:new(class, property, defaultValue, setter)
	Boolean.super.new(self, class, property, defaultValue or false)
	if setter then self:withSetter(setter) end
end

function Boolean:add(a, b)
	return a and b
end

function Boolean:sanitize(val)
	return val or false
end

function Boolean:isValid(val)
	return type(val) == "boolean"
end

return Boolean
