local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")

---@class Toolbox
local Toolbox = {}

---@class Toolbox.InitOptions
---@field keybinds ShortcutContext.Keybinds? # Any keybinds for Toolbox's ShortcutContext; default is backtick (`) for full view
---@field openEditor boolean? # Should Toolbox start with the editor opened?

---@type AdoreInit
local Adore = require(ADORE_PATH)
local MainWindow = require(PKG_NAME..".ui.mainwindow")

---@type Node
local Node = nil
---@type RootNode
Toolbox.godRoot = nil
---@type Toolbox.MainWindow
Toolbox.mainWindow = nil

do
-- Set Toolbox in Previewer (so it can push/pop the subroot)
local Previewer = require(PKG_NAME..".ui.inspector.previewer")
Previewer.Toolbox = Toolbox
end

---Returns the subroot container
---@return Toolbox.EditableScene?
function Toolbox:getSubrootContainer()
	return Toolbox.mainWindow:getSubrootContainer()
end

return setmetatable(Toolbox, {
	---@param self Toolbox
	---@param originalRoot RootNode
	---@param Adore AdoreInit
	---@param options Toolbox.InitOptions?
	__call = function(self, originalRoot, Adore, options)
		assert(Toolbox.godRoot == nil, "Attempted to initialize Toolbox more than once")

		Node = Adore.Nodes("Node")
		Node._root = nil

		local godRoot = Adore:build({hideSceneWarning = true, allowTabFocus = "withModal"}, require(PKG_NAME..".themes.dark")())
		Toolbox.godRoot = godRoot

		Toolbox.mainWindow = MainWindow(self, originalRoot)
		godRoot:addChild(Toolbox.mainWindow)

		---@type Toolbox.SubrootContext
		local subrootContext = require(PKG_NAME..".subrootcontext")(Toolbox)
		Toolbox.subrootContext = subrootContext
		subrootContext:push()

		---@type Toolbox.ToolboxShortcuts
		local ToolboxShortcuts = require(PKG_NAME..".toolboxshortcuts")
		ToolboxShortcuts:push()
		ToolboxShortcuts:setToolbox(self)

		if options and options.keybinds then
			-- Keybinds exist, set them
			ToolboxShortcuts.pressedKeybinds = options.keybinds
		end

		local defaultCallbacks = originalRoot._defaultCallbacks

		-- Add any overrides we have
		local overrides = {}

		for k, v in pairs(overrides) do
			defaultCallbacks[k] = v
		end

		-- Add the rest
		for i = 1, #originalRoot.ALL_LOVE_CALLBACKS do
			local handler = originalRoot.ALL_LOVE_CALLBACKS[i]
			local existingCallback = defaultCallbacks[handler]
			if not existingCallback then
				-- Add a default that wraps around the RootNode's method
				-- (ex. `update()` becomes `root:update()`)
				defaultCallbacks[handler] = function(_, ...)
					-- Call it on the god root
					-- The even will get passed to the subroot through a Context
					return godRoot[handler](godRoot, ...)
				end
			elseif not overrides[handler] then
				-- Wrap the existing one, if it wasn't by us
				defaultCallbacks[handler] = function(_, ...)
					-- Call it on the god root first
					local handled = godRoot[handler](godRoot, ...)

					local srContainer = self:getSubrootContainer()
					if not handled and srContainer then
						-- If not handled, we pass it into the subroot
						local isPushed = srContainer:isPushed()
						if not isPushed then
							srContainer:pushSubroot()
						end

						handled = existingCallback(srContainer.subroot, ...)

						if not isPushed then
							srContainer:popSubroot()
						end
					end

					return handled
				end
			end
		end

		-- Push the subroot when changing scenes
		local originalChangeScene = originalRoot.changeSceneTo
		originalRoot.changeSceneTo = function(s, constructor)
			local srContainer = self:getSubrootContainer()
			local isPushed = srContainer:isPushed()
			if not isPushed then
				srContainer:pushSubroot()
			end

			originalChangeScene(srContainer.subroot, constructor)

			if not isPushed then
				srContainer:popSubroot()
			end
		end

		if options and options.openEditor then
			self.mainWindow:toggleFull()
		end

		return originalRoot
	end,
})
