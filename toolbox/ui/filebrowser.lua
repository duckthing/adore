local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local Control = Nodes("Control")

---@class Toolbox.FileBrowser: Control
---@overload fun(toolbox: Toolbox): Toolbox.FileBrowser
local FileBrowser = Control:extend()
FileBrowser.CLASS_NAME = "FileBrowser"

---@param toolbox Toolbox
function FileBrowser:new(toolbox)
	FileBrowser.super.new(self)
	self:setVariant("panel")
	self.name = "Files"
end

return FileBrowser
