local PKG_NAME = ...
---@type string
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
local ASSET_PATH = ADORE_PATH:gsub("%.", "/").."/toolbox/assets/"
---@type AdoreInit
local Adore = require(ADORE_PATH)
local TextureLoader = Adore.Loader.getCollection("TextureLoader")

local assets = {
	Play = TextureLoader:get(ASSET_PATH.."playtex.lua"),
	Pause = TextureLoader:get(ASSET_PATH.."pausetex.lua"),
	Reload = TextureLoader:get(ASSET_PATH.."reloadtex.lua"),
}

return assets
