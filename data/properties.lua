---@type Property
local Property = require "data.property"

local StringBuffer
if pcall(require, "_G.string.buffer") then
	StringBuffer = require "data.property.stringbuffer"
end

---@enum (key) PropertyType
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
	table = require "data.property.table",
		---@type Property.Array
		array = require "data.property.array",
		---@type Property.Map
		map = require "data.property.map",
		---@type Property.Struct
		struct = require "data.property.struct",
	---@type Property.StringBuffer
	["string.buffer"] = StringBuffer,

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

	---@type Property.Dynamic
	Dynamic = require "data.property.dynamic",
}

local PropertiesMT = {
	__index = {
		setClassDB = function(ClassDB)
			Property.ClassDB = ClassDB
		end
	}
}

return setmetatable(Properties, PropertiesMT)
