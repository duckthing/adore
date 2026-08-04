local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes

local Control = Nodes("Control")
local TabContainer = Nodes("TabContainer")
local VBox = Nodes("VBox")
local HBox = Nodes("HBox")
local Button = Nodes("Button")
local TextureButton = Nodes("TextureButton")
local Label = Nodes("Label")
local PopupMenu = Nodes("PopupMenu")
local WindowPopup = Nodes("WindowPopup")
local LineEdit = Nodes("LineEdit")

local SceneTreeViewer = require(ADORE_PATH..".toolbox.ui.scenetree")
local Inspector = require(ADORE_PATH..".toolbox.ui.inspector")
local FileBrowser = require(ADORE_PATH..".toolbox.ui.filebrowser")
local Assets = require(ADORE_PATH..".toolbox.assets")
---@type Toolbox.EditableScene
local EditableScene = require(ADORE_PATH..".toolbox.editablescene")
---@type Toolbox.GameScene
local GameScene = require(ADORE_PATH..".toolbox.gamescene")

---@class Toolbox.MainWindow: Control
---@overload fun(toolbox: Toolbox): Toolbox.MainWindow
local MainWindow = Control:extend()
MainWindow.CLASS_NAME = "MainWindow"

local gameActions = {
	{
		Assets.Reload,
		"reloadScene",
	},
	{
		Assets.Pause,
		"togglePause",
	},
}

local menuActions = {
	{
		"Scene",
		{
			{label = "Save Scene", func = function(window)
				---@cast window Toolbox.MainWindow
				window:saveScene()
			end},
			{label = "Load Scene", func = function(window)
				---@cast window Toolbox.MainWindow
				window:loadScene()
			end},
			{label = "Reload Scene", func = function(window)
				---@cast window Toolbox.MainWindow
				window:reloadScene()
			end},
		}
	},
	{
		"Project",
		{}
	},
}

---@param toolbox Toolbox
function MainWindow:new(toolbox, subroot)
	MainWindow.super.new(self)
	self:setAnchors(0, 0, 1, 1)
	self.toolbox = toolbox

	--======== GAME TABS
	local tabContainer = TabContainer()
	tabContainer:setAnchorsAndOffsets(
			0, 0, 1, 1,
			260, 36, -260, -240
	)
	tabContainer.tabSelected:connectCallable(function(_, index, tabInfo)
		self.sceneTree:setStartNode(tabInfo.node)
		self:updateButtonTexture()
	end)
	self.tabContainer = tabContainer

	--======== ORIGINAL ROOT
	---@type Toolbox.GameScene # Where the game is rendered to
	local subWindow = GameScene(subroot)
	---@type integer # The index of the currently fullscreened tab
	self._tabIndex = 1
	---@type Toolbox.EditableScene? # The current tab, including when fullscreened
	self._currentTab = subWindow
	---@type boolean # Whether the game window takes up the whole window
	self._fullView = true

	--======== EDITOR
	local editor = Control()
	editor:setAnchors(0, 0, 1, 1)
	self.editor = editor

	--======== MENU BAR
	local menuBar = HBox()
		:setAnchorsAndOffsets(
			0, 0, 1, 0,
			-4, 0, -180, 32
		)
		:setMargin(4)
		:setPadding(12)
		:setVariant("topbar")

	for i = 1, #menuActions do
		local action = menuActions[i]
		local button = Button(action[1])
			:setAnchorsAndOffsets(
				0, 0, 0, 1,
				0, 0, 60, 0
			)
			:setVariant("flat")
		local popupMenu = PopupMenu(action[2])
			:setAnchors(0, 1, 0, 1)
		button:addChild(popupMenu)

		button.clicked:connectCallable(function(...)
			popupMenu:popup()
		end)

		popupMenu.itemSelected:connectCallable(function(_, itemIndex, item)
			local f = item.func
			if f then f(self) end
		end)

		menuBar:addChild(button)
	end

	--======== GAME BAR
	local gameActionBar = HBox()
		:setAnchorsAndOffsets(
			1, 0, 1, 0,
			-176, 0, 4, 32
		)
		:setMargin(4)
		:setVariant("topbar")

	for i = 1, #gameActions do
		local action = gameActions[i]
		local button = TextureButton(action[1])
			:setAnchorsAndOffsets(
				0, 0, 0, 1,
				0, 0, 32, 0
			)
		button.clicked:connect(self, action[2])
		gameActionBar:addChild(button)
	end

	---@type TextureButton
	self.pauseButton = gameActionBar.children[2]

	--======== SCENE TREE
	do
		---@type Toolbox.SceneTree
		local sceneTree = SceneTreeViewer(toolbox, subWindow)
			:setAnchorsAndOffsets(
				0, 0, 1, 1,
				0, 36, 0, 0
			)
		self.sceneTree = sceneTree

		local sceneTreeContainer = Control()
			:setAnchorsAndOffsets(
				0, 0, 0, 1,
				0, 40, 252, 0
			)
			:setVariant("panel")
		self.sceneTreeContainer = sceneTreeContainer

		local label = Label("Scene Tree")
			:setAnchors(0, 0, 1, 0)
			:setOffsets(5, 0, 0, 30)
			:setAlign("left")
			:setJustify("center")
			:setFontSize(16)

		sceneTreeContainer:addChild(sceneTree)
		sceneTreeContainer:addChild(label)
	end

	--======== INSPECTOR
	local inspector = Inspector(toolbox, self.sceneTree)
		:setAnchorsAndOffsets(
			1, 0, 1, 1,
			-252, 40, 0, 0
		)
	self.inspector = inspector

	--======== FILE BROWSER
	local fileBrowser = FileBrowser(toolbox)
		:setAnchorsAndOffsets(
			0, 1, 1, 1,
			264, -233, -264, 0
		)
	self.fileBrowser = fileBrowser

	--======== SCENE STRUCTURE
	editor:addChild(self.sceneTreeContainer)
	editor:addChild(inspector)
	editor:addChild(fileBrowser)
	editor:addChild(gameActionBar)
	editor:addChild(menuBar)
	editor:addChild(tabContainer)
	editor:hide()

	self:addChild(editor)
	self:addChild(subWindow)
