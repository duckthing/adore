local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local Common = Adore.Common
local Resources = Adore.Resources

local ClassDB = Common("ClassDB")
local ObjectSaver = Common("ObjectSaver")
local ObjectLoader = Adore.Loader.getCollection("ObjectLoader")
local TableScene = Resources("TableScene")
local tclear = Common("Structures").tableClear

local Node = Nodes("Node")
local Control = Nodes("Control")
local TabContainer = Nodes("TabContainer")
local HBox = Nodes("HBox")
local Button = Nodes("Button")
local TextureButton = Nodes("TextureButton")
local WindowPopup = Nodes("WindowPopup")
local MenuButton = Nodes("MenuButton")
local PopupMenu = Nodes("PopupMenu")
local FormBuilder = Common("FormBuilder")
local fzy = Adore.Libraries("fzy")
local LuaPath = Adore.Libraries("LuaPath")

local SceneTreeViewer = require(ADORE_PATH..".toolbox.ui.scenetree")
local Inspector = require(ADORE_PATH..".toolbox.ui.inspector")
local FileBrowser = require(ADORE_PATH..".toolbox.ui.filebrowser")
local SignalPanel = require(ADORE_PATH..".toolbox.ui.signalpanel")
local Assets = require(ADORE_PATH..".toolbox.assets")
---@type Toolbox.EditableScene
local EditableScene = require(ADORE_PATH..".toolbox.editablescene")
---@type Toolbox.GameScene
local GameScene = require(ADORE_PATH..".toolbox.gamescene")
local Templates = require(ADORE_PATH..".toolbox.scripttemplates")
---@type Toolbox.Tool
local Tool = require(ADORE_PATH..".toolbox.tool")
---@type Toolbox.Popups
local ToolboxPopups = require(ADORE_PATH..".toolbox.toolboxpopups")
---@type Toolbox.Actions
local ToolboxActions = require(ADORE_PATH..".toolbox.toolboxactions")

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
			{label = "New Scene", func = function(window)
				---@cast window Toolbox.MainWindow
				ToolboxActions.newScene()
			end},
			{label = "Save Scene", func = function(window)
				---@cast window Toolbox.MainWindow
				ToolboxActions.saveScene()
			end},
			{label = "Save As...", func = function(window)
				---@cast window Toolbox.MainWindow
				ToolboxPopups.popupSaveSceneAs()
			end},
			{label = "Load Scene", func = function(window)
				---@cast window Toolbox.MainWindow
				ToolboxPopups.popupLoadScene()
			end},
			{label = "Reload Scene", func = function(window)
				---@cast window Toolbox.MainWindow
				ToolboxActions.reloadScene()
			end},
			{label = "Close Scene", func = function(window)
				---@cast window Toolbox.MainWindow
				ToolboxActions.closeScene()
			end},
		}
	},
	{
		"Editor",
		{
			{label = "Reset Camera", func = function(window)
				---@cast window Toolbox.MainWindow
				local srContainer = window:getSubrootContainer()
				if not (srContainer and srContainer.cameraActive) then return end
				srContainer.camera:setPosition(0, 0):setZoom(1, 1)
			end},
			{label = "Toggle Physics Draw", func = function(window)
				---@cast window Toolbox.MainWindow
				local srContainer = window:getSubrootContainer()
				if not srContainer then return end
				local layers = srContainer.subroot._canvasLayers
				local firstViewport = layers[1]._viewport
				local shouldDraw = not firstViewport.shouldDrawPhysics
				firstViewport.shouldDrawPhysics = shouldDraw
				for i = 2, #layers do
					layers[i]._viewport.shouldDrawPhysics = shouldDraw
				end
			end},
		},
	},
}

