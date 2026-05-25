local Number = require "data.property.number"
local floor = math.floor

---@class Property.Integer: Property.Number
---@field super Property.Number
local Integer = Number:extend()
Integer.TYPE = "integer"
Integer.step = 1

return Integer
