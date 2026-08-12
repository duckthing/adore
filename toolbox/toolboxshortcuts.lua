local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox.toolboxshortcuts")
---@type AdoreInit
local Adore = require(ADORE_PATH)
---@type ShortcutContext
local ShortcutContext = Adore.Resources("ShortcutContext")

---@class Toolbox.ToolboxShortcuts: ShortcutContext
---@field super ShortcutContext
local ToolboxShortcuts = ShortcutContext:extend()
ToolboxShortcuts.CLASS_NAME = "ToolboxShortcuts"
-- 1 below CoreUIContext, so text input in the editor shouldn't get in the way
ToolboxShortcuts._priority = 999

---@type Toolbox
local toolbox
---@type Toolbox.MainWindow
local mainWindow

---Returns `true` if we are sending most inputs to the game
---@return boolean
local function isGamePrioritized()
	return mainWindow._fullView
end

---@type ShortcutContext.ActionMap
local actions = {
	addNode = function(context, isRepeat)
		if isGamePrioritized() then return false end
		mainWindow:addNode()
		return true
	end,
	saveScene = function(context, isRepeat)
		if isGamePrioritized() then return false end
		mainWindow:saveScene()
		return true
	end,
	saveSceneAs = function(context, isRepeat)
		if isGamePrioritized() then return false end
		mainWindow:saveSceneAs()
		return true
	end,
	loadScene = function(context, isRepeat)
		if isGamePrioritized() then return false end
		mainWindow:loadScene()
		return true
	end,
	reloadScene = function(context, isRepeat)
		if isGamePrioritized() then return false end
		mainWindow:reloadScene()
		return true
	end,
	closeScene = function(context, isRepeat)
		if isGamePrioritized() then return false end
		mainWindow:closeScene()
		return true
	end,

	deleteSelectedNode = function(context, isRepeat)
		if isGamePrioritized() then return false end
		mainWindow:deleteSelectedNode()
		return true
	end,

	toggleFullView = function(context, isRepeat)
		mainWindow:toggleFull()
		return true
	end,
}
---@type ShortcutContext.Keybinds?
local pressedKeybinds = {
	normal = {
		["`"] = "toggleFullView",
		delete = "deleteSelectedNode",
	},
	ctrl = {
		a = "addNode",
		s = "saveScene",
		o = "loadScene",
		r = "reloadScene",
		w = "closeScene",
	},
	altctrl = {
		s = "saveSceneAs",
	},
}

function ToolboxShortcuts:new()
	ToolboxShortcuts.super.new(self, actions, pressedKeybinds)
end

---@param newToolbox Toolbox
function ToolboxShortcuts:setToolbox(newToolbox)
	toolbox = newToolbox
	mainWindow = toolbox.mainWindow
end

return ToolboxShortcuts()