---@param toolbox Toolbox
---@param subroot RootNode
function MainWindow:new(toolbox, subroot)
	MainWindow.super.new(self)
	self:setAnchors(0, 0, 1, 1)
	self.toolbox = toolbox
	Tool.mainWindow = self
	ToolboxPopups.setMainWindow(self)
	ToolboxActions.setMainWindow(self)
	ToolboxPopups.setActions(ToolboxActions)
	ToolboxActions.setPopups(ToolboxPopups)

	--======== GAME TABS
	local gameTabContainer = TabContainer()
	gameTabContainer:setAnchorsAndOffsets(
			0, 0, 1, 1,
			260, 36, -260, -240
	)
	gameTabContainer.tabSelected:connectCallable(function(_, index, tabInfo)
		local iterateMode = (tabInfo and tabInfo.node:is(GameScene) and "full") or "owned"
		self.sceneTree.iterateMode = iterateMode
		self.signalPanel.iterateMode = iterateMode
		self.sceneTree:setStartNode((tabInfo and tabInfo.node) or nil)
		self.inspector:onNodeFocusChanged(nil)
		self:updateButtonTexture()
		self:populateToolbar()
	end)
	self.gameTabContainer = gameTabContainer

	--======== PANELS
	local leftPanel = TabContainer()
		:setAnchorsAndOffsets(
				0, 0, 0, 1,
				0, 36, 256, 0
		)
		:setVariant("panel")
	self.leftPanel = leftPanel

	local rightPanel = TabContainer()
		:setAnchorsAndOffsets(
				1, 0, 1, 1,
				-256, 36, 0, 0
		)
		:setVariant("panel")
	self.rightPanel = rightPanel

	local bottomPanel = TabContainer()
		:setAnchorsAndOffsets(
			0, 1, 1, 1,
			260, -236, -260, 0
		)
		:setVariant("panel")
	self.bottomPanel = bottomPanel

	--======== ORIGINAL ROOT
	---@type Toolbox.GameScene? # Where the game is rendered to
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
			0, 0, 0, 0,
			4, 4, 4, 32
		)
		:setMargin(8)
		:setPadding(8)
		:setVariant("topbar")
		:setResizeToContent(true)

	for i = 1, #menuActions do
		local action = menuActions[i]
		local button = MenuButton(action[1], nil, action[2])
			:setAnchors(
				0, 0, 0, 1
			)

		button:getPopupMenu().itemSelected:connectCallable(function(_, itemIndex, item)
			local f = item.func
			if f then f(self) end
		end)

		menuBar:addChild(button)
	end

	--======== TOOL BAR (middle of screen)
	local toolBar = HBox()
		:setAnchorsAndOffsets(
			0.5, 0, 0.5, 0,
			0, 4, 0, 32
		)
		:setMargin(8)
		:setPadding(8)
		:setResizeToContent(true)
		:setVariant("topbar")
		:setGrowDirection(nil, 0.5)
	self.toolbar = toolBar

	--======== GAME BAR
	local gameActionBar = HBox()
		:setAnchorsAndOffsets(
			1, 0, 1, 0,
			-4, 4, -4, 32
		)
		:setMargin(4)
		:setVariant("topbar")
		:setResizeToContent(true)
		:setGrowDirection(0, 1)

	for i = 1, #gameActions do
		local action = gameActions[i]
		local button = TextureButton(action[1])
			:setAnchorsAndOffsets(
				0, 0, 0, 1,
				0, 0, 32, 0
			)
		button.clicked:connect(ToolboxActions, action[2])
		gameActionBar:addChild(button)
	end

	---@type TextureButton
	self.pauseButton = gameActionBar.children[2]

	--======== SCENE TREE
	local sceneTreeContainer
	do
		---@type Toolbox.SceneTree
		local sceneTree = SceneTreeViewer(toolbox, subWindow)
			:setAnchorsAndOffsets(
				0, 0, 1, 1,
				0, 30, 0, 0
			)
		self.sceneTree = sceneTree

		sceneTreeContainer = Control()
			:setAnchors(0, 0, 1, 1)
		sceneTreeContainer.name = "Scene"
		self.sceneTreeContainer = sceneTreeContainer

		local treeActionBar = HBox()
			:setAnchorsAndOffsets(
				0, 0, 1, 0,
				0, 0, 0, 30
			)
			:setSortMode("center")
			:setMargin(8)

		do
			-- Create the buttons for the scene tree
			local treeActions = {
				"Add", "popupAddNode",
				"Link", "popupLinkScene",
				"Extend", "popupExtendNode",
			}
			for i = 1, 5, 2 do
				local button = Button(treeActions[i])
					:setAnchors(0, 0, 0, 1)
					:setVariant("flat")
				button.clicked:connect(ToolboxPopups, treeActions[i + 1])
				treeActionBar:addChild(button)
			end
		end

		-- Context menu for right-clicking a popup
		---@type PopupMenu.Item[]
		local nodeActions = {
			{label = "Add Node...", func = function()
				ToolboxPopups.popupAddNode()
			end},
			{label = "Link Scene...", func = function()
				ToolboxPopups.popupLinkScene()
			end},
			{separator = true},
			{label = "Cut", func = function()
				ToolboxActions.deleteSelectedNode()
			end},
			{label = "Copy", func = function()
			end},
			{label = "Duplicate", func = function()
				ToolboxActions.duplicateSelectedNode()
			end},
			{separator = true},
			{label = "Extend...", func = function()
				ToolboxPopups.popupExtendNode()
			end},
			{label = "Change Type...", func = function()
				ToolboxPopups.popupChangeType()
			end},
			{separator = true},
			{label = "Move Up", func = function()
			end},
			{label = "Move Down", func = function()
			end},
			{label = "Make Scene Root", func = function()
			end},
			{label = "Delete", func = function()
				ToolboxActions.deleteSelectedNode()
			end},
		}

		-- Call the function contained in the menu
		local nodeContextMenu = PopupMenu(nodeActions)
		nodeContextMenu._resizeWithParent = false
		nodeContextMenu.itemSelected:connectCallable(function(_, _, item)
			local f = item.func
			if f then f() end
		end)

		-- Open the menu when right-clicking something
		---@param pressedNode Node
		---@param button integer
		sceneTree.nodePressed:connectCallable(function(_, pressedNode, button)
			if button == 2 then
				nodeContextMenu:setWorldPosition(love.mouse.getPosition())
				self.sceneTree:focusNode(pressedNode)
				nodeContextMenu:popup()
			end
		end)

		-- Build the container
		sceneTreeContainer:addChild(sceneTree)
		sceneTreeContainer:addChild(treeActionBar)
		sceneTreeContainer:addChild(nodeContextMenu)
	end

	--======== INSPECTOR
	---@type Toolbox.Inspector
	local inspector = Inspector(toolbox, self.sceneTree)
		:setAnchors(0, 0, 1, 1)
	self.inspector = inspector

	--======== SIGNAL PANEL
	---@type Toolbox.SignalPanel
	local signalPanel = SignalPanel(toolbox, self.sceneTree)
		:setAnchors(0, 0, 1, 1)
	self.signalPanel = signalPanel

	--======== FILE BROWSER
	---@type Toolbox.FileBrowser
	local fileBrowser = FileBrowser(toolbox)
		:setAnchors(0, 0, 1, 1)
	self.fileBrowser = fileBrowser

	--======== SCENE STRUCTURE
	leftPanel:addChild(sceneTreeContainer)
	rightPanel:addChild(inspector)
	rightPanel:addChild(signalPanel)
	bottomPanel:addChild(fileBrowser)

	editor:addChild(leftPanel)
	editor:addChild(rightPanel)
	editor:addChild(bottomPanel)
	editor:addChild(gameActionBar)
	editor:addChild(menuBar)
	editor:addChild(toolBar)
	editor:addChild(gameTabContainer)
	editor:hide()

	self:addChild(editor)
	self:addChild(subWindow)
