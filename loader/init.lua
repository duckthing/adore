---"Exposed collections" are ones that are useful to developers.
---Some collections, like TextureLoader, will automatically use hidden collections with certain assets.
---@alias Adore.ExposedCollections
---| "TextureLoader"
---| "FontLoader"
---| "ObjectLoader"
---| "ShaderLoader"
---| "StreamSound"
---| "StaticSound"

---These collections are used automatically.
---You may read from these collections if you'd like to debug your assets.
---@alias Adore.HiddenCollections
---| "AtlasLoader"
---| "SheetLoader"
---| "ProcLoader"

---@class Adore.Loader
local Loader = {}
local function emptyFunc() end

---@type Adore.AssetCollection
local AssetCollection = require("loader.assetcollection")
---@type {[Adore.Common | "_paths"]: any}
local Common = require "common"

---@type {[string]: Adore.AssetCollection}
local loadedCollections = {}

---@type {[string]: fun(path: string): (table | userdata | any)}
local handlers = {
	["StreamSound"] = function(path)
		-- Music, decoded when necessary
		return love.audio.newSource(path, "stream")
	end,
	["StaticSound"] = function(path)
		-- Sound FX, decoded entirely in memory
		return love.audio.newSource(path, "static")
	end,
}

---@type {[string]: fun(collection: Adore.AssetCollection, path: string, ...: unknown)}
local reloaders = {}

---@type {[string]: function}
local destructors = {}

---@type {[string]: Adore.AssetCollection} A map of collection types to their (uninitialized) module.
---Usually modified by `Loader.addCollection`.
local collectionTypeToModule = {}

---(Creates if needed, and) returns a table of resources of `type`, as well as the array where you can look up assets by ID.
---@generic T: Adore.AssetCollection
---@param name `T` | Adore.ExposedCollections
---@return T
---@return any[] # The array of assets
function Loader.getCollection(name)
	local collection = loadedCollections[name]

	if not collection then
		-- This collection might not be loaded
		-- Check if the passed type references an uninitialized collection, and initialize it
		if collectionTypeToModule[name] then
			-- Instance it
			collection = collectionTypeToModule[name]()
		elseif Common._paths[name] then
			-- Referencing an unloaded module, require and instance it
			local module = Common[name]
			collection = module()
		else
			-- Not referencing an unloaded collection
			-- Create a new collection from the associated functions
			local handler = handlers[name]
			if not handler then
				error(("No handler exists for '%s' for getting the asset collection; did you remember to add a handler before loading an asset?"):format(name))
			end

			local reloader = reloaders[name] or nil
			local destructor = destructors[name] or emptyFunc

			collection = AssetCollection(name, handler, reloader, destructor)
		end

		loadedCollections[name] = collection
		collection = collection
	end

	return collection, collection.assets
end

---Adds a handler for a given type. Handlers create new assets from a given file path.
---Will not overwrite existing handlers by default; pass in `true` as the last parameter to allow this.
---@param type string
---@param func fun(path: string, ...: unknown): (table | userdata)
---@param overwrite boolean? # Should we overwrite an existing handler?
function Loader.addHandler(type, func, overwrite)
	if not overwrite and handlers[type] then
		error(("Handler for '%s' already exists"):format(type))
	end
	handlers[type] = func
end

---Adds a reloader for a given type. Reloaders handle reloading assets.
---Will not overwrite existing handlers by default; pass in `true` as the last parameter to allow this.
---@param type string
---@param func fun(path: string, ...: unknown): (table | userdata)
---@param overwrite boolean? # Should we overwrite an existing handler?
function Loader.addReloader(type, func, overwrite)
	if not overwrite and reloaders[type] then
		error(("Reloader for '%s' already exists"):format(type))
	end
	reloaders[type] = func
end

---Adds a destructor for a given type. Destructors destroy an asset when necessary.
---Will not overwrite existing destructors by default; pass in `true` as the last parameter to allow this.
---@param type string
---@param func fun(toDestroy: table | userdata, newAsset: (table | userdata)?, ...: unknown)
---@param overwrite boolean? # Should we overwrite an existing destructor?
function Loader.addDestructor(type, func, overwrite)
	if not overwrite and destructors[type] then
		error(("Destructor for '%s' already exists"):format(type))
	end
	destructors[type] = func
end

---Adds a collection from a require path
---@param module Adore.AssetCollection
---@param overwrite boolean? # Should we overwrite existing collections and their aliases?
function Loader.addCollection(module, overwrite)
	local type = module.TYPE
	if not overwrite and collectionTypeToModule[type] then
		error(("Collection '%s' already exists"):format(type))
	end
	collectionTypeToModule[type] = module
end

return Loader
