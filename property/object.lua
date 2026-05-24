---@type AdoreInit
local Adore = require ""
local Property = require "property"
local StringBuffer = require "_G.string.buffer"
local ObjectSaver = Adore.Common("ObjectSaver")

---@class Property.Object: Property
local Object = Property:extend()
Object.TYPE = "Object"
Object.IS_BINARY = true
Object.DEFER_MODE = "shared"

function Object:new(class, property, baseClass)
	Object.super.new(self, class, property)

	---@type string
	self.baseClass = baseClass or "Object"
end

function Object:newValue()
	return nil
end

function Object:sanitize(val)
	-- Can't sanitize an Object
	return val
end

function Object.packBufferResource(buffer, reference, resources)
	local value = reference.value
	ObjectSaver.serializeObject(value, buffer, resources)
end

function Object.unpackBufferResource(buffer, reference, resources)
	local err, obj, deferredProperties = ObjectSaver.deserializeFromBuffer(buffer)
	reference.value = obj
	reference.deferredProperties = deferredProperties
end

function Object:serialize(obj, propertyName, value, resources)
	-- TODO: Search Objects for shared resources too
	local index, ref = self:getSharedMatch(obj, propertyName, value, resources)
	if not index then
		index = #resources + 1
		resources[index] = ref
	end
	return index
end

function Object:deserialize(obj, propertyName, value, resources)
	-- Do nothing; we unpack the buffer later
	-- When deferred, this function gets called later.
	-- When deferred and reliant on a shared resource, the `value` parameter will be whatever `:serialize()` returned.
	-- (which tends to be the ID to a resource)

	local reference = resources[value]
	local parsedObject = reference.value
	local deferred = reference.deferredProperties

	if deferred then
		-- Set any deferred properties, and remove it so later `:deserialize()` calls don't do it again
		reference.deferredProperties = nil
		ObjectSaver.setDeferredProperties(parsedObject, deferred, resources)
	end

	self:set(obj, propertyName, parsedObject)
end

return Object
