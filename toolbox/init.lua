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
---@type RootNode?
Toolbox.subRoot = nil
---@type RootNode
Toolbox.godRoot = nil
---@type Toolbox.MainWindow
Toolbox.mainWindow = nil

do
-- Set Toolbox in Previewer (so it can push/pop the subroot)
local Previewer = require(PKG_NAME..".ui.inspector.previewer")
Previewer.Toolbox = Toolbox
end

local toolboxContext = Adore.Resources("ShortcutContext")(
	{
		toggleFullView = function(context, isRepeat)
			Toolbox.mainWindow:toggleFull()
			return true
		end
	},
	{
		normal = {
			["`"] = "toggleFullView",
		}
	}
)
-- 1 below CoreUIContext, so text input in the editor shouldn't get in the way
toolboxContext._priority = 999

function Toolbox:pushSubroot()
	Node._root = Toolbox.subRoot
	Toolbox.mainWindow:onSubrootPushed()
end

function Toolbox:popSubroot()
	Node._root = Toolbox.godRoot
	Toolbox.mainWindow:onSubrootPopped()
end

---Returns `true` if the subroot is active
---@return boolean subrootActive
function Toolbox:isPushed()
	return Node._root == Toolbox.subRoot
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

		Toolbox.subRoot = originalRoot
		local godRoot = Adore:build({hideSceneWarning = true}, require(PKG_NAME..".themes.dark")())
		godRoot.allowTabFocus = false
		Toolbox.godRoot = godRoot
		-- godRoot.drawBackground = function()
		-- 	love.graphics.setColor(0.1, 0.1, 0.12)
		-- 	love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
		-- end

		Toolbox.mainWindow = MainWindow(self)
		godRoot:addChild(Toolbox.mainWindow)

		local subrootContext = require(PKG_NAME..".subrootcontext")(Toolbox)
		Toolbox.subrootContext = subrootContext
		subrootContext:push()
		toolboxContext:push()

		if options and options.keybinds then
			-- Keybinds exist, set them
			toolboxContext.pressedKeybinds = options.keybinds
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

					if not handled and Toolbox.subRoot then
						-- If not handled, we pass it into the subroot
						local isPushed = self:isPushed()
						if not isPushed then
							self:pushSubroot()
						end

						handled = existingCallback(...)

						if not isPushed then
							self:popSubroot()
						end
					end

					return handled
				end
			end
		end

		-- Push the subroot when changing scenes
		local originalChangeScene = originalRoot.changeSceneTo
		originalRoot.changeSceneTo = function(s, c)
			local isPushed = self:isPushed()
			if not isPushed then
				self:pushSubroot()
			end

			originalChangeScene(s, c)

			if not isPushed then
				self:popSubroot()
			end
		end

		if options and options.openEditor then
			self.mainWindow:toggleFull()
		end

		return originalRoot
	end,
})
