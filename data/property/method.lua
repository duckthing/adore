local Property = require "data.property"

---@class Property.Method: Property
local Method = Property:extend()
Method.TYPE = "Method"
Method.isConstant = true

function Method:new(class, methodName, label)
	Method.super.new(self, class, methodName)
	---@type string # The human-readable name of this method
	self.label = label or methodName
end

return Method
