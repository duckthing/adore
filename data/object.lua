-- The one under ./lib/classic (SimpleObject) is the original Classic, with some type hints.
-- This one (Object) is a copy of that one, plus inheritance tracking and ClassDB support.
-- + Use this one if you'd like to serialize objects easily

---@class Object
---@field super self
---@field CLASS_ID integer
---@field CLASS_NAME string
---@field INHERITED_BY Object[]
---@overload fun(): Object
local Object = {}
Object.__index = Object
Object.CLASS_ID = 1
Object.CLASS_NAME = "Object"
Object.INHERITED_BY = {}

---@type AdoreInit
local Adore = require ""
local SimpleObject = Adore.Libraries("SimpleObject")
local ClassDB = Adore.Common("ClassDB")
local createdClasses = 1

---@generic T
---@param self T
---@return unknown
function Object:extend()
	local cls = SimpleObject.extend(self)

	createdClasses = createdClasses + 1
	self.INHERITED_BY[#self.INHERITED_BY+1] = cls
	cls.CLASS_ID = createdClasses
	cls.CLASS_NAME = ("(Inherits) %s"):format(self.CLASS_NAME)
	cls.INHERITED_BY = {}

	return cls
end

function Object:__tostring()
	return self.CLASS_NAME
end

Object.new = SimpleObject.new
Object.implement = SimpleObject.implement
Object.is = SimpleObject.is
Object.__call = SimpleObject.__call

---Called after this Object is serialized, but before its buffer data is finalized. (Header and body is already inserted).
---Put binary data into the buffer here.
---@param buffer string.buffer
---@param header table
---@param body table
function Object:_afterSerialized(buffer, header, body)
end

---Called after this Object is deserialized; you can read anything inserted by `_afterSerialized()` here.
---@param buffer string.buffer
---@param header table
---@param body table
function Object:_afterDeserialized(buffer, header, body)
end

---Returns the ClassDB.Entry for this class.
---If it does not exist, a new ClassDB.Entry will be made, which runs `._addDefinition()` on it.
---@return ClassDB.Entry
function Object:getClassDBEntry()
	return ClassDB.getClassDBEntry(self)
end

---Override this method with any definitions that are **specific** to this class.
---Make sure you aren't using this as a method (`._addDefinition()` vs. `:_addDefinition()`)
---@param entry ClassDB.Entry
function Object._addDefinition(entry)
	entry:newString("CLASS_NAME")
		:moveToHeader()
		:makeConstant()
		:hide()
	entry:setSerialization(true, true)
end
Object:getClassDBEntry()

return Object
