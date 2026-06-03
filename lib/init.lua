---@diagnostic disable: assign-type-mismatch
local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.lib")

local LazyRequire = require(ADORE_PATH..".lazyrequire")

local Libraries
do
---@enum (key) Adore.Libraries
local libraryPaths = {
	---@type SimpleObject
	SimpleObject = "lib.classic",
	---@type InputField
	InputField = "lib.inputfield",
	---@type Flux
	Flux = "lib.flux",
	NativeFS = "lib.nativefs",
	Shash = "lib.shash",
	---@type TinyTOML
	TinyTOML = "lib.tinytoml",
	Serpent = "lib.serpent",
	RTA = "lib.runtimeatlas",
	Expression = "lib.expression",
}
Libraries = LazyRequire(libraryPaths, true)
end

return Libraries
