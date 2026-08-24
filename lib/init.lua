---@diagnostic disable: assign-type-mismatch
local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.lib")

local LazyRequire = require(ADORE_PATH..".lazyrequire")

---@class NativeFS: love.filesystem

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
	---@type NativeFS
	NativeFS = "lib.nativefs",
	Shash = "lib.shash",
	---@type TinyTOML
	TinyTOML = "lib.tinytoml",
	Serpent = "lib.serpent",
	RTA = "lib.runtimeatlas",
	Expression = "lib.expression",
	---@type JSON
	JSON = "lib.json",
	---@type fzy
	fzy = "lib.fzy",
}
Libraries = LazyRequire(libraryPaths, true)
end

return Libraries
