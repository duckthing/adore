---@type Property
local Property = require "data.property"

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
	stringBuffer = require "data.property.stringbuffer"
end

---@type {[PropertyType]: Property}
local Properties = {
	---@type Property.Any
	any = require "data.property.any",

	---@type Property.Number
	number = require "data.property.number",
	---@type Property.Integer
	integer = require "data.property.integer",
	---@type Property.String
	string = require "data.property.string",
	---@type Property.Boolean
	boolean = require "data.property.boolean",
	---@type Property.Table
	["table"] = require "data.property.table",
	---@type Property.StringBuffer
	["string.buffer"] = stringBuffer,

	---@type Property.Vec2
	Vec2 = require "data.property.vec2",
	---@type Property.Rect2
	Rect2 = require "data.property.rect2",
	---@type Property.Color
	Color = require "data.property.color",
	---@type Property.Signal
	Signal = require "data.property.signal",
	---@type Property.NodeRef
	NodeRef = require "data.property.noderef",
	---@type Property.AssetPath
	AssetPath = require "data.property.assetpath",
	---@type Property.Object
	Object = require "data.property.object",
	---@type Property.LoveObject
	LoveObject = require "data.property.loveobject",
}

local PropertiesMT = {
	__index = {
		setClassDB = function(ClassDB)
			Property.ClassDB = ClassDB
		end
	}
}

return setmetatable(Properties, PropertiesMT)
