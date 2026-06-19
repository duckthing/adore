---@type Adore.Loader
local Loader = require "loader"
---@type ObjectSaver
local ObjectSaver = require "common.objectsaver"
---@type Adore.AssetCollection
local AssetCollection = require "loader.assetcollection"

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
