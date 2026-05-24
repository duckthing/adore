local Property = require "property"

---@class Property.Table: Property
local Table = Property:extend()
Table.TYPE = "table"
Table.DEFER_MODE = "shared"

function Table:new(class, property, defaultValue, setter)
	Table.super.new(self, class, property, defaultValue or class[property])
	if setter then self:withSetter(setter) end
end

function Table:newValue()
	return {}
end

function Table:add(a, b)
	return a
end

function Table:sanitize(val)
	return (self:isValid(val) and val) or {}
end

function Table:isValid(val)
	return type(val) == "table"
end

function Table:serialize(obj, propertyName, value, resources)
	-- TODO: Search tables for shared resources too
	local index, ref = self:getSharedMatch(obj, propertyName, value, resources)
	if not index then
		index = #resources + 1
		resources[index] = ref
	end
	return index
end

function Table:deserialize(obj, propertyName, value, resources)
	-- Do nothing; we unpack the buffer later
	-- When deferred, this function gets called later.
	-- When deferred and reliant on a shared resource, the `value` parameter will be whatever `:serialize()` returned.
	-- (which tends to be the ID to a resource)

	-- TLDR
	-- * `value` is the ID to the table in `resources`
	-- * `resources[id]/resources[value]` gets the reference
	-- * `reference.value` gets the decoded table

	self:set(obj, propertyName, resources[value].value)
end

return Table

