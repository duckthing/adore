--[[ local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.data")
---@type AdoreInit
local Adore = require(ADORE_PATH) --]]

---Configuration for Adore (and Toolbox)
---@class AdoreInit.Config
---@overload fun(): AdoreInit.Config
local Config = {}
local ConfigMT
ConfigMT = {
	__index = Config,
	__call = function()
		local t = setmetatable({}, ConfigMT)
		Config.new(t)
		return t
	end,
}

function Config:new()
	---@type string # Where this file came from
	self.path = "config.toml"
	---@type "json" | "toml"
	self.extension = "toml"

	---A map of class names to their Lua paths
	---```lua
	---{
	---	Player = "nodes.player",
	---	TileMap = "nodes.tilemap",
	---}
	---@type {[string]: string}?
	self.userPaths = {}

end

return setmetatable(Config, ConfigMT)
