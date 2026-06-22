local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.loader%.imageloader")

---@type Adore.Loader
local Loader = require(ADORE_PATH..".loader")
---@type Adore.AssetCollection
local AssetCollection = require(ADORE_PATH..".loader.assetcollection")

---ImageLoader does loading through `love.graphics.newImage`.
---Called automatically by `TextureLoader`, do not use this directly.
---@class ImageLoader: Adore.AssetCollection
---@field get fun(self: ImageLoader, path: string): TextureSource, AssetID
local ImageLoader = AssetCollection:extend()
ImageLoader.TYPE = "ImageLoader"

---@param path string
---@return TextureSource
function ImageLoader:handler(path)
	local image = love.graphics.newImage(path)
	local tw, th = image:getDimensions()
	local quad = love.graphics.newQuad(0, 0, tw, th, tw, th)
	---@type TextureSource
	local tSource = {
		texture = image,
		quad = quad,
		from = ImageLoader,
		fromId = 0,
	}
	return tSource
end

function ImageLoader:register(asset, path)
	-- Handler should not register assets into the TextureLoader
	ImageLoader.super.register(self, asset, path)
	asset.fromId = Loader.getCollection("TextureLoader"):register(asset, path)
end

function ImageLoader:reloader(path, ...)
	local id = self.pathToId[path]
	---@type TextureSource
	local tSource = self.assets[id]
	local imageData = love.image.newImageData(path)
	local image = tSource.texture
	---@cast image love.Image
	image:replacePixels(imageData)
	imageData:release()
end

Loader.addCollection(ImageLoader)
return ImageLoader
