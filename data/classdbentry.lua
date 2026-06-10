---@type AdoreInit
local Adore = require ""
---@type {[string]: Property}
local Properties = require "data.properties"
local Structures = Adore.Common("Structures")
local Set = Structures.Set
local tclear = Structures.tableClear

---@type Property[] # Internal array
local _arr = {false, false, false}

---@class ClassDB.Entry
---@field _class Object
---@field _info ClassDB.Info
---@field _lastProperty Property?
---@field _lastPropertyName string?
local ClassDBEntry = {}
local ClassDBEntryMT = {
	__index = ClassDBEntry,
}

ClassDBEntry.Adore = Adore

---Creates a new ClassDB.Entry, adds the definitions from the class, and returns it.
---You shouldn't call this, as it should be created automatically inside ClassDB.
---@param class Object # The **class** object, not its name
---@param info ClassDB.Info
function ClassDBEntry.new(class, info)
	---@class ClassDB.Entry
	local entry = {
		_class = class,
		_info = info,
		---@diagnostic disable-next-line: assign-type-mismatch
		_lastProperty = false,
		_lastPropertyName = "",
	}
	setmetatable(entry, ClassDBEntryMT)

	-- Adds the definitions, if the function exists
	local func = rawget(class, "_addDefinition")
	if func then
		func(entry)
	end

	-- Usually the default name is the CLASS_NAME, so we insert it automatically
	if not entry:getProperty("name", false) then
		entry:newString("name", class.CLASS_NAME)
	end

	return entry
end

---Returns `true` if any inherited classes allow deserializing.
function ClassDBEntry:canDeserialize()
	local info = self._info
	while info do
		local mode = info.allowDeserialization
		if mode ~= nil then
			-- Non-nil mode found, return it
			return mode
		else
			-- Go up
			info = info.superInfo
		end
	end

	-- No mode found
	return false
end

---Returns `true` if any inherited classes allow serializing.
function ClassDBEntry:canSerialize()
	local info = self._info
	while info do
		local mode = info.allowSerialization
		if mode ~= nil then
			-- Non-nil mode found, return it
			return mode
		else
			-- Go up
			info = info.superInfo
		end
	end

	-- No mode found
	return false
end

---Sets whether de/serialization is allowed from this point. Pass `nil` to inherit.
---First parameter is for serialization, while the second is for deserialization.
---@param serialize boolean?
---@param deserialize boolean?
function ClassDBEntry:setSerialization(serialize, deserialize)
	local info = self._info
	info.allowSerialization, info.allowDeserialization =
		serialize, deserialize
end

---Creates a Property by looking it up and passing the given parameters.
---Difficult to debug; it's recommended to use other methods.
---@deprecated
---@param propertyName string
---@param propertyType string
---@param ... unknown
---@return self
function ClassDBEntry:newProperty(propertyName, propertyType, ...)
	local PropertyClass = Properties[propertyType]
	if not PropertyClass then
		error(("'%s' type not found (for property '%s')"):format(propertyType, propertyName))
	end

	local class = self._class
	local info = self._info

	local propertyOrError = PropertyClass(class, propertyName, ...)

	if type(propertyOrError) == "table" then
		-- No error, made the property
		---@cast propertyOrError Property
		self:insertProperty(propertyOrError)
	else
		-- TODO: This might need to be removed
		-- Returning anything else is an error
		error(("Error creating '%s' for '%s': %s"):format(propertyType, propertyName, propertyOrError))
	end
	return self
end

