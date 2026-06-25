---@type Adore.Loader
local Loader = require "loader"
---@type Adore.AssetCollection
local AssetCollection = require "loader.assetcollection"

---Will get replaced in the future
---@alias ShaderSource
---| love.Shader

---ShaderLoader reads shaders on disk into `love.graphics.newShader`
---@class ShaderLoader: Adore.AssetCollection
---@field get fun(self: ShaderLoader, path: string): ShaderSource, AssetID
local ShaderLoader = AssetCollection:extend()
ShaderLoader.TYPE = "ShaderLoader"

---@param path string
---@return ShaderSource
function ShaderLoader:handler(path)
	-- Reads from a file and puts it into a shader
	-- Will also log any warning with the shader
	local contents, errMessage = love.filesystem.read("string", path)
	if contents == nil then error(errMessage) end
	---@cast contents string
	local shader = love.graphics.newShader(contents)
	local warnings = shader:getWarnings()
	if warnings ~= "vertex shader:\npixel shader:\n" then
		-- Returned warnings are weird...
		print(("[ShaderLoader (%s)]:\n%s"):format(path, warnings))
	end
	return shader
end

function ShaderLoader:reloader(path)
	local id = self.pathToId[path]
	local newShader = self:handler(path)
	self.assets[id] = newShader
end

Loader.addCollection(ShaderLoader)
return ShaderLoader
