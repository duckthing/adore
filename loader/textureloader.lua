local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.loader%.textureloader")

---@type Adore.Loader
local Loader = require(ADORE_PATH..".loader")
---@type Adore.AssetCollection
local AssetCollection = require(ADORE_PATH..".loader.assetcollection")
local Common = require(ADORE_PATH..".common")

---@class TextureSource
---@field texture love.Texture
---@field quad love.Quad
---@field from table # Where this asset came from (fields for `.handler` and `.reloader`)
---@field fromId integer # The ID in the source loader

---@class TextureLoader: Adore.AssetCollection
local TextureLoader = AssetCollection:extend()
TextureLoader.TYPE = "TextureLoader"

local EXTENSION_TO_COLLECTION = {
	jpg = "ImageLoader",
	jpeg = "ImageLoader",
	png = "ImageLoader",
	bmp = "ImageLoader",
	tga = "ImageLoader",
	hdr = "ImageLoader",
	pic = "ImageLoader",
	exr = "ImageLoader",
}

---Calls `method` on the collections. Either `handler` or `get`.
---@param method "handler" | "get"
---@param path string
---@param ... unknown
---@return TextureSource
---@return integer AssetID
local function genericHandle(method, path, ...)
	-- TextureLoader is not real; it is like a 'base class'
	-- Other collections load their assets into the TextureLoader.
	-- It points to the relevant resource loader or 'ImageLoader' when the asset is not loaded.
	-- Load your atlases and sheets before using TextureLoader.

	local extension = path:match("%.(.*)$")
	if extension == "lua" then
		-- It's a Lua module, load it with the relevant loader
		local requirePath = path:gsub("%.lua$", ""):gsub("[/\\]", ".")
		local success, result = pcall(require, requirePath)

		if not success then
			error(("Lua asset at '%s' failed to load: \n%s"):format(path, result))
		end

		local type = result.type
		if not Common._paths[type] then
			error(("Asset at '%s' has an invalid type '%s'"):format(path, type))
		end

		-- Load the Loader for this type
		local _ = Common[type]
		local collection = Loader.getCollection(type)
		local asset, id = collection[method](collection, path)
		return asset, id
	end

	-- See if there's another collection for this
	local collectionName = EXTENSION_TO_COLLECTION[extension]
	if not collectionName then
		error(("TextureLoader cannot load '%s' (unsupported extension '%s')"):format(path, extension))
	end

	-- Use that collection
	local collection = Loader.getCollection(collectionName)
	return collection[method](collection, path)
end

---@param path string
---@return TextureSource
---@return AssetID
function TextureLoader:handler(path, ...)
	-- TextureLoader is not real; it is like a 'base class'
	-- Other collections load their assets into the TextureLoader.
	-- It points to the relevant resource loader or 'ImageLoader' when the asset is not loaded.
	-- Load your atlases and sheets before using TextureLoader.

	return genericHandle("handler", path, ...)
end

---@param path string
---@param ... unknown
---@return TextureSource
---@return AssetID
function TextureLoader:get(path, ...)
	local id = self.pathToId[path]
	if id then
		return self.assets[id], id
	end
	return genericHandle("get", path, ...)
end

---@param collection Adore.AssetCollection
---@param path string
---@param ... unknown
function TextureLoader:reloader(collection, path, ...)
	local assetId = collection.pathToId(path)
	if not assetId then
		error(("AssetID at path '%s' not found"):format(path))
	end

	---@type TextureSource
	local tSource = collection.assets[assetId]
	if not tSource then
		error(("Asset at path '%s' not found"):format(path))
	end

	-- Reload using the collection this texture source came from
	local from = tSource.from
	local fromCollection = Loader.getCollection(from.collectionName)
	tSource.from.reloader(fromCollection, fromCollection.idToPath[tSource.fromId])
end

Loader.addCollection(TextureLoader)
return TextureLoader
