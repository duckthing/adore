local Property = require "property"

---@class Property.Any: Property
local Any = Property:extend()
Any.TYPE = "any"

local t = type(1)
local serializable = {
	boolean = true,
	number = true,
	string = true,
	-- TODO: Should tables be exluded from serialization as an 'any'?
	-- Their references won't get simplified, like the table property will.
	table = true,
}
function Any:serialize(obj, propertyName, value, resources)
	local val = self:get(obj, propertyName)
	if serializable[val] then
		return val
	end
	return nil
end

return Any
