---@diagnostic disable: assign-type-mismatch
local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.common")

local LazyRequire = require(ADORE_PATH..".lazyrequire")

local Common
do
---@enum (key) Adore.Common
local commonPaths = {
	Color = "common.color",
	VecMath = "common.vecmath",
	---@type Signal
	Signal = "common.signal",
	---@type ObjectSaver
	ObjectSaver = "objectsaver",
	---@type ClassDB
	ClassDB = "common.classdb",
	---@type Vec2
	Vec2 = "common.vec2",
	---@type Rect2
	Rect2 = "common.rect2",
	---@type Structures
	Structures = "common.structures",
	---@type ffilib
	ffilib = "common.ffilib",
	---@type bitlib
	bitlib = "common.bitlib",
	---@type NoiseGen
	NoiseGen = "common.noisegen",
	Expression = "lib.expression",
	TextureLoader = "loader.textureloader",
	ImageLoader = "loader.imageloader",
	AtlasLoader = "loader.atlasloader",
	SheetLoader = "loader.sheetloader",
	ProcLoader = "loader.procloader",
	FontLoader = "loader.fontloader",
	---@type Adore.Loader
	["Adore.Loader"] = "loader",
	---@type Adore.AssetCollection
	["Adore.AssetCollection"] = "loader.assetcollection"
}
Common = LazyRequire(commonPaths)
end

return Common
