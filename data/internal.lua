---@diagnostic disable: assign-type-mismatch
local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.data%.internal")

local LazyRequire = require(ADORE_PATH..".lazyrequire")

local Internal
do
---@enum (key) Adore.Internal
local internalPaths = {
	---@type AnimationTrack
	AnimationTrack = "data.animation.animationtrack",
		---@type PropertyTrack
		PropertyTrack = "data.animation.propertytrack",
	-- AssetCollection objects that are used internally and should not be created directly
	TextureLoader = "loader.textureloader",
	ImageLoader = "loader.imageloader",
	AtlasLoader = "loader.atlasloader",
	SheetLoader = "loader.sheetloader",
	ProcLoader = "loader.procloader",
	FontLoader = "loader.fontloader",
	ObjectLoader = "loader.objectloader",
	ShaderLoader = "loader.shaderloader",
}
Internal = LazyRequire(internalPaths)
end

return Internal
