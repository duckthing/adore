local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local Common = Adore.Common
local Libraries = Adore.Libraries

local Assets = require(ADORE_PATH..".toolbox.assets")
local Control = Nodes("Control")
local Label = Nodes("Label")
local LineEdit = Nodes("LineEdit")
local Button = Nodes("Button")
local HBox = Nodes("HBox")
local VBox = Nodes("VBox")
local PopupMenu = Nodes("PopupMenu")
local SceneFactory = Adore.Resources("SceneFactory")

-- Use the best filesystem
local filesystem = love.filesystem
local ObjectLoader = Adore.Loader.getCollection("ObjectLoader")
local LuaPath = Libraries("LuaPath")

---File extensions that are used for objects
local OBJECT_EXTENSIONS = {
	lua = true,
	json = true,
	toml = true,
	agf = true,
}
local ICON_SIZE = 24
local USING_FFI = not not Common("ffilib")

-- Context menu for right-clicking a file
-- (`func` is a string referencing a method)
---@type PopupMenu.Item[]
local FILE_ACTIONS = {
	{label = "Open", func = "openPressedFile"},
	{label = "Rename...", func = nil},
	{label = "Move...", func = nil},
	{separator = true},
	{label = "Copy", func = nil},
	{label = "Duplicate", func = nil},
	{separator = true},
	{label = "Delete...", func = nil},
	{separator = true},
	{label = "Show in File System", func = "showFileInSystem"},
}

-- Context menu for right-clicking a file
-- (`func` is a string referencing a method)
---@type PopupMenu.Item[]
local DIR_ACTIONS = {
	{label = "Open", func = "openPressedDirectory"},
	{label = "Rename...", func = nil},
	{label = "Move...", func = nil},
	{separator = true},
	{label = "Delete...", func = nil},
	{separator = true},
	{label = "Show in File System", func = "showFolderInSystem"},
}

---@class Toolbox.FileBrowser: Control
---@overload fun(toolbox: Toolbox): Toolbox.FileBrowser
local FileBrowser = Control:extend()
FileBrowser.CLASS_NAME = "FileBrowser"
---@type Toolbox
local Toolbox

---@param toolbox Toolbox
function FileBrowser:new(toolbox)
	FileBrowser.super.new(self)
	self.name = "Files"
	Toolbox = toolbox
	self.toolbox = toolbox

	-- Path LineEdit, which opens a directory when text is submitted
	---@type LineEdit
	local pathLE = LineEdit("/")
		:setAnchorsAndOffsets(
			0, 0, 1, 1,
			0, 0, -24, 0
		)
	self.pathLE = pathLE
	pathLE.textSubmitted:connectCallable(function(_, text)
		self:openDirectory(text)
	end)

	do
		-- HBox that contains the LineEdit and reload button
		local hbox = HBox()
		hbox:setAnchorsAndOffsets(
			0, 0, 1, 0,
			5, 5, -5, ICON_SIZE + 5
		)
		local reloadButton = Button()
			:setOffsets(0, 0, ICON_SIZE, ICON_SIZE)
			:setIcon(Assets.Reload)
			:setIconExpand(true)
			:setVariant("flat")
		reloadButton.clicked:connect(self, "_onReloadButtonPressed")

		hbox:addChild(pathLE)
		hbox:addChild(reloadButton)
		self:addChild(hbox)
	end

	-- The VBox that contains all of the directories and files
	local itemVBox = VBox()
		:setAnchorsAndOffsets(
			0, 0, 1, 1,
			5, ICON_SIZE + 10, -5, 0
		)
		:setClipChildren(true)
	self.itemVBox = itemVBox

	-- PopupMenu for right-clicking a file
	local fileContextMenu = PopupMenu(FILE_ACTIONS)
	fileContextMenu._resizeWithParent = false
	fileContextMenu.itemSelected:connectCallable(function(_, _, item)
		-- Call the function contained in the menu
		local f = item.func
		if f then self[f](self) end
	end)
	self.fileContextMenu = fileContextMenu

	-- PopupMenu for right-clicking a folder
	local dirContextMenu = PopupMenu(DIR_ACTIONS)
	dirContextMenu._resizeWithParent = false
	dirContextMenu.itemSelected:connectCallable(function(_, _, item)
		-- Call the function contained in the menu
		local f = item.func
		if f then self[f](self) end
	end)
	self.dirContextMenu = dirContextMenu

	self:openDirectory("/")

	---@type string # The path of the last pressed file
	self.pressedFile = ""
	---@type string # The path of the last pressed directory
	self.pressedDir = ""

	self:addChild(itemVBox)
	self:addChild(fileContextMenu)
	self:addChild(dirContextMenu)
end

---@param button Button
function FileBrowser:_onReloadButtonPressed(button)
	self:openDirectory(self.pathLE._submittedText)
