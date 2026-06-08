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
}
Internal = LazyRequire(internalPaths)
end

return Internal
