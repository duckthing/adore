local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local Resources = Adore.Resources

local EScene = require(ADORE_PATH..".toolbox.editablescene")

---@class Toolbox.GameScene: Toolbox.EditableScene
---@overload fun(root: RootNode?): Toolbox.GameScene
local GScene = EScene:extend()
GScene._pauseMode = "inherit"

---@param root RootNode
function GScene:new(root)
	GScene.super.new(self, root)
	self.name = "Game"
	self._running = true
end

return GScene
