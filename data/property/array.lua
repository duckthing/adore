local Property = require "data.property"

---@class Property.Array: Property
local Array = Property:extend()
Array.TYPE = "array"
Array.DEFER_MODE = "shared"

---@param class Object
---@param propertyName string
---@param valueProperty Property
---@param setter string?
function Array:new(class, propertyName, valueProperty, defaultValue, setter)
	Array.super.new(self, class, propertyName, defaultValue)
	self.valueProperty = valueProperty
	if setter then self:withSetter(setter) end
end

function Array:newValue()
	return {}
end

function Array:add(a, b)
	return a
end

function Array:sanitize(val)
	return (self:isValid(val) and val) or {}
end

function Array:isValid(val)
	return type(val) == "table"
end

function Array:serialize(obj, propertyName, value, resources, ...)
	local index, ref = self:getSharedMatch(obj, propertyName, value, resources, ...)
	if not index then
		index = #resources + 1
		resources[index] = ref
	end
	return index
end

-- `:deserialize()` sets the value on an object, so we work around it with this
local temp = {}

function Array:deserialize(obj, propertyName, resourceId, resources, ...)
	local resource = resources[resourceId]

	if not resource._deserializedArray then
		-- Array not built; do that
		local array = {}
		local values = resource.values
		local valueProperty = self.valueProperty

		for i = 1, resource.count do
			if values[i] then
				valueProperty:deserialize(temp, "value", values[i], resources, obj, ...)
				array[i] = temp.value
				temp.value = nil
			end
		end

		resource._deserializedArray = array
	end

	self:set(obj, propertyName, resource._deserializedArray)
end

function Array:getReference(obj, propertyName, valueArr, resources, ...)
	if not valueArr then return nil end

	local valueProperty = self.valueProperty

	local valueArrCopy = {}
	local count = 0
	for i, v in ipairs(valueArr) do
		valueArrCopy[i] =
			valueProperty:serialize(obj, propertyName, v, resources, ...)
		count = i
	end

	return {
		TYPE = self.TYPE,
		values = valueArrCopy,
		-- Count is stored in case a key or value is nil
		count = count,
	}
end

return Array