end

---Returns the subroot container
---@return Toolbox.EditableScene?
function MainWindow:getSubrootContainer()
	if self._fullView then return self._currentTab end
	local selectedTab = self.tabContainer:getActiveTab()
	if selectedTab and selectedTab:is(EditableScene) then
		---@cast selectedTab Toolbox.EditableScene
		return selectedTab
	end
	return nil
end

---Changes the pause button texture
function MainWindow:updateButtonTexture()
	local srContainer = self:getSubrootContainer()
	self.pauseButton:setTexture((srContainer and srContainer._running) and Assets.Pause or Assets.Play)
end

---Toggles the pause mode of the current tab
function MainWindow:togglePause()
	local srContainer = self:getSubrootContainer()
	if srContainer then
		srContainer._running = not srContainer._running
		srContainer._errorMessage = nil
		self:updateButtonTexture()
	end
end

---Toggles fullscreen of the current tab
function MainWindow:toggleFull()
	if not self._fullView then
		-- We are going to fullscreen
		-- Remove the current tab from the TabContainer, and make it fullscreen on the main window
		local tab = self.tabContainer:getActiveTab()
		if tab then
			self._fullView = true
			self._tabIndex = self.tabContainer:getIndexOfChild(tab)

			self:addChild(tab)
			tab:setVisible(true)
			self._currentTab = tab

			self.editor:setVisible(false)
		end
	else
		-- We are exiting fullscreen
		-- Re-insert it into the TabContainer
		local tab = self._currentTab
		if tab then
			self._fullView = false
			self.tabContainer:insertChild(tab, self._tabIndex)
			self.tabContainer:selectTab(tab)

			self.editor:setVisible(true)
		end
	end
end

---Reloads the scene of the current tab
function MainWindow:reloadScene()
	local srContainer = self:getSubrootContainer()
	if not srContainer then return end
	srContainer._running = true
	srContainer:handleOnSubroot("reloadCurrentScene")
end

---Saves the scene of the current tab
function MainWindow:saveScene()
	local srContainer = self:getSubrootContainer()
	if not srContainer then return end

	-- Create the popup
	local window = WindowPopup()
	window:setAnchorsAndOffsets(
		0.5, 0.5, 0.5, 0.5,
		-90, -60, 90, 60
	)

	window:getTitleLabel():setText("Save to...")

	local vbox = VBox()
	vbox:setAnchorsAndOffsets(
			0, 0, 1, 1,
			10, 10, -10, 0
		)
		:setResizeToContent(true)
		:setMargin(4)

	-- Create the fields
	-- == File path Label
	vbox:addChild(Label("File Path"):setAnchors(0, 0, 1, 0))

	-- == File path LineEdit
	local userPath = love.filesystem.getWorkingDirectory()
	local pathField = LineEdit(userPath.."/myScene.lua")
	pathField:setAnchors(0, 0, 1, 0)
		:setAlign("right")
	vbox:addChild(pathField)

	window:addChild(vbox)

	-- Connect events
	window:addAction("Cancel").clicked:connect(window, "close")
	local save = window:addAction("Save")
	save.clicked:connectCallable(function(...)
		local sceneRoot = srContainer.subroot.children[1]

		local ObjectSaver = Adore.Common("ObjectSaver")
		local TableScene = Adore.Resources("TableScene")
		local tableScene = TableScene()
		tableScene:pack(sceneRoot)

		local NativeFS = Adore.Libraries("NativeFS")
		local file = NativeFS.newFile(pathField._text)
		local success, err = ObjectSaver.saveToFile(file, tableScene, "lua")
		if success then
			print("written to path:", pathField._text)
			window:close()
		else
			print(err)
		end
	end)

	-- Show the popup
	self:addChild(window)
	window:popup()
	self:getRoot():uiSelectNext()
end

---Loads the scene and opens it
function MainWindow:loadScene()
	local ObjectSaver = Adore.Common("ObjectSaver")
	local obj, err = ObjectSaver.loadFromFilePath("myScene.lua", "lua", "SceneFactory", true)
	if obj then
		local eScene = EditableScene()
		eScene:createSubroot()
		eScene:changeSceneTo(obj)
		self.tabContainer:addChild(eScene)
	else
		print(err)
		return
	end
end

return MainWindow
