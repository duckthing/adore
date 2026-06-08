local Property = require "data.property"

---@class Property.Struct: Property
local Struct = Property:extend()
Struct.TYPE = "struct"
Struct.DEFER_MODE = "shared"

function Struct:new(class, property, definition, defaultValue, setter)
	Struct.super.new(self, class, property, defaultValue or class[property])

	---@type {[string]: Property}
	self.definition = definition or {}

	if setter then self:withSetter(setter) end
end

function Struct:serialize(obj, propertyName, value, resources, ...)
	local index, ref = self:getSharedMatch(obj, propertyName, value, resources, ...)
	if not index then
		index = #resources + 1
		resources[index] = ref
	end
	return index
end

function Struct:deserialize(obj, propertyName, resourceId, resources, ...)
	local reference = resources[resourceId]

	if not reference.__structVal then
		-- Not deserialized yet; do it
		local t = {}
		local definition = self.definition

		for fieldName, property in pairs(definition) do
			property:deserialize(t, fieldName, reference[fieldName], resources, ...)
		end

		reference.__structVal = t
	end

	self:set(obj, propertyName, reference.__structVal)
end

function Struct:getReference(obj, propertyName, value, resources, ...)
	local t = {}
	local definition = self.definition

	for fieldName, property in pairs(definition) do
		t[fieldName] = property:serialize(value, fieldName, value[fieldName], resources, obj, ...)
	end

	t.TYPE = self.TYPE
	return setmetatable(t,
	{
			__index = {value = value}
	})
end

return Struct
