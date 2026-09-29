---@type Adore.Loader
local Loader = require "loader"
---@type Adore.AssetCollection
local AssetCollection = require "loader.assetcollection"

---@class SoundLoader: Adore.AssetCollection
---@field get fun(self: SoundLoader, path: string): TextureSource, AssetID
local SoundLoader = AssetCollection:extend()
SoundLoader.TYPE = "SoundLoader"

---@class SoundSource
---@field path string
---@field _intSource love.Source? # Use SoundSource:get() instead
---@field type "static" | "stream"
local SoundSource = {}
local SoundSourceMT = {
	__index = SoundSource,
	---@param self SoundSource
	__tostring = function(self)
		return ("SoundSource[%s] (%s)"):format(self.type, self.path)
	end
}

---Gets a `love.Source` from this SoundSource
function SoundSource:get()
	if self.type == "static" then
		-- Static sources always have an internal source
		return self._intSource:clone()
	end
	-- Stream sources create their new sources here
	return love.audio.newSource(self.path, "stream")
end

local hintMap = {
	static = "static",
	sound = "static",
	sfx = "static",

	stream = "stream",
	music = "stream",
}

---@param path string
---@return SoundSource
function SoundLoader:handler(path)
	local realPath, hinting = path:match("(.*)@(.*)")
	if hinting then
		local newHinting = hintMap[hinting]
		if not newHinting then
			error(("Hint '%s' of '%s' must be equal to 'static' or 'stream'"):format(hinting, path))
		end
		hinting = newHinting
	else
		hinting = "static"
	end
	if not realPath then realPath = path end

	local source
	if hinting == "static" then
		source = love.audio.newSource(realPath, "static")
	end

	---@type SoundSource
	local sourceDesc = {
		path = realPath,
		_intSource = source,
		type = hinting
	}
	return setmetatable(sourceDesc, SoundSourceMT)
end

Loader.addCollection(SoundLoader)
return SoundLoader
