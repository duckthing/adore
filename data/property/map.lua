local Property = require "data.property"

---@class Property.Map: Property
local Map = Property:extend()
Map.TYPE = "map"
Map.DEFER_MODE = "shared"

---@param class Object
---@param propertyName string
---@param keyProperty Property
---@param valueProperty Property
---@param setter string?
function Map:new(class, propertyName, keyProperty, valueProperty, defaultValue, setter)
	Map.super.new(self, class, propertyName, defaultValue)
	self.keyProperty = keyProperty
	self.valueProperty = valueProperty
	if setter then self:withSetter(setter) end
end

function Map:newValue()
	return {}
end

function Map:add(a, b)
	return a
end

function Map:sanitize(val)
	return (self:isValid(val) and val) or {}
end

function Map:isValid(val)
	return type(val) == "table"
end

function Map:serialize(obj, propertyName, value, resources, ...)
	-- TODO: Search tables for shared resources too
	local index, ref = self:getSharedMatch(obj, propertyName, value, resources, ...)
	if not index then
		index = #resources + 1
		resources[index] = ref
	end
	return index
end

-- `:deserialize()` sets the value on an object, so we work around it with this
local temp = {}

function Map:deserialize(obj, propertyName, resourceId, resources, ...)
	local resource = resources[resourceId]

	if not resource._deserializedMap then
		-- Map not built; do that
		local map = {}
		local keys, values = resource.keys, resource.values
		local keyProperty, valueProperty = self.keyProperty, self.valueProperty
		temp.key, temp.value = nil, nil

		for i = 1, resource.count do
			keyProperty:deserialize(temp, "key", keys[i], resources, obj, ...)
			local key = temp.key
			temp.key = nil
			if key then
				-- Since a nil key will error
				valueProperty:deserialize(temp, "value", values[i], resources, obj, ...)
				map[key] = temp.value
				temp.value = nil
			end
		end

		resource._deserializedMap = map
	end

	self:set(obj, propertyName, resource._deserializedMap)
end

function Map:getReference(obj, propertyName, value, resources, ...)
	if not value then return nil end

	local keyProperty, valueProperty = self.keyProperty, self.valueProperty
	local keys = {}
	local values = {}
	local i = 1
	for k, v in pairs(value) do
		keys[i], values[i] =
			keyProperty:serialize(obj, propertyName, k, resources, ...),
			valueProperty:serialize(obj, propertyName, v, resources, ...)
		i = i + 1
	end

	return {
		TYPE = self.TYPE,
		keys = keys,
		values = values,
		-- Count is stored in case a key or value is nil
		count = i - 1,
	}
end

return Map
