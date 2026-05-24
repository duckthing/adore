---@class Adore.Loader
local Loader = {}
local function emptyFunc() end

---@type Adore.AssetCollection
local AssetCollection = require("loader.assetcollection")

---@type {[string]: Adore.AssetCollection}
local loadedCollections = {}

---@type {[string]: fun(path: string): (table | userdata | any)}
local handlers = {
	["love.ImageData"] = love.image.newImageData,
	-- `love.Image` will not return a `TextureSource` that is needed for most Nodes
	-- Use `ImageLoader` instead
	["love.Image"] = love.graphics.newImage,
	["love.Video"] = love.graphics.newVideo,
	["love.Shader"] = function(path)
		-- Reads from a file and puts it into a shader
		-- Will also log any warning with the shader
		local contents, errMessage = love.filesystem.read("string", path)
		if contents == nil then error(errMessage) end
		---@cast contents string
		local shader = love.graphics.newShader(contents)
		local warnings = shader:getWarnings()
		if warnings ~= "vertex shader:\npixel shader:\n" then
			-- Returned warnings are weird...
			print(("[Adore.Loader:Shader (%s)]:\n%s"):format(path, warnings))
		end
		return shader
	end,
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
local reloaders = {
	["love.Image"] = function(collection, path)
		local id = collection.pathToId[path]
		---@type love.Image
		local image = collection.assets[id]
		local imageData = love.image.newImageData(path)
		image:replacePixels(imageData)
		imageData:release()
	end,
}

---@type {[string]: function}
local destructors = {}

---Maps from a common name into the internal name.
---All keys should be in lower-case, while values can be upper-case
---@type {[string]: string}
local aliases = {
	shader = "love.Shader",

	music = "StreamSound",
	sfx = "StaticSound",
	["love.source"] = "StaticSound",
}

---@type {[string]: Adore.AssetCollection} A map of collection types to their (uninitialized) module
local collectionTypeToPath = {}

---@type {[string]: string} # Warning messages for using certain collections
local collectionWarnings = {
	["love.Image"] = [[
[Adore.Loader] Using 'love.Image', which does not return a 'TextureSource' needed for most Nodes.
[Adore.Loader] Only use 'love.Image' if you know what you are doing!
]]
}

---(Creates if needed, and) returns a table of resources of `type`, as well as the array where you can look up assets by ID.
---@generic T
---@param name `T` | string
---@return T | Adore.AssetCollection
---@return T[]
function Loader.getCollection(name)
	local collection = loadedCollections[name]
	if not collection then
		-- Check if the passed type is an alias
		local alias = aliases[name:lower()]
		if alias then
			name = alias
			collection = loadedCollections[alias]
		end
	end
	if not collection then
		-- This collection might not be loaded
		---@type Adore.AssetCollection
		local Collection

		local warning = collectionWarnings[name]
		if warning then
			-- Warn if we have a warning for this collection
			print(debug.traceback(warning, 2))
		end

		-- Check if the passed type references an unloaded collection, and load it
		if collectionTypeToPath[name] then
			-- Load it
			Collection = collectionTypeToPath[name]()
		else
			-- Not referencing an unloaded collection
			-- Create a new collection from the associated functions
			local handler = handlers[name]
			if not handler then
				error(("No alias/handler exists for '%s' for getting the asset collection; did you remember to add an alias/handler before loading an asset?"):format(name))
			end

			local reloader = reloaders[name] or nil
			local destructor = destructors[name] or emptyFunc

			Collection = AssetCollection(name, handler, reloader, destructor)
		end

		loadedCollections[name] = Collection
		collection = Collection
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

---Adds an alias for a given type. Aliases can be used to map certain names to a different type/handler.
---Will not overwrite existing aliases by default; pass in `true` as the last parameter to allow this.
---@param alias string
---@param realType string
---@param overwrite boolean? # Should we overwrite an existing alias?
function Loader.addAlias(alias, realType, overwrite)
	if not overwrite and aliases[alias] then
		error(("Alias for '%s' already exists as '%s'"):format(alias, aliases[alias]))
	end
	aliases[alias] = realType
end

---Adds a collection from a require path
---@param module Adore.AssetCollection
---@param overwrite boolean? # Should we overwrite existing collections and their aliases?
function Loader.addCollection(module, overwrite)
	local type = module.TYPE
	if not overwrite and collectionTypeToPath[type] then
		error(("Collection '%s' already exists"):format(type))
	end

	collectionTypeToPath[type] = module
	local cAliases = module.ALIASES
	for i = 1, #cAliases do
		Loader.addAlias(cAliases[i], type, overwrite)
	end
end

return Loader
