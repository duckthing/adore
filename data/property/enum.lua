local Property = require "data.property"

---@class Property.Enum: Property
local Enum = Property:extend()
Enum.TYPE = "Enum"

---@param values {[string | number | boolean]: any} | fun(self: Property.Enum, object: Object, propertyName: string?): {[string | number | boolean]: any}
---@param defaultValue any
---@param setter string?
function Enum:new(class, property, values, defaultValue, setter)
	Enum.super.new(self, class, property, defaultValue)

	if type(values) == "table" then
		---A lookup table of valid values
		self.valueMap = values
	else
		-- It's a function that gets the value map when called
		self.getValueMap = values
	end

	if setter then self:withSetter(setter) end
end

---Returns the lookup table of valid values
---@param object Object
---@param propertyName string?
---@return {[string | number | boolean]: any} valueMap
function Enum:getValueMap(object, propertyName)
	return self.valueMap
end

function Enum:sanitize(val)
	if self.valueMap then
		if self.valueMap[val] ~= nil then
			return val
		end
	else
		-- Getting the value map is dynamic; we can't check it
		return val
	end
	return nil
end

function Enum:isValid(val)
	return not self.valueMap or self.valueMap[val] ~= nil
end

return Enum