end

---@param bNode Button
---@param button integer
function FileBrowser:_onDirButtonPressed(bNode, button)
	local path = self.pathLE._submittedText..bNode._text
	self.pressedDir = path

	if button == 1 then
		-- Left-click; open the file
		self:openDirectory(path)
	elseif button == 2 then
		-- Right-click; show context menu
		local dirContextMenu = self.dirContextMenu
		dirContextMenu:setWorldPosition(love.mouse.getPosition())
		dirContextMenu:popup()
	end
end

---@param bNode Button
---@param button integer
function FileBrowser:_onItemButtonPressed(bNode, button)
	-- Remove the starting slash
	local path = self.pathLE._submittedText:match("^/(.*)")..bNode._text
	self.pressedFile = path

	if button == 1 then
		-- Left-click; open the file
		self:openPressedFile()
	elseif button == 2 then
		-- Right-click; show context menu
		local fileContextMenu = self.fileContextMenu
		fileContextMenu:setWorldPosition(love.mouse.getPosition())
		fileContextMenu:popup()
	end
end

---Opens the file at `self.pressedFile`
function FileBrowser:openPressedFile()
	local path = self.pressedFile
	local success, obj = pcall(ObjectLoader.get, ObjectLoader, path)
	if not success then print(obj) return end
	---@cast obj Object
	if obj:is(SceneFactory) then
		---@cast obj SceneFactory
		self.toolbox.mainWindow:getActions().loadSceneFromFactory(obj, path)
	else
		self.toolbox.mainWindow.inspector:onNodeFocusChanged(nil, obj, false)
	end
end

---Opens the file at `self.pressedFile`
function FileBrowser:showFileInSystem()
	local path = love.filesystem.getRealDirectory(self.pressedFile)
	love.system.openURL("file://"..path)
end

---Opens the folder at `self.pressedDir`
function FileBrowser:openPressedDirectory()
	self:openDirectory(self.pressedDir)
end

---Opens the folder at `self.pressedDir`
function FileBrowser:showFolderInSystem()
	local path = love.filesystem.getRealDirectory(self.pressedDir)
	love.system.openURL("file://"..path)
end

---Returns the drag data for an item
---@param button Button
---@return any
---@return Control?
local function getItemDragData(button)
	---@type string # The path, minus the starting slash
	local itemPath = (Toolbox.mainWindow.fileBrowser.pathLE._submittedText:sub(2))..button._text
	local extension = LuaPath:extension_name(itemPath)

	if OBJECT_EXTENSIONS[extension] then
		local success, obj = pcall(ObjectLoader.get, ObjectLoader, itemPath)
		local label = Label(("%s (Object)\nPath: %s"):format(tostring(obj), itemPath))
		if not success then
			print("[Toolbox.FileBrowser.getItemDragData]", obj)
		else
			return {
				type = "object",
				path = itemPath,
				object = obj,
			}, label
		end
	end

	local label = Label(("[Unknown]\nPath: %s"):format(itemPath))
	return {
		type = "path",
		path = itemPath,
	}, label
end

function FileBrowser:goUp()
	self:openDirectory(LuaPath:parent_dir(self.pathLE._submittedText))
end

---Opens the directory
---@param dir string
function FileBrowser:openDirectory(dir)
	dir = LuaPath:ensure_dir_end(dir)
	self.pathLE:setText(dir)

	-- Clear it and add the "go up" button
	local itemVBox = self.itemVBox
	itemVBox:clearChildren(true)
	itemVBox._offsetY = 0
	do
		local goUpButton = Button("[Go up]")
			:setAnchors(0, 0, 1, 0)
			:setTextAlign("left")
		goUpButton.clicked:connect(self, "goUp")
		itemVBox:addChild(goUpButton)
	end


	local items = filesystem.getDirectoryItems(dir)
	for _, itemPath in ipairs(items) do
		-- Make a button for directories first
		local info = filesystem.getInfo(dir..itemPath, "directory")
		if info then
			local button = Button(itemPath.."/")
				:setAnchors(0, 0, 1, 0)
				:setTextAlign("left")
			button.buttonFilter = 3
			button.clicked:connect(self, "_onDirButtonPressed")
			itemVBox:addChild(
				button
			)
		end
	end

	for _, itemPath in ipairs(items) do
		-- Make a button for files second
		local info = filesystem.getInfo(dir..itemPath, "file")
		if info then
			local button = Button(itemPath)
				:setAnchors(0, 0, 1, 0)
				:setTextAlign("left")
			button.buttonFilter = 3
			button.clicked:connect(self, "_onItemButtonPressed")
			button._getDragData = getItemDragData
			itemVBox:addChild(
				button
			)
		end
	end
end

return FileBrowser
