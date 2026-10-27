---@type AdoreInit
local Adore = require ""
local Object = Adore.Resources("Object")

---Configuration for Adore projects, which is written into by Toolbox.
---Generate configuration with `Adore:config("project.toml")` before creating the root.
---@class ProjectConfig: Object
---@overload fun(): ProjectConfig
local ProjectConfig = Object:extend()
ProjectConfig.CLASS_NAME = "ProjectConfig"

function ProjectConfig:new()
	ProjectConfig.super.new(self)

	---@type string # Where this file came from
	self.path = "project.toml"
	---@type "json" | "toml"
	self.extension = "toml"

	---A map of class names to their Lua module paths
	---```lua
	---{
	---	Player = "nodes.player",
	---	TileMap = "nodes.tilemap",
	---}
	---@type {[string]: string}?
	self.userPaths = {}

	---@type string # The default scene to launch
	self.defaultScenePath = nil
end

---@type {[string]: fun(config: ProjectConfig): string?}
local configWriters = {
	json = function(config)
		local JSON = Adore.Libraries("JSON")
		return JSON.encodePretty(config)
	end,
	toml = function(config)
		local TinyTOML = Adore.Libraries("TinyTOML")
		return TinyTOML.encode(config)
	end
}

---Writes the `ProjectConfig` to the file it came from
function ProjectConfig:writeToFile()
	local path, extension = self.path, self.extension
	if not (path and extension) then return end
	local LuaPath = Adore.Libraries("LuaPath")

	-- Get the encoded data
	local writer = configWriters[extension]
	local encoded = writer(self)
	if not encoded then
		error("Failed to encode data for project config")
	end

	-- Create the directories and write them
	local NativeFS = Adore.Libraries("NativeFS")
	NativeFS.createDirectory(LuaPath:dir_name(path))
	assert(NativeFS.write(path, encoded), "Failed to write project config")
	print(("[Adore.ProjectConfig] Wrote to '%s'"):format(path))
end

function ProjectConfig._addDefinition(entry)
	entry:newString("path", "project.toml")
	entry:newString("extension", "toml")
	entry:newMap(
		"userPaths",
		entry:newString("className"):popProperty(),
		entry:newString("modname"):popProperty()
	)
	entry:newString("defaultScenePath")
end

return ProjectConfig
