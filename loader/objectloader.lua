---@type Adore.Loader
local Loader = require "loader"
---@type ObjectSaver
local ObjectSaver = require "common.objectsaver"
---@type Adore.AssetCollection
local AssetCollection = require "loader.assetcollection"
---@type ClassDB
local ClassDB = require "common.classdb"

---ObjectLoader returns an Object that is found at a certain file path.
---It's a wrapper around ObjectSaver for loading specifically.
---@class ObjectLoader: Adore.AssetCollection
local ObjectLoader = AssetCollection:extend()
ObjectLoader.TYPE = "ObjectLoader"

---Takes a filepath of a Lua file (like "assets/fognoise.lua") and creates an Object from it
---@param filepath string
local function loadFromLua(filepath, requestedClassName)
	local obj, err = ObjectSaver.loadFromFilePath(filepath, "lua", requestedClassName, true)
	if err then
		error(("Failed to load Object from '%s': \n'%s'"):format(filepath, err))
	end
	return obj
end

---Takes a filepath of a JSON file (like "assets/scene.json") and creates an Object from it
---@param filepath string
local function loadFromJSON(filepath, requestedClassName)
	local obj, err = ObjectSaver.loadFromFilePath(filepath, "json", requestedClassName, true)
	if err then
		error(("Failed to load Object from '%s': \n'%s'"):format(filepath, err))
	end
	return obj
end

---@type {[string]: fun(path: string): table}
local specialHandlers = {
	-- Load from Lua
	lua = loadFromLua,
	-- Load from JSON
	json = loadFromJSON,

	-- Adore Generic File; will always be interpreted as binary
	---@diagnostic disable-next-line: assign-type-mismatch
	agf = false,
}

function ObjectLoader:new(...)
	ObjectLoader.super.new(self, ...)

	---@type {[string]: {[string]: any}} # A map of scene asset paths to their default values
	self.pathToDefaultValues = {}
end

---(Loads if needed, and) returns the asset and asset ID at the path
---@generic T: Object
---@param path string
---@param requestedClassName `T`
---@return T asset
---@return AssetID id
---@overload fun(self: ObjectLoader, path: string): Object, AssetID
function ObjectLoader:get(path, requestedClassName)
	-- Check for existing path
	local id = self.pathToId[path]
	if not id then
		-- Doesn't exist; create it
		local asset = self:handler(path, requestedClassName)
		return asset, self:register(asset, path)
	else
		-- Returns the existing ID while checking if it inherits from the requested class
		local existingAsset = self.assets[id]
		if requestedClassName and not ClassDB.doesClassInherit(requestedClassName, existingAsset.CLASS_NAME) then
			error(("Asset at '%s' ('%s') does not inherit from '%s'"):format(path, existingAsset.CLASS_NAME, requestedClassName))
		end

		return existingAsset, id
	end
end

---Returns the modified properties for the scene
---@param path string
---@return {[string]: any}?
function ObjectLoader:getModifiedSceneProperties(path)
	return self.pathToDefaultValues[path]
end

---Removes the modified properties for the scene; usually called after saving a scene
---@param path string
function ObjectLoader:removeModifiedSceneProperties(path)
	self.pathToDefaultValues[path] = nil
end

do
---@param node Node
---@param property Property
---@param propertyName string
---@param fromClass string
---@param modified {[string]: any}
local function insertModifiedValues(node, property, propertyName, fromClass, modified)
	if not property.IS_BINARY and not property.isConstant then
		local value = property:get(node, propertyName)
		if not property:isDefault(value) then
			-- It's modified
			modified[propertyName] = value
		end
	end
end

---Returns the modified properties for the scene
---@param node Node
---@param path string
function ObjectLoader:updateModifiedSceneProperties(node, path)
	-- Get the old modified values, or use a new empty table
	local modified = self.pathToDefaultValues[path]
	if not modified then
		modified = {}
		self.pathToDefaultValues[path] = modified
	else
		-- Clear the modified table
		for k, _ in pairs(modified) do modified[k] = nil end
	end
	-- Insert the modified properties
	node:getClassDBEntry():forEachProperty(node, true, insertModifiedValues, modified)
end
end

---@generic T: Object
---@param path string
---@param requestedClassName `T`
---@return T
---@overload fun(self: ObjectLoader, path: string): Object
function ObjectLoader:handler(path, requestedClassName)
	if not requestedClassName then requestedClassName = "Object" end

	local extension = path:match("^.*%.(.*)")
	if specialHandlers[extension] then
		-- Use the special handler
		local success, obj = pcall(specialHandlers[extension], path, requestedClassName)
		assert(success, obj)
		return obj
	else
		-- It's probably binary
		return assert(ObjectSaver.loadFromFilePath(path, "binary", requestedClassName, true))
	end
end

Loader.addCollection(ObjectLoader)
return ObjectLoader
