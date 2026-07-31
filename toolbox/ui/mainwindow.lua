local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes

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
local MainWindow = Nodes("Control"):extend()
MainWindow.CLASS_NAME = "MainWindow"

local gameActions = {
	{
		Assets.Reload,
		"reloadLevel",
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
			{label = "Save Scene"},
			{label = "Load Scene", func = function(window)
				---@cast window Toolbox.MainWindow
				local eScene = EditableScene()
				eScene:createSubroot()
				eScene:changeSceneTo("src.levels.test")
				window.tabContainer:addChild(eScene)
			end},
			{label = "Reload Scene"},
			{label = "", separator = true},
			{label = "Quit"},
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

	---@type boolean # Whether the game window takes up the whole window
	self._fullView = true

	---@type Toolbox.GameScene # Where the game is rendered to
	local subWindow = GameScene(subroot)

	local tabContainer = Nodes("TabContainer")()
	tabContainer:setAnchorsAndOffsets(
			0, 0, 1, 1,
			260, 36, -260, -240
	)
	tabContainer.tabSelected:connectCallable(function(_, index, tabInfo)
		self.sceneTree:setStartNode(tabInfo.node)
		self:updateButtonTexture()
	end)
	self.tabContainer = tabContainer

	---@type integer # The index of the currently fullscreened tab
	self.oldIndex = 1
	---@type Toolbox.EditableScene? # The fullscreened tab
	self.fullTab = subWindow

	subWindow:setAnchors(0, 0, 1, 1)
	---@type Toolbox.GameScene? # The original subwindow
	self.subWindow = subWindow

	--======== EDITOR
	local editor = Nodes("Control")()
	editor:setAnchors(0, 0, 1, 1)
	self.editor = editor

	--======== MENU BAR
	local menuBar = Nodes("HBox")()
	menuBar:setAnchorsAndOffsets(
		0, 0, 1, 0,
		-4, 0, -180, 32
	)
	menuBar:setMargin(4)
	menuBar:setPadding(12)
	menuBar:setVariant("topbar")

	for i = 1, #menuActions do
		local action = menuActions[i]
		local button = Nodes("Button")(action[1])
		button:setAnchorsAndOffsets(
			0, 0, 0, 1,
			0, 0, 60, 0
		)
		button:setVariant("flat")
		local popupMenu = Nodes("PopupMenu")(action[2])
		popupMenu:setAnchors(0, 1, 0, 1)
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
	local gameActionBar = Nodes("HBox")()
	gameActionBar:setAnchorsAndOffsets(
		1, 0, 1, 0,
		-176, 0, 4, 32
	)
	gameActionBar:setMargin(4)
	gameActionBar:setVariant("topbar")

	for i = 1, #gameActions do
		local action = gameActions[i]
		local button = Nodes("TextureButton")(action[1])
		button:setAnchorsAndOffsets(
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
		self.sceneTree = sceneTree
		sceneTree:setAnchorsAndOffsets(
			0, 0, 1, 1,
			0, 36, 0, 0
		)

		local sceneTreeContainer = Nodes("Control")()
		self.sceneTreeContainer = sceneTreeContainer
		sceneTreeContainer:setAnchorsAndOffsets(
			0, 0, 0, 1,
			0, 40, 252, 0
		)
		sceneTreeContainer:setVariant("panel")
		sceneTreeContainer:addChild(sceneTree)

		local label = Nodes("Label")("Scene Tree")
			:setAnchors(0, 0, 1, 0)
			:setOffsets(5, 0, 0, 30)
			:setAlign("left")
			:setJustify("center")
			:setFontSize(16)
		sceneTreeContainer:addChild(label)
	end

	--======== INSPECTOR
	local inspector = Inspector(toolbox, self.sceneTree)
	self.inspector = inspector
	inspector:setAnchorsAndOffsets(
		1, 0, 1, 1,
		-252, 40, 0, 0
	)

	--======== FILE BROWSER
	local fileBrowser = FileBrowser(toolbox)
	self.fileBrowser = fileBrowser
	fileBrowser:setAnchorsAndOffsets(
		0, 1, 1, 1,
		264, -233, -264, 0
	)

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
---@return Toolbox.EditableScene
function MainWindow:getSubrootContainer()
	if self._fullView then return self.fullTab end
	local selectedTab = self.tabContainer:getActiveTab()
	return selectedTab
end

---Changes the pause button texture
function MainWindow:updateButtonTexture()
	local srContainer = self:getSubrootContainer()
	self.pauseButton:setTexture((srContainer and srContainer._running) and Assets.Pause or Assets.Play)
end

function MainWindow:togglePause()
	local srContainer = self:getSubrootContainer()
	if srContainer then
		srContainer._running = not srContainer._running
		srContainer._errorMessage = nil
		self:updateButtonTexture()
	end
end

function MainWindow:reloadLevel()
	local srContainer = self:getSubrootContainer()
	local subroot = srContainer.subroot
	srContainer._running = true

	srContainer:pushSubroot()
	subroot:reloadCurrentScene()
	srContainer:popSubroot()
end

function MainWindow:onSubrootPushed()
	self.sceneTree:onSubrootPushed()
end

function MainWindow:onSubrootPopped()
	self.sceneTree:onSubrootPopped()
end

function MainWindow:toggleFull()
	---@type boolean # If we're fullscreened now
	local full = not self._fullView
	self._fullView = full

	if full then
		-- We are going to fullscreen
		-- Remove the current tab from the TabContainer, and make it fullscreen on the main window

		-- Get the tab
		local tab = assert(self.tabContainer:getActiveTab(), "Tab doesn't exist")
		self.oldIndex = self.tabContainer:getIndexOfChild(tab)

		self:addChild(tab)
		tab:setVisible(true)
		self.fullTab = tab

		self.editor:setVisible(false)
	else
		-- We are exiting fullscreen
		-- Re-insert it into the TabContainer
		local tab = assert(self.fullTab)
		self.tabContainer:insertChild(tab, self.oldIndex)
		self.tabContainer:selectTab(tab)

		self.editor:setVisible(true)
	end
end

function MainWindow:saveScene()
end

function MainWindow:loadScene()
end

return MainWindow
