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

---@type ShortcutContext.ActionMap
local actions = {
	addNode = function(context, isRepeat)
		if mainWindow._fullView then return end
		mainWindow:addNode()
	end,
	saveScene = function(context, isRepeat)
		if mainWindow._fullView then return end
		mainWindow:saveScene()
	end,
	saveSceneAs = function(context, isRepeat)
		if mainWindow._fullView then return end
		mainWindow:saveSceneAs()
	end,
	loadScene = function(context, isRepeat)
		if mainWindow._fullView then return end
		mainWindow:loadScene()
	end,
	reloadScene = function(context, isRepeat)
		if mainWindow._fullView then return end
		mainWindow:reloadScene()
	end,
	closeScene = function(context, isRepeat)
		if mainWindow._fullView then return end
		mainWindow:closeScene()
	end,

	toggleFullView = function(context, isRepeat)
		mainWindow:toggleFull()
	end
}
---@type ShortcutContext.Keybinds?
local pressedKeybinds = {
	normal = {
		["`"] = "toggleFullView",
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
