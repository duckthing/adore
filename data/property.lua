---@type AdoreInit
local Adore = require ""
local SimpleObject = Adore.Libraries("SimpleObject")

---VIRTUAL! Don't use this!
---@class Property: SimpleObject
---@field super Property
local Property = SimpleObject:extend()
---@type ClassDB
Property.ClassDB = nil
---@type ObjectSaver
Property.ObjectSaver = nil

Property.TYPE = "Property"
Property.IS_BINARY = false
---@type {[string]: Property} # Properties of a data type (ex. Vec2 has x/y number subproperties)
---Nested subproperties do not work right now. (ex. 'Transform.scale.x' won't work)
Property.subproperties = {}
---@type boolean # Pokeable properties will 'poked' when their immediate, unpokeable subproperty is updated.
---'Pokeable' properties are important because they usually have a setter attached.
---ex. In 'transform.position.x', if 'position' is unpokeable, 'transform' will get poked when 'x' is changed.
Property.canPoke = true

---@alias Property.DeferMode
---| false # The value will get de/serialized when requested
---| "unique" # The value will get copied; works similar to normal de/serialization, but must be performed manually
---| "shared" # The value will reference an index in an array of values, preventing duplication of large values

---@type Property.DeferMode # When deserialized and truthy, this Property will have a value that can be deserialized later (as the 3rd return value under ObjectSaver.deserialize)
Property.DEFER_MODE = false

Property.isConstant = false
Property.isHeader = false
Property.visible = true

---Creates a new Property
---@param class Object
---@param propertyName string
---@param defaultValue any
function Property:new(class, propertyName, defaultValue)
	---@type any # The default value of this Property
	self.defaultValue = defaultValue
	if defaultValue == nil then
		self.defaultValue = class[propertyName] or self:newValue()
	end
	self.propertyName = propertyName
	---@type Property? # If this Property is a subproperty, the super property is what this one is a part of
	self.superProperty = nil

	---@type {[Property]: Property}? # Property to proxy map; don't use directly
	self._proxyTable = nil
end

---Returns a clone of the default value
---@return any clone
function Property:newValue()
	return self.defaultValue
end

---Gets the value using this Property from `obj` under `propertyName`
---@param obj Object
---@param propertyName string
---@return any value
function Property:get(obj, propertyName)
	return obj[propertyName]
end

---Sets the value on an Object
---@param obj Object
---@param propertyName string
---@param value any
function Property:set(obj, propertyName, value)
	obj[propertyName] = self:sanitize(value)
end

---Debug method for calling the setter with the current value
---@param obj Object
---@param propertyName string
function Property:poke(obj, propertyName)
	self:set(obj, propertyName, self:get(obj, propertyName))
end

---Sets the value on an Object without using a setter method
---@type fun(property: Property, obj: Object, propertyName: string, value: any)
Property.rawSet = Property.set

function Property:add(a, b)
	return a + b
end

function Property:sanitize(val)
	-- Can't sanitize an unknown value
	return val
end

function Property:isValid(val)
	return true
end

function Property:stepTowards(from, to, amount)
	return from
end

function Property:lerp(start, final, percent)
	if percent >= 1 then
		return final
	end
	return start
end

function Property:isDefault(v)
	return self:areEqual(self.defaultValue, v)
end

function Property:areEqual(a, b)
	return a == b
end

---Returns the index of a match found in the shared resources array along with the match.
---If no match it found, it returns `nil` and a table that allows this Property to detect matches.
---@param obj Object
---@param propertyName string
---@param value any
---@param resources any[]
---@param ...Object # If this Property is a part of another Property (like a Map), all tuples will be earlier Objects
---@return integer? index
---@return table reference
function Property:getSharedMatch(obj, propertyName, value, resources, ...)
	local ownType = self.TYPE
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

---Creates a reference from the given values;
---this method is only useful for deferred shared properties
---@param obj Object
---@param propertyName string
---@param value any
---@param resources any[]
---@param ...Object # If this Property is a part of another Property (like a Map), all tuples will be earlier Objects
---@return table
function Property:getReference(obj, propertyName, value, resources, ...)
	return {
		TYPE = self.TYPE,
		value = value,
	}
end

---Returns a plain Lua type that can be serialized easily. Can be a table.
---@param obj Object
---@param propertyName string
---@param value any
---@param resources any[]?
---@param ...Object # If this Property is a part of another Property (like a Map), all tuples will be earlier Objects
---@return any
function Property:serialize(obj, propertyName, value, resources, ...)
	return value
end

---Sets a Property from a deserialized Lua value.
---If the Property is binary data, this function will not be called.
---@param obj Object
---@param propertyName string
---@param deserializedValue any
---@param resources any[]?
---@param ...Object # If this Property is a part of another Property (like a Map), all tuples will be earlier Objects
function Property:deserialize(obj, propertyName, deserializedValue, resources, ...)
	self:set(obj, propertyName, deserializedValue)
end

---Reads binary data from a string.buffer and sets it in an Object (performed while deserializing).
---@param obj Object
---@param propertyName string
---@param deserializedValue any # The serialized value that was returned previously
---@param buffer string.buffer
function Property:unpackBuffer(obj, propertyName, deserializedValue, buffer)
end

---Puts binary data into a string.buffer.
---@param obj Object
---@param propertyName string
---@param buffer string.buffer
---@param resources any[]
function Property:packBuffer(obj, propertyName, buffer, resources)
end

---Serializes a BINARY reference value into the buffer.
---If it isn't binary, this function won't be called; it will use whatever the reference contained.
---@param buffer string.buffer
---@param reference any # From :getReference()
---@param resources any[]
function Property.packBufferResource(buffer, reference, resources)
end

---Deserializes a BINARY reference value from the buffer
---If it isn't binary, this function won't be called; it will use whatever the reference contained.
---@param buffer string.buffer
---@param reference any # From :getReference()
---@param resources any[]
function Property.unpackBufferResource(buffer, reference, resources)
end

---Skips the setter for the next call; mainly used internally
-- TODO: Replace with a stack
function Property:skipSetter()
	if self.setter then
		self.oldSetter = self.setter
		self.setter = nil
	end
end

---Used in case there is a setter method
---@param self Property.Boolean
---@param obj Object
---@param property string # Unused, using setter instead
---@param value number
local function useNormalSetter(self, obj, property, value)
	if not self.setter then
		obj[property] = self:sanitize(value)
		self.setter = self.oldSetter
	else
		obj[self.setter](obj, self:sanitize(value))
	end
end

---Sets the value and then calls the method
---@param self Property.Boolean
---@param obj Object
---@param property string # Unused, using setter instead
---@param value number
local function usePostSetter(self, obj, property, value)
	if not self.setter then
		obj[property] = self:sanitize(value)
		self.setter = self.oldSetter
	else
		obj[property] = self:sanitize(value)
		obj[self.setter](obj)
	end
end


---Uses this setter method (name) when attempting to set this property
---@param setterName string
function Property:withSetter(setterName)
	if setterName:match("^%%") then
		-- Use post setter
		self.setter = setterName:match("^%%(.*)")
		self.set = usePostSetter
	else
		-- Not special
		self.setter = setterName
		self.set = useNormalSetter
	end
end

---Makes this Property unpokable
---@generic T: Property
---@param self T
---@return T
function Property:makeUnpokable()
	self.canPoke = false
	return self
end

---Creates a proxy that refers to `superProperty`'s returned object as its own passed object.
---Basically, referring to a specific subproperty is like normal.
---@param superProperty Property
---@return table|Property
function Property:asProxy(superProperty)
	local proxyTable = self._proxyTable
	if not proxyTable then
		proxyTable = setmetatable({}, {__mode = 'k'})
		self._proxyTable = proxyTable
	end

	do
		-- Return an existing proxy
		local existing = proxyTable[superProperty]
		if existing then
			return existing
		end
	end

	-- Create a new proxy, and add it to the table
	local superPropertyName = superProperty.propertyName
	local proxy = setmetatable(
		{
			get = function(_, object, propertyName)
				local val = superProperty:get(object, superPropertyName)
				return self.get(self, val, propertyName)
			end,
			set = function(_, object, propertyName, value)
				local val = superProperty:get(object, superPropertyName)
				self.set(self, val, propertyName, value)
				if superProperty.setter then
					superProperty:poke(object, superPropertyName)
				end
			end
		},
		{
			__index = self
		}
	)
	proxyTable[superProperty] = proxy

	return proxy
end

function Property:__tostring()
	if self.propertyName then
		-- It's an instance
		return ("%s[%s]"):format(self.TYPE, self.propertyName)
	else
		-- It's the Class itself
		return ("'%s'"):format(self.TYPE)
	end
end

return Property
