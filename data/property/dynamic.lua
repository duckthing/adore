local Property = require "data.property"

---@class Property.Dynamic: Property
local Dynamic = Property:extend()
Dynamic.TYPE = "Dynamic"
Dynamic.DEFER_MODE = "shared"

---@alias Property.Dynamic.Getter
---| fun(self: Property.Dynamic, obj: Object, propertyName: string, value: any, parentObjects: ...): Property?

---@param class Object
---@param propertyName string
---@param propertyGetter Property.Dynamic.Getter
---@param setter string?
function Dynamic:new(class, propertyName, propertyGetter, defaultValue, setter)
	Dynamic.super.new(self, class, propertyName, defaultValue)
	self.propertyGetter = propertyGetter
	if setter then self:withSetter(setter) end
end

---Gets the Property with the property getter
---@param obj Object
---@param propertyName string
---@param value any
---@param ...Object
---@return Property?
function Dynamic:getProperty(obj, propertyName, value, ...)
	return self.propertyGetter and self:propertyGetter(obj, propertyName, value, ...)
end

function Dynamic:serialize(obj, propertyName, value, resources, ...)
	local targetProperty = self:getProperty(obj, propertyName, value, ...)
	if not targetProperty then
		return
	end

	return targetProperty:serialize(obj, propertyName, value, resources, ...)
end

function Dynamic:deserialize(obj, propertyName, value, resources, ...)
	local targetProperty = self:getProperty(obj, propertyName, value, ...)
	if not targetProperty then
		return
	end

	targetProperty:skipSetter()
	targetProperty:deserialize(obj, propertyName, value, resources, ...)
end

function Dynamic:getSharedMatch(obj, propertyName, value, resources, ...)
	local targetProperty = self:getProperty(obj, propertyName, value, ...)
	if not targetProperty then
		return
	end

	local ownType = targetProperty.TYPE
	for i = 1, #resources do
		local resReference = resources[i]
		if resReference.TYPE == ownType and self:areEqual(resReference.value, value) then
			-- Found match, do nothing
			return i, resReference
		end
	end

	-- No match, return the new reference
	return nil, self:getReference(obj, propertyName, value, resources, ...)
end

function Dynamic:getReference(obj, propertyName, value, resources, ...)
	local targetProperty = self:getProperty(obj, propertyName, value, ...)
	if not targetProperty then
		return
	end

	return targetProperty:getReference(obj, propertyName, value, resources, ...)
end

return Dynamic