---Inserts an already created Property
---@param property Property
---@return self
function ClassDBEntry:insertProperty(property)
	local propertyName = property.propertyName
	local info = self._info

	self._lastProperty = property
	self._lastPropertyName = propertyName

	info.nameToProperty[propertyName] = property
	info.propertyList[#info.propertyList+1] = property
	return self
end

---Removes the last created Property
---@return Property
function ClassDBEntry:popProperty()
	local info = self._info

	local property = self:getInsertedProperty()
	self._lastProperty = nil
	info.propertyList[#info.propertyList] = nil

	info.nameToProperty[self._lastPropertyName] = nil
	self._lastPropertyName = nil
	return property
end

---Moves the last inserted Property into the header.
---This will make it available for reading in the header before parsing the rest of a serialized Object.
---@return self
function ClassDBEntry:moveToHeader()
	self:getInsertedProperty().isHeader = true
	return self
end

---Makes the last inserted Property constant; set operations will be avoided.
---@return self
function ClassDBEntry:makeConstant()
	self:getInsertedProperty().isConstant = true
	return self
end

---Hides the last inserted Property via `property.visible = false`.
---This is only useful if you make an editor tool; it will still appear when iterating and serializing.
---@return self
function ClassDBEntry:hide()
	self:getInsertedProperty().visible = false
	return self
end

---Sets the default value
---@param value any
---@return self
function ClassDBEntry:withDefault(value)
	self:getInsertedProperty().defaultValue = value
	return self
end

---Makes the Property use the setter (method name).
---@param methodName string
---@return self
function ClassDBEntry:setter(methodName)
	self:getInsertedProperty():withSetter(methodName)
	return self
end

---Adds a Property.Any
---@param name string
---@param defaultValue any
---@param setter string?
---@return self
function ClassDBEntry:newAny(name, defaultValue, setter)
	local property = Properties.any(self._class, name, defaultValue)
	if setter then
		property:withSetter(setter)
	end
	self:insertProperty(property)
	return self
end

---Adds a Property.Number
---@param name string
---@param defaultValue number?
---@param min number?
---@param max number?
---@param step number?
---@param setter string?
---@return self
function ClassDBEntry:newNumber(name, defaultValue, min, max, step, setter)
	self:insertProperty(Properties.number(self._class, name, defaultValue, min, max, step, setter))
	return self
end

---Adds a Property.Integer
---@param name string
---@param defaultValue number?
---@param min number?
---@param max number?
---@param step number?
---@param setter string?
---@return self
function ClassDBEntry:newInteger(name, defaultValue, min, max, step, setter)
	self:insertProperty(Properties.integer(self._class, name, defaultValue, min, max, step, setter))
	return self
end

---Adds a Property.String
---@param name string
---@param defaultValue string?
---@param maxLength integer?
---@param validator (fun(val: string): boolean)?
---@param setter string?
---@return self
function ClassDBEntry:newString(name, defaultValue, maxLength, validator, setter)
	self:insertProperty(Properties.string(self._class, name, defaultValue, maxLength, validator, setter))
	return self
end

---Adds a Property.Boolean
---@param name string
---@param defaultValue boolean?
---@param setter string?
---@return self
function ClassDBEntry:newBoolean(name, defaultValue, setter)
	self:insertProperty(Properties.boolean(self._class, name, defaultValue, setter))
	return self
end

---Adds a Property.Table
---@param name string
---@param defaultValue table?
---@param setter string?
---@return self
function ClassDBEntry:newTable(name, defaultValue, setter)
	self:insertProperty(Properties.table(self._class, name, defaultValue, setter))
	return self
end

---Adds a Property.Map
---@param name string
---@param keyProperty Property
---@param valueProperty Property
---@param defaultValue table?
---@param setter string?
---@return self
function ClassDBEntry:newMap(name, keyProperty, valueProperty, defaultValue, setter)
	self:insertProperty(Properties.map(self._class, name, keyProperty, valueProperty, defaultValue, setter))
	return self
end

---Adds a Property.Array
---@param name string
---@param valueProperty Property
---@param defaultValue table?
---@param setter string?
---@return self
function ClassDBEntry:newArray(name, valueProperty, defaultValue, setter)
	self:insertProperty(Properties.array(self._class, name, valueProperty, defaultValue, setter))
	return self
end

---Adds a Property.Struct
---@param name string
---@param definition {[string]: Property}
---@param defaultValue table?
---@param setter string?
---@return self
function ClassDBEntry:newStruct(name, definition, defaultValue, setter)
	self:insertProperty(Properties.struct(self._class, name, definition, defaultValue, setter))
	return self
end

---Adds a Property.StringBuffer
---@param name string
---@return self
function ClassDBEntry:newStringBuffer(name)
	self:insertProperty(Properties["string.buffer"](self._class, name))
	return self
end

---Adds a Property.Object
---@param name string
---@param baseClass string?
---@param setter string?
function ClassDBEntry:newObject(name, baseClass, setter)
	self:insertProperty(Properties.Object(self._class, name, baseClass, setter))
	return self
end

---Adds a Property.LoveObject
---@param name string
---@param baseClass string?
---@param setter string?
function ClassDBEntry:newLoveObject(name, baseClass, setter)
	self:insertProperty(Properties.LoveObject(self._class, name, baseClass, nil, setter))
	return self
end

---Adds a Property.Enum.
---Pass a function as `valueMap` if you'd like to dynamically get the valid values.
---@param name string
---@param valueMap {[string | number | boolean]: any} | fun(self: Property.Enum, object: Object, propertyName: string?): {[string | number | boolean]: any}
---@param defaultValue string | number | boolean | nil
---@param setter string?
function ClassDBEntry:newEnum(name, valueMap, defaultValue, setter)
	self:insertProperty(Properties.Enum(self._class, name, valueMap, defaultValue, setter))
	return self
end

---Adds a Property.Vec2
---@param name string
---@param defaultValue Vec2?
---@param setter string?
---@return self
function ClassDBEntry:newVec2(name, defaultValue, setter)
	self:insertProperty(Properties.Vec2(self._class, name, defaultValue, setter))
	return self
end

---Adds a Property.Rect2
---@param name string
---@param defaultValue Rect2?
---@param setter string?
---@return self
function ClassDBEntry:newRect2(name, defaultValue, setter)
	self:insertProperty(Properties.Rect2(self._class, name, defaultValue, setter))
	return self
end

---Adds a Property.Color
---@param name string
---@param defaultValue integer[]?
---@param colorSpace string?
---@param setter string?
---@return self
function ClassDBEntry:newColor(name, defaultValue, colorSpace, setter)
	self:insertProperty(Properties.Color(self._class, name, defaultValue, colorSpace, setter))
	return self
end

---Adds a Property.Signal.
---Signal properties **CANNOT** belong to the static class; it must be instanced for every Node!
---@param name string
---@return self
function ClassDBEntry:newSignal(name)
	self:insertProperty(Properties.Signal(self._class, name))
	return self
end

---Adds a Property.NodeRef
---@param name string
---@param baseClass string | Node | nil # The class to inherit from; the class name and object both work here
---@param setter string?
---@return self
function ClassDBEntry:newNodeRef(name, baseClass, setter)
	self:insertProperty(Properties.NodeRef(self._class, name, baseClass, setter))
	return self
end

---Adds a Property.AssetPath
---@param name string
---@param collectionName string # The collection this asset will be from
---@param defaultValue string?
---@param setter string?
---@return self
function ClassDBEntry:newAssetPath(name, collectionName, defaultValue, setter)
	self:insertProperty(Properties.AssetPath(self._class, name, collectionName, defaultValue, setter))
	return self
end

---Adds a Property.Dynamic; used internally, you might want something else
---@param name string
---@param propertyGetter Property.Dynamic.Getter # Gets the desired Property on every access
---@param defaultValue any?
---@param setter string?
---@return self
function ClassDBEntry:newDynamic(name, propertyGetter, defaultValue, setter)
	self:insertProperty(Properties.Dynamic(self._class, name, propertyGetter, defaultValue, setter))
	return self
end

---Gets the last inserted Property by this ClassDB.Entry.
---This only works AFTER inserting a property:
---`entry:addProperty(...):getInsertedProperty()`
---@return Property
function ClassDBEntry:getInsertedProperty()
	local last = self._lastProperty
	if not last then
		error("Attempted to get the last inserted property without inserting any properties")
	end
	return last
end

---Gets the property by name. If recursive is `true`/`nil`, it will search parent classes too.
---If requesting a subproperty (ex. the `x` of a `Vec2`), it returns a proxy for it that handles get/sets.
---@param propertyName string
---@param recursive boolean? # (default: `true`) Search super classes
---@return Property? requestedProperty
function ClassDBEntry:getProperty(propertyName, recursive)
	if recursive == nil then recursive = true end

	-- Get the parent property's name
	local subpropertyCharStart = propertyName:find("%.")
	local originalName
	if subpropertyCharStart then
		originalName = propertyName
		propertyName = propertyName:sub(1, subpropertyCharStart - 1)
	end

	-- Get that property
	local info = self._info
	local p = info.nameToProperty[propertyName]
	if recursive then
		while not p do
			info = info.superInfo
			if not info then
				break
			end
			p = info.nameToProperty[propertyName]
		end
	end

	if subpropertyCharStart then
		-- We're looking for a subproperty, wrap it so set/gets poke the correct property
		if not p then
			error(("Could not find property '%s' (from '%s')"):format(propertyName, originalName))
		end

		-- Get the list of subproperties we need
		local firstProperty = p
		local count = 0
		tclear(_arr)
		local list = _arr
		list[1] = firstProperty

		do
			local currProperty = firstProperty
			for name in originalName:gmatch("([_%w]+)") do
				count = count + 1
				if count ~= 1 then
					-- Skip the first property; we already got it
					local nextProperty = currProperty.subproperties[name]
					if not nextProperty then
						error(("Could not find subproperty '%s' under '%s' (%s)"):format(name, currProperty.propertyName, currProperty.TYPE))
					end
					currProperty = nextProperty
					list[count] = nextProperty

					-- TODO: Add support for deeper subproperties?
					-- Need to prepare tween/animations for that
					-- * Need the ability to skip certain subproperties for poking
					--   * ex. Skip 'object' in 'object._position.x'
					--     * ...which will poke '_position', since that is more relevant
					--     * ...but we need a way to get 'object._position.x' and 'object'
					--
					-- I didn't want to leave it without any work, so I did some below
					-- Anything nested 3 and more levels is untested
					-- Most important part is `Property:asProxy()`

					-- Break here since we didn't implement the above yet
					-- break
				end
			end
		end

		local lastPokeableProperty = list[count]
		for i = count, 1, -1 do
			local nextProperty = list[i]
			if not nextProperty.canPoke then
				break
			else
				lastPokeableProperty = nextProperty
			end
		end

		local proxy = firstProperty
		local pokeFunc = nil
		for i = 2, count do
			local currProperty = list[i]
			proxy = currProperty:asProxy(proxy)

			if currProperty == lastPokeableProperty then
				local relativeProxy = proxy
				pokeFunc = function(_, obj, _)
					relativeProxy:poke(obj, relativeProxy.propertyName)
				end
			end
		end
		proxy.poke = pokeFunc
		return proxy
	end

	return p
end

---Returns true if the property is different from the default value
---@param object Object
---@param propertyName string
function ClassDBEntry:isModified(object, propertyName)
	local value = rawget(object, propertyName)
	if value == nil then return false end
	return self:getProperty(propertyName, true):isDefault(value)
end

local function checkIsNotDefault(obj, property, propertyName, value)
	return not property:isDefault(value)
end

---Runs a function for each modified value in an object
---@param object Object
---@param recursive boolean?
---@param forEach fun(obj: Object, property: Property, propertyName: string, value: any, ...: unknown)
---@param ... unknown
function ClassDBEntry:forEachModifiedValue(object, recursive, forEach, ...)
	self:forEachPropertyCheck(object, recursive, checkIsNotDefault, forEach, ...)
end

---Runs a function for each potentially modified Property in an instanced Object.
---Will not run for each Property, only for the ones found to be inside the Object's table
---@param object Object
---@param recursive boolean?
---@param checkFunc fun(obj: Object, property: Property, propertyName: string, value: any, ...: unknown)
---@param forEach fun(obj: Object, property: Property, propertyName: string, value: any, ...: unknown)
---@param ... unknown
function ClassDBEntry:forEachPropertyCheck(object, recursive, checkFunc, forEach, ...)
	if recursive == nil then recursive = true end

	for k, v in pairs(object) do
		local property = self:getProperty(k, recursive)
		if property and checkFunc(object, property, k, v, ...) then
			-- Modified
			forEach(object, property, k, v, ...)
		end
	end
end

---Runs a function for each Property in this Object.
---@param object Object
---@param recursive boolean
---@param forEach fun(obj: Object, property: Property, propertyName: string, fromClass: Object, ...)
---@param ... unknown
function ClassDBEntry:forEachProperty(object, recursive, forEach, ...)
	if recursive == nil then recursive = true end

	---@type ClassDB.Info
	local currInfo = self._info
	-- Should use a new table, this method may be recursively called
	local alreadyUsedProperties = {}
	repeat
		local class = currInfo.class
		---@cast class Object
		for i = 1, #currInfo.propertyList do
			local property = currInfo.propertyList[i]
			local propertyName = property.propertyName

			if Set.mark(alreadyUsedProperties, propertyName) then
				-- (In case a later property overrides an earlier property)
				forEach(object, property, propertyName, class, ...)
			end
		end
		currInfo = currInfo.superInfo
	until not recursive or currInfo == nil

	tclear(alreadyUsedProperties)
end

---Runs a function for each binary data Property in this Object.
---Runs in a deterministic order (based off the order binary Properties were added).
---@param object Object
---@param recursive boolean
---@param forEach fun(obj: Object, property: Property, propertyName: string, fromClass: Object, ...)
---@param ... unknown
function ClassDBEntry:forEachBinaryProperty(object, recursive, forEach, ...)
	if recursive == nil then recursive = true end

	---@type ClassDB.Info
	local currInfo = self._info
	-- Should use a new table, this method may be recursively called
	local alreadyUsedProperties = {}
	repeat
		local class = currInfo.class
		---@cast class Object
		for i = 1, #currInfo.propertyList do
			local property = currInfo.propertyList[i]
			if not property.isConstant and property.IS_BINARY then
				local propertyName=  property.propertyName

				if Set.mark(alreadyUsedProperties, propertyName) then
					forEach(object, property, propertyName, class, ...)
				end
			end
		end
		currInfo = currInfo.superInfo
	until not recursive or currInfo == nil

	tclear(alreadyUsedProperties)
end

function ClassDBEntry._setClassDB(ClassDB) Properties.setClassDB(ClassDB) end

return ClassDBEntry
