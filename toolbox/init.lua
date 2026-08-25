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

---An array of every path in this project
---@type string[]
local allFiles = {}

---An array of string patterns to avoid searching
---@type string[]
local excludedSearchPatterns = {
	"^%.",
	"^"..ADORE_PATH,
}

---Whether the array of all class names should be updated
---@type boolean
local shouldReloadFileList = true

---Marks the file list to reload on next call to `Toolbox.getFilePaths()`
function Toolbox.reloadFileList()
	shouldReloadFileList = true
end

---Adds a file path for Toolbox to include while searching.
---If this item is a directory, it won't include items underneath automatically.
---@param path string
function Toolbox.addFilePath(path)
	local length = #allFiles
	for i = 1, length do
		-- Only insert if not found
		if allFiles[i] == path then return end
	end
	allFiles[length+1] = path
end

do
local info = {}

---Adds files from a starting folder
---@param folder string
local function addFromDirectory(folder)
	---@type string[]
	local dirItems = love.filesystem.getDirectoryItems(folder)
	for i = 1, #dirItems do
		local localPath = dirItems[i]

		local excluded = false
		for j = 1, #excludedSearchPatterns do
			-- Check if this item matches any excluded patterns
			local pattern = excludedSearchPatterns[j]
			if localPath:match(pattern) then
				-- Exclude it
				excluded = true
				break
			end
		end

		if not excluded then
			-- This path isn't excluded, work on it
			local fullPath = folder..localPath
			love.filesystem.getInfo(fullPath, info)
			local fileType = info.type

			if fileType == "file" then
				allFiles[#allFiles+1] = fullPath
			elseif fileType == "directory" then
				addFromDirectory(fullPath.."/")
			end
		end
	end
end

---Returns a read-only array containing every file path in this project
---@return string[] filePaths
function Toolbox.getFilePaths()
	if shouldReloadFileList then
		shouldReloadFileList = false

		-- Clear the array
		for i = #allFiles, 1, -1 do
			allFiles[i] = nil
		end

		-- Now get every class name
		addFromDirectory("")
	end
	return allFiles
end
end

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
