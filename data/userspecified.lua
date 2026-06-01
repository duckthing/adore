---@diagnostic disable: assign-type-mismatch
local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.data")

local LazyRequire = require(ADORE_PATH..".lazyrequire")

-- These are paths that the user added, so we can load them later in ObjectSaver
local User
do
local internalPaths = {}
User = LazyRequire(internalPaths, true)
end

return User
