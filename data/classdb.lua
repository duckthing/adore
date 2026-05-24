---@class ClassDB
local ClassDB = {}
---@type ClassDB.Entry
local ClassDBEntry = require "data.classdbentry"

---@class ClassDB.Info
---@field super Object?
---@field superInfo ClassDB.Info?
---@field nameToProperty {[string]: Property}
---@field propertyList Property[]
---@field allowSerialization boolean?
---@field allowDeserialization boolean?
local ClassInfo = {}
local ClassInfoMT = {__index = function(self, k)
	local super = rawget(self, "super")
	return (super and super[k]) or nil
end}

---@type {[integer]: ClassDB.Info}
local classInfoMap = {}
---@type {[string]: Object}
local classNameToClass = {}
---@type {[integer]: ClassDB.Entry}
local classIdToEntry = {}

ClassDB.ClassInfo = classInfoMap
ClassDB.ClassNameToClass = classNameToClass

---(Registers itself and super classes, and) returns the ClassDBEntry used for registering new properties.
---Only call this once the class name was set!
---@param class Object
---@return ClassDB.Entry
function ClassDB.getClassDBEntry(class)
	-- TODO: Check if getting a later entry affects getting earlier entries
	local classId = rawget(class, "CLASS_ID")
	if not classId then
		-- In case we got an instance of a class, and not the class itself
		class = class.__index
		classId = class.CLASS_ID
		assert(classId, "Passed value is not a valid Object")
		---@cast class Object
	end

	if classInfoMap[classId] == nil then
		---@class ClassDB.Info
		local info = {
			class = class.__index,
			super = class.super,
			superInfo = class.super and ClassDB.getClassDBEntry(class.super)._info,
			nameToProperty = {},
			propertyList = {},
			allowDeserialization = nil,
			allowSerialization = nil,
		}

		-- Insert the created data
		classInfoMap[classId] = setmetatable(info, ClassInfoMT)
		classIdToEntry[classId] = ClassDBEntry.new(class, info)

		local existingClass = classNameToClass[class.CLASS_NAME]
		if not existingClass then
			-- Insert this into the class name lookup
			classNameToClass[class.CLASS_NAME] = class
		elseif existingClass ~= class then
			-- Normally, an existing class means you're attempting a duplicate.
			-- If `existingClass` equals `class`, it means hot reloading (with Lurker) occured, and can be ignored.
			-- If not, and already registered, it's likely a duplicate.
			error(("Attempted to register similar class '%s' when one already exists; are your class names unique?"):format(class.CLASS_NAME))
		end
	end
	return classIdToEntry[class.CLASS_ID]
end

---Returns `true` if the `targetClass` inherits from or matches `baseClass`
---@param baseClass string | Object
---@param targetClass string | Object
function ClassDB.doesClassInherit(baseClass, targetClass)
	-- Converts from class object to class name
	if type(baseClass) == "string" then baseClass = classNameToClass[baseClass] end
	if type(targetClass) == "string" then targetClass = classNameToClass[targetClass] end

	return targetClass:is(baseClass)
end

return ClassDB
