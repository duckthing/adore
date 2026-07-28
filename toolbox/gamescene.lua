local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local Resources = Adore.Resources

local EScene = require(ADORE_PATH..".toolbox.editablescene")

---@class Toolbox.GameScene: Toolbox.EditableScene
local GScene = EScene:extend()
GScene._pauseMode = "inherit"

function GScene:new(root)
	GScene.super.new(self, nil, root)
	self.name = "Game"
end

function GScene:update(dt)
end

return GScene
