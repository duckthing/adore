local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local Libraries = Adore.Libraries

local Assets = require(ADORE_PATH..".toolbox.assets")
local Control = Nodes("Control")
local Label = Nodes("Label")
local LineEdit = Nodes("LineEdit")
local Button = Nodes("Button")
local HBox = Nodes("HBox")
local VBox = Nodes("VBox")

local usingFFI = not not Adore.Common("ffilib")
-- Use the best filesystem
local filesystem = love.filesystem
local LuaPath = Libraries("LuaPath")

---@class Toolbox.FileBrowser: Control
---@overload fun(toolbox: Toolbox): Toolbox.FileBrowser
local FileBrowser = Control:extend()
FileBrowser.CLASS_NAME = "FileBrowser"

---@param toolbox Toolbox
function FileBrowser:new(toolbox)
	FileBrowser.super.new(self)
	self:setVariant("panel")
	self.name = "Files"

	if not usingFFI then
		-- TODO: Support non-FFI filesystem
		local label = Label("Filesystem is only available on desktop")
		label:setAnchors(0, 0, 1, 1)
			:setAlign("center")
			:setJustify("center")
		self:addChild(label)
		return
	end

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

	local ICON_SIZE = 24
	do
		-- The path LineEdit and other actions
		local hbox = HBox()
		hbox:setAnchorsAndOffsets(
			0, 0, 1, 0,
			4, 4, -4, ICON_SIZE + 4
		)
		local reloadButton = Button()
			:setOffsets(0, 0, ICON_SIZE, ICON_SIZE)
			:setIcon(Assets.Reload)
			:setIconExpand(true)

		hbox:addChild(pathLE)
		hbox:addChild(reloadButton)
		self:addChild(hbox)
	end

	local itemVBox = VBox()
		:setAnchorsAndOffsets(
			0, 0, 1, 1,
			4, ICON_SIZE + 8, -4, 0
		)
		:setClipChildren(true)
	self.itemVBox = itemVBox

	self:addChild(itemVBox)

	self:openDirectory("/")
end

---@param button Button
function FileBrowser:_onDirButtonPressed(button)
	self:openDirectory(self.pathLE._submittedText..button._text)
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
	self.itemVBox:clearChildren(true)
	self.itemVBox._offsetY = 0
	do
		local goUpButton = Button("[Go up]")
			:setAnchors(0, 0, 1, 0)
			:setTextAlign("left")
		goUpButton.clicked:connect(self, "goUp")
		self.itemVBox:addChild(goUpButton)
	end


	local items = filesystem.getDirectoryItems(dir)
	for _, itemPath in ipairs(items) do
		-- Make a button for directories first
		local button = Button(itemPath.."/")
			:setAnchors(0, 0, 1, 0)
			:setTextAlign("left")
		local info = filesystem.getInfo(dir..itemPath, "directory")
		if info then
			button.clicked:connect(self, "_onDirButtonPressed")
			self.itemVBox:addChild(
				button
			)
		end
	end

	for _, itemPath in ipairs(items) do
		-- Make a button for files second
		local button = Button(itemPath)
			:setAnchors(0, 0, 1, 0)
			:setTextAlign("left")
		local info = filesystem.getInfo(dir..itemPath, "file")
		if info then
			self.itemVBox:addChild(
				button
			)
		end
	end
end

return FileBrowser
