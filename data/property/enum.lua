local Property = require "data.property"

---@class Property.Enum: Property
local Enum = Property:extend()
Enum.TYPE = "Enum"

---@param values {[string | number | boolean]: true}
---@param defaultValue any
---@param setter string?
function Enum:new(class, property, values, defaultValue, setter)
	Enum.super.new(self, class, property, defaultValue)

	---A lookup table of valid values
	self.values = values

	if setter then self:withSetter(setter) end
end

function Enum:sanitize(val)
	if self.values[val] then
		return val
	end
	return nil
end

function Enum:isValid(val)
	return self.values[val]
end

return Enum
