---Configuration for Adore projects.
---Written into by Toolbox.
---@class Adore.ProjectConfig
---@overload fun(): Adore.ProjectConfig
local ProjectConfig = {}
local ConfigMT
ConfigMT = {
	__index = ProjectConfig,
	__call = function()
		local t = setmetatable({}, ConfigMT)
		ProjectConfig.new(t)
		return t
	end,
}

function ProjectConfig:new()
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

return setmetatable(ProjectConfig, ConfigMT)
