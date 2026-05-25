local Property = require "data.property"
local StringBuffer = require "_G.string.buffer"

---@class Property.StringBuffer: Property
local SBProperty = Property:extend()
SBProperty.TYPE = "string.buffer"
SBProperty.IS_BINARY = true

function SBProperty:new(class, property)
	SBProperty.super.new(self, class, property, nil)
end

function SBProperty:newValue()
	return StringBuffer.new()
end

function SBProperty:add(a, b)
	return a..b
end

function SBProperty:sanitize(val)
	-- Can't sanitize a string.buffer
	return val
end

---@param a string.buffer
---@param b string.buffer
---@return boolean
function SBProperty:areEqual(a, b)
	if a == nil then
		if b == nil then
			-- Both are nil
			return true
		end
		-- One is nil
		return false
	elseif b == nil then
		-- One is nil
		return false
	end

	local aPtr, _ = a:ref()
	local bPtr, _ = b:ref()

	-- Comparing contents isn't worth it, compare their pointers instead
	return aPtr == bPtr
end

function SBProperty:serialize(obj, propertyName, value)
	---@type string.buffer
	local buffer = obj[propertyName]
	return {
		size = #buffer,
	}
end

function SBProperty:deserialize(obj, propertyName, value)
	-- Do nothing; we unpack the buffer later
	-- This function isn't called at all when the Property is binary data
	-- (but whatever was returned by `:serialize()` is passed in `:unpackBuffer()` as `deserializedValue`)
end

function SBProperty:unpackBuffer(obj, propertyName, deserializedValue, fromBuffer)
	-- Transfer data from `fromBuffer` into `ownBuffer`

	---@type string.buffer
	local ownBuffer = obj[propertyName]
	local length = deserializedValue.size
	ownBuffer:reserve(length)
	ownBuffer:reset()
	local remaining = length

	while remaining > 0 and #fromBuffer > 0 do
		local ptr, len = fromBuffer:ref()
		len = math.min(remaining, len)
		ownBuffer:putcdata(ptr, len)
		fromBuffer:skip(len)
		remaining = remaining - len
	end

	if remaining ~= 0 then
		error(("Buffer ended before remaining length was read (needed %d more for a total of %d)"):format(remaining, length))
	end
end

function SBProperty:packBuffer(obj, propertyName, buffer)
	---@type string.buffer
	local ownBuffer = obj[propertyName]
	buffer:put(ownBuffer)
end

return SBProperty
