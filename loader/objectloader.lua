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
ObjectLoader.ALIASES = {"objectloader", "object"}

---Takes a filepath of a Lua file (like "/assets/fognoise.lua") and creates an Object from it
---@param filepath string
local function requireFromFilePath(filepath, requestedClassName)
	local err, obj = ObjectSaver.loadFromFilePath(filepath, "lua", requestedClassName, true)
	if err then
		error(("Failed to load Object from '%s': \n'%s'"):format(filepath, err))
	end
	return obj
end

---@type {[string]: fun(path: string): table}
local specialHandlers = {
	-- The following is usually require'd with the basic require
	lua = requireFromFilePath,
	luau = requireFromFilePath,
	moon = requireFromFilePath,

	-- Adore Generic File; will always be interpreted as binary
	---@diagnostic disable-next-line: assign-type-mismatch
	agf = false,
}

---(Loads if needed, and) returns the asset and asset ID at the path
---@param path string
---@param requestedClassName string?
---@param ... unknown
---@return any asset
---@return AssetID id
function AssetCollection:get(path, requestedClassName, ...)
	-- Check for existing path
	local id = self.pathToId[path]
	if not id then
		-- Doesn't exist; create it
		local asset = self:handler(path, requestedClassName, ...)
		return asset, self:register(asset, path)
	else
		-- Returns the existing ID while checking if it inherits from the requested class
		local existingAsset = self.assets[id]
		if requestedClassName and ClassDB.doesClassInherit(existingAsset.CLASS_NAME, requestedClassName) then
			error(("Asset at '%s' ('%s') does not inherit from '%s'"):format(path, existingAsset.CLASS_NAME, requestedClassName))
		end

		return existingAsset, id
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
		local err, obj = ObjectSaver.loadFromFilePath(path, "binary", requestedClassName, true)
		assert(obj, err)
		return obj
	end
end

function ObjectLoader:reloader(path, requestedClassName)
end

Loader.addCollection(ObjectLoader)
return ObjectLoader
