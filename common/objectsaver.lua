---@type AdoreInit
local Adore = require ""

local StringBuffer
local ffi = Adore.Common("ffilib")

local ClassDB = Adore.Common("ClassDB")
local Serpent = Adore.Libraries("Serpent")
local JSON = Adore.Libraries("JSON")
local Properties = require "data.properties"

---@class ObjectSaver
local ObjectSaver = {}

---@alias ObjectSaver.Format
---| "binary" # A binary format
---| "lua" # A plain-text format in valid Lua syntax
---| "json" # A common plain-text format

-- http://stackoverflow.com/questions/9137415
---@param str string
---@return string
local function fromhex(str)
	return (str:gsub('..', function (cc)
		return string.char(tonumber(cc, 16))
	end))
end

---@param str string
---@return string
local function tohex(str)
	return (str:gsub('.', function (c)
		return string.format('%02X', string.byte(c))
	end))
end

---Guesses a file format from a path
---@param path string
---@return ObjectSaver.Format? format
local function guessFormatFromPath(path)
	local extension = path:match("^.+(%..+)$")
	if extension == "json" or extension == "lua" then
		return extension
	end
end

local STRING_MAGIC_NUMBER = fromhex("AD0430B7") -- "AdoreObj"
local EMPTY_ARR = {}
local SERPENT_OPTIONS = {nocode = true, comment = false}

do
	local success, mod = pcall(require, "_G.string.buffer")
	if success then StringBuffer = mod end
end

---@type string.buffer
local tbuffer
local DEFAULT_FORMAT = "json"
if StringBuffer then
	---@diagnostic disable-next-line: undefined-field
	tbuffer = StringBuffer.new()
	DEFAULT_FORMAT = "binary"
end

---Passed into a pcall; decodes a buffer
---@param buf string.buffer
---@return boolean ok
---@return string | table | number | nil objOrErr
local function safeDecode(buf)
	return pcall(buf.decode, buf)
end

do
	---Inserts properties, including binary properties if necessary
	---@param obj Object
	---@param property Property
	---@param propertyName string
	---@param fromClass Object
	---@param header table
	---@param body table
	local function femvInsertWithBinaryCallback(obj, property, propertyName, fromClass, header, body, resources)
		local value = property:get(obj, propertyName)
		if property.isHeader then
			-- Any header property goes into the header, even if it's not modified
			local serialized = property:serialize(obj, propertyName, value, resources)
			header[propertyName] = serialized
		elseif not property:isDefault(value) then
			-- All modified values go into the body
			local serialized = property:serialize(obj, propertyName, value, resources)
			body[propertyName] = serialized
		end
	end

	---Inserts properties, excluding binary properties for compatability without string.buffer.
	---@param obj Object
	---@param property Property
	---@param propertyName string
	---@param fromClass Object
	---@param header table
	---@param body table
	local function femvInsertWithoutBinaryCallback(obj, property, propertyName, fromClass, header, body, resources)
		local value = property:get(obj, propertyName)
		if not property.IS_BINARY then
			-- Exclude binary properties
			if property.isHeader then
				-- Any header property goes into the header, even if it's not modified
				local serialized = property:serialize(obj, propertyName, value, resources)
				header[propertyName] = serialized
			elseif not property:isDefault(value) then
				-- All modified values go into the body
				local serialized = property:serialize(obj, propertyName, value, resources)
				body[propertyName] = serialized
			end
		end
	end

	---Gets the table of modified values that can be used to load this Object's properties again later.
	---Includes changed binary properties.
	---@param object Object
	---@param resources any[]
	---@param includeBinary boolean? # Whether we should include binary properties
	---@return table header
	---@return table body
	---@return any[] resources
	function ObjectSaver.getPropertyPairs(object, resources, includeBinary)
		-- The data that will get encoded
		local header = {}
		local body = {}
		local cb = (includeBinary and femvInsertWithBinaryCallback) or femvInsertWithoutBinaryCallback
		-- We don't use `:forEachModifiedProperty()` because we want to insert all values into the header,
		-- even if they are unmodified.
		object:getClassDBEntry():forEachProperty(object, true, cb, header, body, resources)
		return header, body, resources
	end
end

