---@type Property
local Property = require "data.property"

---@class Property.Object: Property
local Object = Property:extend()
Object.TYPE = "Object"
Object.IS_BINARY = true
Object.DEFER_MODE = "shared"

function Object:new(class, property, baseClass, setter)
	Object.super.new(self, class, property)

	---@type string
	self.baseClass = baseClass or "Object"

	if setter then self:withSetter(setter) end
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
	Property.ObjectSaver.serializeObjectToBuffer(value, buffer, resources)
end

function Object.unpackBufferResource(buffer, reference, resources)
	local err, obj, deferredProperties = Property.ObjectSaver.deserializeFromBuffer(buffer)
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
		Property.ObjectSaver.setDeferredProperties(parsedObject, deferred, resources)
	end

	self:set(obj, propertyName, parsedObject)
end

---Gets the address string of the table
---@param t table
---@return string
local function getAddr(t)
	local oldMT = getmetatable(t)
	setmetatable(t, nil)
	local addr = tostring(t)
	setmetatable(t, oldMT)
	return addr
end

function Object:getSharedMatch(obj, propertyName, value, resources)
	local ownType = self.TYPE
	local ownValueAddr = getAddr(value)
	for i = 1, #resources do
		local resReference = resources[i]
		if resReference.TYPE == ownType and value == resReference.value then
			-- Found match, do nothing
			return i, resReference
		end
	end

	-- No match, return the new reference
	return nil, self:getReference(obj, propertyName, value, resources)
end

function Object:getReference(obj, propertyName, value, resources)
	local header, body = Property.ObjectSaver.getPropertyPairs(value, resources)
	return setmetatable({
		TYPE = self.TYPE,
		header = header,
		body = body,
	}, {__index = {value = value}}
	)
end

return Object
