local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.loader%.fontloader")

---@type Adore.Loader
local Loader = require(ADORE_PATH..".loader")
---@type Adore.AssetCollection
local AssetCollection = require(ADORE_PATH..".loader.assetcollection")

---@class FontLoader: Adore.AssetCollection
---@field get fun(self: FontLoader, path: string): FontSource, AssetID
local FontLoader = AssetCollection:extend()
FontLoader.TYPE = "FontLoader"

---@class FontSource
---@field path string
---@field hinting love.HintingMode
---@field [integer] love.Font

---@type integer
local DEFAULT_FONT_SIZE
if love.getVersion() >= 12 then
	DEFAULT_FONT_SIZE = 13
else
	DEFAULT_FONT_SIZE = 12
end

-- Fonts require a special handler; on top of a font path, they need a size to get something drawable
-- * `Loader:getCollection("love.Font"):get("")` will return the AssetID to this object
-- * `Loader:getCollection("love.Font").assets[id]` will return this object
-- * `Loader:getCollection("love.Font").assets[id][size]` FINALLY returns a `love.Font`
local FontMT = {
	---@param self FontSource
	---@param k number
	---@return love.Font
	__index = function(self, k)
		-- The key should be a number, as its the font size
		-- You can pass in 0 for the default font size
		assert(type(k) == "number", "Expected a number for the font size")
		assert(k >= 0, "Font size should be 0 or greater")
		---@cast k number

		-- If the font size is a non-integer, lets check if the integer part exists
		local floored = math.floor(k)
		if k ~= floored then
			k = floored
			local font = rawget(self, floored)
			if font then return font end
		end

		if self.path == "" then
			-- An empty path returns the default font
			local font
			if k > 0 then
				font = love.graphics.newFont(k, self.hinting)
			else
				font = love.graphics.newFont(DEFAULT_FONT_SIZE, self.hinting)
			end
			self[k] = font
			return font
		else
			-- Anything else is a file path
			local font
			if k > 0 then
				font = love.graphics.newFont(self.path, k, self.hinting)
			else
				font = love.graphics.newFont(self.path, nil, self.hinting)
			end
			self[k] = font
			return font
		end
	end,
	__tostring = function(t)
		return ("FontSource (path: %s)"):format((t.path ~= "" and t.path) or "[BUILT-IN]")
	end
}

function FontLoader:handler(path)
	-- Returns a table that, when indexed with a number (font size), returns the love.Font that should be used
	-- `Loader.getCollection("love.Font")[assetId][size]` => love.Font
	local realPath, hinting = path:match("(.*)@(.*)")
	if hinting then
		path = realPath
	else
		hinting = "normal"
	end

	---@type FontSource
	local t = {
		path = path,
		hinting = hinting,
	}
	return setmetatable(t, FontMT)
end

---@param asset FontSource
---@param path string
---@ret
function FontLoader:register(asset, path)
	local realPath, hinting = path:match("(.*)@?(.*)")
	if asset.hinting == "normal" then
		if hinting and hinting ~= "" then
			-- Register the asset to the path without the postfix
			FontLoader.super.register(self, asset, realPath)
		else
			-- Register the asset to the path WITH the postfix
			FontLoader.super.register(self, asset, path.."@normal")
		end
	end

	return FontLoader.super.register(self, asset, path)
end

---@param collection Adore.AssetCollection
---@param path string
---@param ... unknown
function FontLoader:reloader(collection, path, ...)
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

Loader.addCollection(FontLoader)
return FontLoader
