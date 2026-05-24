local Property = require "property"

---@class Property.String: Property
local String = Property:extend()
String.TYPE = "string"

function String:new(class, property, defaultValue, maxLength, validator, setter)
	String.super.new(self, class, property, defaultValue or class[property] or "")
	self.maxLength = maxLength or math.huge

	---@type fun(val: string): boolean
	self.validator = validator
	if setter then self:withSetter(setter) end
end

function String:add(a, b)
	return a..b
end

function String:sanitize(val)
	-- Can't sanitize a string
	return val
end

function String:isValid(val)
	if #val > self.maxLength then return false end
	local v = self.validator
	if v and not v(val) then return false end

	return true
end

return String