end

---Returns the subroot container
---@return Toolbox.EditableScene?
function MainWindow:getSubrootContainer()
	if self._fullView then return self._currentTab end
	local selectedTab = self.gameTabContainer:getActiveTab()
	if selectedTab and selectedTab:is(EditableScene) then
		---@cast selectedTab Toolbox.EditableScene
		return selectedTab
	end
	return nil
end

---Returns the actions this MainWindow can do
---@return Toolbox.Actions
function MainWindow:getActions()
	return ToolboxActions
end

---Returns the popups relevant to this MainWindow
---@return Toolbox.Popups
function MainWindow:getPopups()
	return ToolboxPopups
end

---Changes the pause button texture
function MainWindow:updateButtonTexture()
	local srContainer = self:getSubrootContainer()
	self.pauseButton:setTexture((srContainer and srContainer._running) and Assets.Pause or Assets.Play)
end

function MainWindow:populateToolbar()
	local srContainer = self:getSubrootContainer()
	if not srContainer then return end
	local toolActions = srContainer:getTools()
	local toolbar = self.toolbar
	toolbar:clearChildren()
	local toolCount = #toolActions
	toolbar:setVisible(toolCount > 0)
	for i = 1, toolCount do
		local action = toolActions[i]
		local button = Button(action.label, action.icon)
			:setAnchors(
				0, 0, 0, 1
			)
			:setVariant("flat")
		button.clicked:connect(srContainer, "_onSelectToolPressed", false, false)

		toolbar:addChild(button)
	end
end

return MainWindow
