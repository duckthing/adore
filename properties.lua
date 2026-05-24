---@type Property
local Property = require "property"

---@alias PropertyType
---| "any"
---| "number"
---| "integer"
---| "string"
---| "boolean"
---| "table"
---| "string.buffer" # Not supported on the web
---| "Vec2"
---| "Color"
---| "Signal"
---| "NodeRef"

local stringBuffer
if pcall(require, "_G.string.buffer") then
	stringBuffer = require "property.stringbuffer"
end

---@type {[PropertyType]: Property}
local Properties = {
	---@type Property.Any
	any = require "property.any",

	---@type Property.Number
	number = require "property.number",
	---@type Property.Integer
	integer = require "property.integer",
	---@type Property.String
	string = require "property.string",
	---@type Property.Boolean
	boolean = require "property.boolean",
	---@type Property.Table
	["table"] = require "property.table",
	---@type Property.StringBuffer
	["string.buffer"] = stringBuffer,

	---@type Property.Vec2
	Vec2 = require "property.vec2",
	---@type Property.Color
	Color = require "property.color",
	---@type Property.Signal
	Signal = require "property.signal",
	---@type Property.NodeRef
	NodeRef = require "property.noderef",
}

local PropertiesMT = {
	__index = {
		setClassDB = function(self)
			Property.ClassDB = self
		end
	}
}

return setmetatable(Properties, PropertiesMT)