---Serializes an Object at the end of a string.buffer, which can be deserialized later to load the Object again.
---Returns the passed resource array, or the new one if it wasn't passed.
---@param object Object
---@param buffer string.buffer
---@param resources any[]? # Should be initialized outside
---@return any[] resources
function ObjectSaver.serializeObjectToBuffer(object, buffer, resources)
	-- TODO: Better error handling
	if not resources then resources = {} end

	local entry = object:getClassDBEntry()
	if not entry:canSerialize() then
		return resources
	end

	local header, body = ObjectSaver.getPropertyPairs(object, resources, true)

	do
		-- Insert the length of the header, and then the header
		local encodedHeader = StringBuffer.encode(header)
		buffer:put(fromhex(string.format("%08X", #encodedHeader)))
		buffer:put(encodedHeader)
	end

	do
		-- Insert the length of the body, and then the body
		local encodedBody = StringBuffer.encode(body)
		buffer:put(fromhex(string.format("%08X", #encodedBody)))
		buffer:put(encodedBody)
	end

	-- Put any binary data into the buffer
	entry:forEachBinaryProperty(object, true, function(obj, property, propertyName, fromClass, ...)
		-- TODO: Should binary data equal to the default value be serialized?
		if not property.DEFER_MODE then
			-- Deferred binary data will get packed in the resource section (at the end)
			-- These properties are NOT deferred, though, so we can pack it
			property:packBuffer(obj, propertyName, buffer, resources)
		end
	end)
	object:_afterSerialized(buffer, header, body)

	return resources
end

---Serializes the resource list and puts it at the end of a string.buffer.
---It should get called **after** serializing all other Objects.
---@param buffer string.buffer
---@param resources any[]?
function ObjectSaver.serializeResourcesToBuffer(buffer, resources)
	-- Encode the resource list
	buffer:encode(resources or EMPTY_ARR)

	-- Add the binary data to the end of the buffer
	if resources then
		for i = 1, #resources do
			local reference = resources[i]
			---@type Property
			local property = Properties[reference.TYPE]
			if property and property.IS_BINARY then
				property.packBufferResource(buffer, reference, resources)
			end
		end
	end
end

---Creates an Object from the serialized table. There is an optional `requestedClassName` parameter that only returns an
---Object that either matches the class name exactly or inherits from it.
---@generic T: Object
---@param binaryBuffer string.buffer
---@param header table # The serialized header of the Object
---@param body table # The serialized body of the Object
---@param requestedClassName `T` # The optional class (name) to expect; should be a string
---@param canInherit boolean? # [Default: `false` if requesting a class] Whether the deserialized object can inherit from the requested class
---@return string? err
---@return T? object
---@return {[string]: any}? deferredProperties # A map of property names to their values; keep this for later
---@overload fun(binaryBuffer: string.buffer, header: table, body: table): string?, Object?
function ObjectSaver.deserializeObjectFromBuffer(binaryBuffer, header, body, requestedClassName, canInherit)
	local RequestedClass
	if not requestedClassName then
		-- No class name, allow converting into any Object
		requestedClassName = "Object"
		RequestedClass = Adore.Resources("Object")
		canInherit = true
	else
		-- Check if the class name matches/inherits the parameters
		RequestedClass = Adore.Any(requestedClassName) or ClassDB.ClassNameToClass[requestedClassName]

		if not RequestedClass then
			-- The passed parameters request a class that doesn't exist
			return ("Requested class parameter '%s' does not exist"):format(requestedClassName), nil
		end
	end

	if not header.CLASS_NAME then
		-- There's no CLASS_NAME field in the header
		return "Missing class name in header", nil
	end

	---@type Object
	local TargetClass = Adore.Any(header.CLASS_NAME) or ClassDB.ClassNameToClass[header.CLASS_NAME]
	if not TargetClass then
		-- The table has a class that doesn't exist
		return ("Serialized object's class '%s' does not exist"):format(header.CLASS_NAME), nil
	end

	if canInherit then
		-- Check if the requested class is inheriting from the target class
		if not (TargetClass == RequestedClass or TargetClass:is(RequestedClass)) then
			return ("Serialized object '%s' does not inherit from '%s'"):format(TargetClass, RequestedClass), nil
		end
	else
		-- Check if the requested class matches the target class
		if header.CLASS_NAME ~= requestedClassName then
			return ("Serialized object '%s' does not match class name '%s'"):format(header.CLASS_NAME, requestedClassName), nil
		end
	end

	-- Check if the entry allows deserialization
	local entry = TargetClass:getClassDBEntry()
	if not entry:canDeserialize() then
		return ("Serialized object class '%s' is requesting a class that disallows deserialization"):format(header.CLASS_NAME), nil
	end

	---@type Object # The object where all the properties will get set
	local obj = TargetClass()

	-- Deserialize everything and put it into the object, if the property isn't a constant and not binary
	local deferredData = nil

	-- Set the properties
	for i = 1, 2 do
		local t = (i == 1 and header) or body
		for propertyName, value in pairs(t) do
			local property = entry:getProperty(propertyName)
			if property and not property.IS_BINARY and not property.isConstant then
				-- Property, not a binary blob, not constant
				if not property.DEFER_MODE then
					-- Not deferred, deserialize immediately
					-- (It won't rely on resources)
					property:deserialize(obj, propertyName, value)
				else
					-- Deserialize later outside of this function
					if not deferredData then deferredData = {} end
					deferredData[propertyName] = value
				end
			end
		end
	end

	-- Deserialize any remaining binary data
	entry:forEachBinaryProperty(obj, true, function(obj, property, propertyName, fromClass, ...)
		local t = (property.isHeader and header) or body
		if not property.DEFER_MODE then
			-- Not deferred, deserialize the binary data immediately
			property:unpackBuffer(obj, propertyName, t[propertyName], binaryBuffer)
		else
			-- Deferred binary data resides in the resource blob at the end
			-- The value that is stored is the reference created by the property
			if not deferredData then deferredData = {} end
			deferredData[propertyName] = t[propertyName]
		end
	end)

	obj:_afterDeserialized(binaryBuffer, header, body)
	return nil, obj, deferredData
end

---Deserializes the resource list from the end of a `string.buffer`
---* It should get called **after** deserializing a block of serialized Object(s).
---* It returns `nil` as the second return value and the error as the third value if there was an issue decoding.
---@param buffer string.buffer
---@return string? err
---@return any[]? resources
function ObjectSaver.deserializeResourcesFromBuffer(buffer)
	-- Decode the resource list
	local ok, resources = safeDecode(buffer)

	if not ok then
		-- Return the error (resources will be an error string)
		---@cast resources string
		return resources, nil
	end

	-- Read the binary data from the end of the buffer
	if resources then
		local resType = type(resources)
		if resType == "table" then
			for i = 1, #resources do
				local reference = resources[i]
				---@type Property
				local property = Properties[reference.TYPE]
				if property and property.IS_BINARY then
					property.unpackBufferResource(buffer, reference, resources)
				end
			end

			-- Return the buffer and resource list
			return nil, resources
		else
			-- Return the error
			return ("Decoded resource list was of incorrect type '%s'"):format(resType)
		end
	end

	-- Resource list doesn't exist; return nothing for it
	return "Resource list does not exist", nil
end

---Creates an Object from a string.buffer. There is an optional `requestedClassName` parameter that only returns an
---Object that either matches the class name exactly or inherits from it.
---
---NOTE: Do not include the magic number at the start of the buffer. That is only used for files.
---@generic T: Object
---@param buffer string.buffer
---@param requestedClassName `T` # The optional class (name) to expect; should be a string
---@param canInherit boolean? # [Default: `false` if requesting a class] Whether the deserialized object can inherit from the requested class
---@return string? err
---@return T? object
---@return {[string]: any}? deferredProperties # A map of property names to their values; keep this for later
---@overload fun(buffer: string.buffer): string?, Object?
function ObjectSaver.deserializeFromBuffer(buffer, requestedClassName, canInherit)
	---@type table # The header of the Object
	local headerTable
	do
		-- Skip the length of the header, as we can read the header into a variable without knowing the length
		buffer:skip(4)
		local success, headerOrErr = safeDecode(buffer)
		if not success then
			-- Errored while decoding
			---@cast headerOrErr string
			return headerOrErr, nil, nil
		end

		if type(headerOrErr) ~= "table" then
			-- Wrong type
			return ("Expected header of type 'table', got '%s'"):format(type(headerOrErr)), nil
		end

		-- All good
		headerTable = headerOrErr
	end

	---@type table # The body of the Object
	local bodyTable
	do
		-- Skip the length of the body just like the header
		buffer:skip(4)
		local success, bodyOrErr = safeDecode(buffer)
		if not success then
			-- Errored while decoding
			---@cast bodyOrErr string
			return bodyOrErr, nil, nil
		end

		if type(bodyOrErr) ~= "table" then
			-- Wrong type
			return ("Expected body of type 'table', got '%s'"):format(type(bodyOrErr)), nil
		end

		-- All good
		bodyTable = bodyOrErr
	end

	return ObjectSaver.deserializeObjectFromBuffer(buffer, headerTable, bodyTable, requestedClassName, canInherit)
end

---Serializes an Object at the end of an array, which can be deserialized later to load the Object again.
---Returns the passed resource array, or the new one if it wasn't passed.
---@param object Object
---@param array table[]
---@param resources any[]? # Should be initialized outside
---@return any[] resources
function ObjectSaver.serializeObjectToArray(object, array, resources)
	-- TODO: Better error handling
	if not resources then resources = {} end

	local entry = object:getClassDBEntry()
	if not entry:canSerialize() then
		return resources
	end

	local header, body = ObjectSaver.getPropertyPairs(object, resources, true)

	-- Insert the header and body
	array[#array+1] = header
	array[#array+1] = body

	object:_afterSerialized(array, header, body)

	return resources
end

---Serializes the resource list and puts it at the end of a array.
---It should get called **after** serializing all other Objects.
---@param array table[]
---@param resources any[]?
function ObjectSaver.serializeResourcesToArray(array, resources)
	-- Encode the resource list
	array[#array+1] = resources or {}
end

---Creates an Object from the serialized table. There is an optional `requestedClassName` parameter that only returns an
---Object that either matches the class name exactly or inherits from it.
---@generic T: Object
---@param header table # The serialized header of the Object
---@param body table # The serialized body of the Object
---@param requestedClassName `T` # The optional class (name) to expect; should be a string
---@param canInherit boolean? # [Default: `false` if requesting a class] Whether the deserialized object can inherit from the requested class
---@return string? err
---@return T? object
---@return {[string]: any}? deferredProperties # A map of property names to their values; keep this for later
---@overload fun(header: table, body: table): string?, Object?
function ObjectSaver.deserializeObjectFromArray(header, body, requestedClassName, canInherit)
	local RequestedClass
	if not requestedClassName then
		-- No class name, allow converting into any Object
		requestedClassName = "Object"
		RequestedClass = Adore.Resources("Object")
		canInherit = true
	else
		-- Check if the class name matches/inherits the parameters
		RequestedClass = Adore.Any(requestedClassName) or ClassDB.ClassNameToClass[requestedClassName]

		if not RequestedClass then
			-- The passed parameters request a class that doesn't exist
			return ("Requested class parameter '%s' does not exist"):format(requestedClassName), nil
		end
	end

	if not header.CLASS_NAME then
		-- There's no CLASS_NAME field in the header
		return "Missing class name in header", nil
	end

	---@type Object
	local TargetClass = ClassDB.ClassNameToClass[header.CLASS_NAME] or Adore.Any(header.CLASS_NAME)
	if not TargetClass then
		-- The table has a class that doesn't exist
		return ("Serialized object's class '%s' does not exist"):format(header.CLASS_NAME), nil
	end

	if canInherit then
		-- Check if the requested class is inheriting from the target class
		if not TargetClass:is(RequestedClass) then
			return ("Serialized object '%s' does not inherit from '%s'"):format(TargetClass, RequestedClass), nil
		end
	else
		-- Check if the requested class matches the target class
		if header.CLASS_NAME ~= requestedClassName then
			return ("Serialized object '%s' does not match class name '%s'"):format(header.CLASS_NAME, requestedClassName), nil
		end
	end

	-- Check if the entry allows deserialization
	local entry = TargetClass:getClassDBEntry()
	if not entry:canDeserialize() then
		return ("Serialized object class '%s' is requesting a class that disallows deserialization"):format(header.CLASS_NAME), nil
	end

	---@type Object # The object where all the properties will get set
	local obj = TargetClass()

	-- Deserialize everything and put it into the object, if the property isn't a constant and not binary
	local deferredData = nil

	-- Set the properties
	for i = 1, 2 do
		local t = (i == 1 and header) or body
		for propertyName, value in pairs(t) do
			local property = entry:getProperty(propertyName)
			if property and not property.isConstant then
				-- Property, not a binary blob, not constant
				if not property.DEFER_MODE then
					-- Not deferred, deserialize immediately
					-- (It won't rely on resources)
					property:deserialize(obj, propertyName, value)
				else
					-- Deserialize later outside of this function
					if not deferredData then deferredData = {} end
					deferredData[propertyName] = value
				end
			end
		end
	end

	return nil, obj, deferredData
end

---Sets the deferred properties that were deserialized.
---Call this when the conditions required for every deferred property has been fulfilled (ex. all children have been
---instanced for NodePaths) and when resources have been deserialized.
---@param obj Object
---@param deferredProperties {[string]: any}?
---@param parsedResources any[]?
function ObjectSaver.setDeferredProperties(obj, deferredProperties, parsedResources)
	if deferredProperties then
		local objEntry = obj:getClassDBEntry()
		for propertyName, value in pairs(deferredProperties) do
			local property = objEntry:getProperty(propertyName, true)

			if property then
				property:deserialize(obj, propertyName, value, parsedResources)
			end
		end
	end
end

---@type {[ObjectSaver.Format]: fun(file: love.File, object: Object): string?}
local saveFormatHandler = {
	binary = function(file, object)
		-- Put in the magic number
		file:write(STRING_MAGIC_NUMBER)

		-- Reset the temporary buffer and put the serialized Object into it
		tbuffer:reset()
		local resources = ObjectSaver.serializeObjectToBuffer(object, tbuffer)
		ObjectSaver.serializeResourcesToBuffer(tbuffer, resources)

		-- Write the contents of the buffer into the file (by creating a new string)
		while #tbuffer > 0 do
			local contents = tbuffer:get()
			local success, err = file:write(contents)
			if not success then
				tbuffer:reset()
				file:close()
				return err
			end
		end

		-- Reset the temporary buffer again
		tbuffer:reset()
	end,

	lua = function(file, object)
		local array = {}
		local resources = ObjectSaver.serializeObjectToArray(object, array)
		array[#array+1] = resources
		local _, err = file:write(Serpent.dump(array, SERPENT_OPTIONS))
		return err
	end,

	json = function(file, object)
		local array = {}
		local resources = ObjectSaver.serializeObjectToArray(object, array)
		array[#array+1] = resources
		local val, err = JSON.encode(array)
		if val then
			_, err = file:write(val)
		end
		return err
	end
}

---Saves this `Object` into a `love.File`. Pick a format with the `format` parameter, which is binary by default.
---* For `nativefs` files, see `ObjectSaver.saveToNativeFilePath`
---@param file love.File
---@param object Object
---@param format ObjectSaver.Format?
---@return boolean success
---@return string? error
function ObjectSaver.saveToFile(file, object, format)
	-- Get the best format if not provided
	if not format then
		format = DEFAULT_FORMAT
	elseif not StringBuffer and format == "binary" then
		return false, "Binary format is not supported on this platform"
	end

	if not file:isOpen() then
		-- Open the file if it isn't already
		local ok, err = file:open("w")
		if not ok then
			return false, err
		end
	else
		-- Check if the file is able to be written to
		local mode = file:getMode()
		if mode ~= "w" and mode ~= "a" then
			return false, ("File is opened in non-write mode: '%s'"):format(mode)
		end
	end

	local err = saveFormatHandler[format](file, object)

	-- Close the file
	file:close()
	return err == nil, err
end

---Saves this `Object` to a relative file path. It creates a `love.File` and passes it into `ObjectSaver.saveToFile`.
---
---This function uses more memory than `ObjectSaver.saveToNativeFilePath` when FFI is available.
---@param path string
---@param object Object
---@param format ObjectSaver.Format?
---@return boolean success
---@return string? error
function ObjectSaver.saveToFilePath(path, object, format)
	local file, err = love.filesystem.newFile(path, "w")
	if not file then
		return false, err
	end
	if not format then format = guessFormatFromPath(path) end

	local ok, err = ObjectSaver.saveToFile(file, object, format)
	file:release()
	return ok, err
end

---Saves this `Object` to a *GLOBAL* file path.
---
---This function uses less memory than `ObjectSaver.saveToFilePath` with the binary format, but may perform oddly on
-- certain platforms.
---On restricted platforms, it's more predictable to use the other functions, as they use the normal `love.filesystem`.
---@param path string
---@param object Object
---@param format ObjectSaver.Format?
---@return boolean success
---@return string? error
function ObjectSaver.saveToNativeFilePath(path, object, format)
	-- Get the best format if not provided
	if not format then
		format = DEFAULT_FORMAT
	elseif not StringBuffer and format == "binary" then
		return false, "Binary format is not supported on this platform"
	end

	if not ffi then
		return false, "[ObjectSaver.savetoNativeFile] Lacking FFI; native files are not supported"
	end

	-- Create the native file, and return if there's an issue
	---@type love.File
	local file = Adore.Libraries("NativeFS").newFile(path)
	do
		local ok, err = file:open("w")
		if not ok then
			return false, err
		end
	end

	if format == "binary" then
		-- Put in the magic number
		local success, err = file:write(STRING_MAGIC_NUMBER)
		if not success then
			file:close()
			return false, err
		end

		-- Reset the temporary buffer and put the serialized Object into it
		tbuffer:reset()
		local resources = ObjectSaver.serializeObjectToBuffer(object, tbuffer)
		ObjectSaver.serializeResourcesToBuffer(tbuffer, resources)

		-- Write the contents of the buffer into the file
		while #tbuffer > 0 do
			local ref, len = tbuffer:ref()
			tbuffer:skip(len)
			success, err = file:writecdata(ref, len)
			if not success then
				file:close()
				return false, err
			end
		end

		-- Reset the temporary buffer again and close the file
		tbuffer:reset()
	else
		saveFormatHandler[format](file, object)
	end

	file:close()
	file:release()
	return true
end

---@type {[ObjectSaver.Format]: fun(file: love.File, requestedClassName: string?, canInherit: boolean?): Object?, string?}
local loadFormatHandler = {
	binary = function(file, requestedClassName, canInherit)
		-- Check the magic number
		do
			local contents, _ = file:read(#STRING_MAGIC_NUMBER)
			if contents ~= STRING_MAGIC_NUMBER then
				-- Magic number doesn't match, exit
				file:close()
				return nil, ("Invalid Adore Object (magic number does not match) (%s ~= %s)"):format(contents, STRING_MAGIC_NUMBER)
			end
		end

		---@type table # The header of the Object
		local headerTable
		do
			-- Get the length of the header, and read it into the variable
			local lengthHex = file:read(4)
			local length = tonumber(tohex(lengthHex), 16)
			local headerBytes, readLength = file:read("data", length)
			---@cast headerBytes love.FileData

			tbuffer:putcdata(ffi.cast("uint8_t*", headerBytes:getFFIPointer()), readLength)
			local success, headerOrErr = safeDecode(tbuffer)
			if not success then
				-- Errored while decoding
				file:close()
				return nil, headerOrErr
			end

			if type(headerOrErr) ~= "table" then
				-- Wrong type
				file:close()
				return nil, ("Expected header of type 'table', got '%s'"):format(type(headerOrErr))
			end

			-- All good
			headerTable = headerOrErr
		end

		---@type table # The body of the Object
		local bodyTable
		do
			-- Get the length of the body, and read it into the variable
			local lengthHex = file:read(4)
			local length = tonumber(tohex(lengthHex), 16)
			local bodyBytes, readLength = file:read("data", length)
			---@cast bodyBytes love.FileData

			tbuffer:putcdata(ffi.cast("uint8_t*", bodyBytes:getFFIPointer()), readLength)
			local success, bodyOrErr = safeDecode(tbuffer)
			if not success then
				-- Errored while decoding
				---@cast bodyOrErr string
				file:close()
				return nil, bodyOrErr
			end

			if type(bodyOrErr) ~= "table" then
				-- Wrong type
				file:close()
				return nil, ("Expected body of type 'table', got '%s'"):format(type(bodyOrErr))
			end

			-- All good
			bodyTable = bodyOrErr
		end

		-- Put the rest of the file into a buffer
		local container, containerSize = file:read("data")
		---@cast container love.FileData
		local containerPointer = ffi.cast("uint8_t*", container:getFFIPointer())
		tbuffer:putcdata(containerPointer, containerSize)

		local err, obj, deferredProperties = ObjectSaver.deserializeObjectFromBuffer(tbuffer, headerTable, bodyTable, requestedClassName, canInherit)
		if err then
			-- Errored while deserializing Object
			tbuffer:reset()
			return nil, err
		end
		---@cast obj Object

		-- No error, now deserialize its resources
		local resources
		err, resources = ObjectSaver.deserializeResourcesFromBuffer(tbuffer)
		tbuffer:reset()

		if err then
			return nil, ("[ObjectSaver.fromFile] Errored while deserializing resources: %s"):format(err)
		end

		ObjectSaver.setDeferredProperties(obj, deferredProperties, resources)
		return obj, err
	end,

	lua = function(file, requestedClassName, canInherit)
		local contents = file:read("string")
		file:close()

		---@cast contents string
		local success, array = Serpent.load(contents, SERPENT_OPTIONS)
		if not success then
			return nil, ("Failed to deserialize Lua: %s"):format(array)
		end

		local err, obj, deferredProperties = ObjectSaver.deserializeObjectFromArray(
			array[1], array[2], -- The header and body
			requestedClassName, canInherit
		)

		if err then
			return nil, err
		end

		---@cast obj Object
		local resources = array[3]
		ObjectSaver.setDeferredProperties(obj, deferredProperties, resources)
		return obj, err
	end,

	json = function(file, requestedClassName, canInherit)
		local contents = file:read("string")
		file:close()

		---@cast contents string
		local array, err = JSON.decode(contents)
		if not array then
			return nil, ("Failed to deserialize JSON: %s"):format(err)
		end

		local obj, deferredProperties
		err, obj, deferredProperties = ObjectSaver.deserializeObjectFromArray(
			array[1], array[2], -- The header and body
			requestedClassName, canInherit
		)

		if err then
			return nil, err
		end

		---@cast obj Object
		local resources = array[3]
		ObjectSaver.setDeferredProperties(obj, deferredProperties, resources)
		return obj, err
	end,
}

---Opens, deserializes a serialized `Object` from the `File` object, and returns it
---@generic T: Object
---@param file love.File
---@param format ObjectSaver.Format?
---@param requestedClassName `T` # The optional class (name) to expect; should be a string
---@param canInherit boolean? # [Default: `false` if requesting a class] Whether the deserialized object can inherit from the requested class
---@return T? object
---@return string? err
---@overload fun(file: love.File, format: ObjectSaver.Format?): Object?, string?
function ObjectSaver.loadFromFile(file, format, requestedClassName, canInherit)
	-- Get the best format if not provided
	if not format then
		format = DEFAULT_FORMAT
	elseif not StringBuffer and format == "binary" then
		return nil, "Binary format is not supported on this platform"
	end

	if not file:isOpen() then
		-- Open the file if it isn't already
		local ok, err = file:open("r")
		if not ok then
			return nil, err
		end
	else
		-- Check if the file is able to be read from
		local mode = file:getMode()
		if mode ~= "r" then
			return nil, ("File is opened in non-read mode: '%s'"):format(mode)
		end
	end

	local handler = loadFormatHandler[format]
	if not handler then
		return nil, ("Format '%s' is not supported"):format(format)
	end

	return handler(file, requestedClassName, canInherit)
end

---Opens and returns the binary serialized `Object` from the file path. Will create a File object.
---@generic T: Object
---@param path string
---@param format ObjectSaver.Format?
---@param requestedClassName `T` # The optional class (name) to expect; should be a string
---@param canInherit boolean? # [Default: `false` if requesting a class] Whether the deserialized object can inherit from the requested class
---@return T? object
---@return string? err
---@overload fun(path: string, format: ObjectSaver.Format?): Object?, string?
function ObjectSaver.loadFromFilePath(path, format, requestedClassName, canInherit)
	local file, err = love.filesystem.newFile(path, "r")
	if not file then
		return nil, err
	end
	if not format then format = guessFormatFromPath(path) end

	local obj
	---@diagnostic disable-next-line: cast-local-type
	obj, err = ObjectSaver.loadFromFile(file, format, requestedClassName, canInherit)
	file:release()
	return obj, err
end

require("data.property").ObjectSaver = ObjectSaver

return ObjectSaver
