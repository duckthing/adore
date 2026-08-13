local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local ObjectSaver = Adore.Common("ObjectSaver")

local Node = Nodes("Node")
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
local MenuButton = Nodes("MenuButton")
local DropdownButton = Nodes("DropdownButton")
local FormBuilder = Adore.Common("FormBuilder")

local SceneTreeViewer = require(ADORE_PATH..".toolbox.ui.scenetree")
local Inspector = require(ADORE_PATH..".toolbox.ui.inspector")
local FileBrowser = require(ADORE_PATH..".toolbox.ui.filebrowser")
local Assets = require(ADORE_PATH..".toolbox.assets")
---@type Toolbox.EditableScene
local EditableScene = require(ADORE_PATH..".toolbox.editablescene")
---@type Toolbox.GameScene
local GameScene = require(ADORE_PATH..".toolbox.gamescene")
local Templates = require(ADORE_PATH..".toolbox.scripttemplates")

---@class Toolbox.MainWindow: Control
---@overload fun(toolbox: Toolbox): Toolbox.MainWindow
local MainWindow = Control:extend()
MainWindow.CLASS_NAME = "MainWindow"

local FORMAT_OPTIONS = {{label = "json"}, {label = "lua"}, {label = "binary"}}
local SCRIPT_OPTIONS = {{label = "Normal", template = "normal"}, {label = "No comments", template = "noComments"}}

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
				window:newScene()
			end},
			{label = "Save Scene", func = function(window)
				---@cast window Toolbox.MainWindow
				window:saveScene()
			end},
			{label = "Save As...", func = function(window)
				---@cast window Toolbox.MainWindow
				window:saveSceneAs()
			end},
			{label = "Load Scene", func = function(window)
				---@cast window Toolbox.MainWindow
				window:loadScene()
			end},
			{label = "Reload Scene", func = function(window)
				---@cast window Toolbox.MainWindow
				window:reloadScene()
			end},
			{label = "Close Scene", func = function(window)
				---@cast window Toolbox.MainWindow
				window:closeScene()
			end},
		}
	},
	{
		"Project",
		{}
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
		}
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
		self.sceneTree:setStartNode((tabInfo and tabInfo.node) or nil)
		self.inspector:onNodeSelectionChanged(nil)
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
			0, 0, 0, 0,
			4, 4, 8, 32
		)
		:setMargin(20)
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

		local treeActionBar = HBox()
			:setAnchorsAndOffsets(
				0, 0, 1, 0,
				(label:getMinimumSize()), 0, 0, 30
			)
			:setSortMode("end")

		local addNodeButton = Button("Add")
			:setAnchorsAndOffsets(
				0, 0, 0, 1,
				0, 0, 50, 0
			)
			:setVariant("flat")
		addNodeButton.clicked:connect(self, "addNode")

		local extendNodeButton = Button("Extend")
		extendNodeButton:setAnchorsAndOffsets(
				0, 0, 0, 1,
				0, 0, 50, 0
			)
			:setVariant("flat")
		extendNodeButton.clicked:connect(self, "extendNode")

		treeActionBar:addChild(addNodeButton)
		treeActionBar:addChild(extendNodeButton)

		sceneTreeContainer:addChild(sceneTree)
		sceneTreeContainer:addChild(label)
		sceneTreeContainer:addChild(treeActionBar)
	end

	--======== INSPECTOR
	---@type Toolbox.Inspector
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
			265, -231, -265, 0
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
		if srContainer:is(GameScene) then
			srContainer._running = not srContainer._running
			srContainer._errorMessage = nil
			self:updateButtonTexture()
		else
			local path, format = srContainer._lastFilepath, srContainer._lastFormat
			if not (path and format) then return self:saveSceneAs() end
			self:saveScene()

			local gScene = GameScene()
			gScene:createSubroot()

			local scene, err = ObjectSaver.loadFromFilePath(path, format, "SceneFactory", true)

			if scene then
				gScene:changeSceneTo(scene)
				gScene.name = ("Game (%s)"):format(path:match(".*[/\\](.*)$"))
				self.tabContainer:addChild(gScene)
				self.tabContainer:selectTab(self.tabContainer:getIndexOfChild(gScene))
			else
				print(err)
			end
		end
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
	if srContainer:is(GameScene) then
		srContainer._running = true
		srContainer:handleOnSubroot("reloadCurrentScene")
	end
end

---Creates an empty EditableScene and selects it
function MainWindow:newScene()
	local tabContainer = self.tabContainer
	local eScene = EditableScene()
	eScene:createSubroot()
	eScene.name = "(Empty)"

	local index = (tabContainer:getIndexOfChild(self:getSubrootContainer()) or #tabContainer.children) + 1

	tabContainer:insertChild(eScene, index)
	tabContainer:selectTab(eScene)
end

---Closes the current tab
function MainWindow:closeScene()
	local srContainer = self:getSubrootContainer()
	if not srContainer then return end
	local index = self.tabContainer:getIndexOfChild(srContainer)
	if index then
		self.tabContainer:removeChildAtIndex(index)
		if index > 1 then
			self.tabContainer:selectTab(index - 1)
		end
	end
end

---Saves the scene of the current tab, if it has its filepath set
---@return boolean success
function MainWindow:saveScene()
	local srContainer = self:getSubrootContainer()
	if not srContainer then return false end
	local child = srContainer.subroot.children[1]
	if not child then return false end
	local savePath = srContainer._lastFilepath
	local format = srContainer._lastFormat
	if not savePath or not format then return self:saveSceneAs() or false end

	-- Create the directories, and error early if we can't open that file
	local NativeFS = Adore.Libraries("NativeFS")
	NativeFS.createDirectory(savePath:match("(.*)[/\\].*$"))
	local file = NativeFS.newFile(savePath)
	if not (file:isOpen() or file:open("w") or file:getMode() == "w") then
		print("Can't open file")
		return false
	end

	-- Pack the scene object
	---@type SceneFactory
	local scene
	if format == "binary" then
		local PackedScene = Adore.Resources("PackedScene")
		scene = PackedScene()
	else
		local TableScene = Adore.Resources("TableScene")
		scene = TableScene()
	end
	scene:pack(child)

	-- Write to the file
	local success, err = ObjectSaver.saveToFile(file, scene, format)
	if success then
		print("Written to path:", savePath)
	else
		-- Errored
		print(err)
	end

	return success
end

function MainWindow:saveSceneAs()
	local srContainer = self:getSubrootContainer()
	if not srContainer then return end
	local child = srContainer.subroot.children[1]
	if not child then return end

	-- Create the popup
	local window = WindowPopup()
	window:setAnchorsAndOffsets(
		0.5, 0.5, 0.5, 0.5,
		-90, -76, 90, 76
	)

	window:getTitleLabel():setText("Save to...")

	---@type Form
	local form = {
		{type = "body", text = "File Path"},
		{id = "path", type = "textfield",
				value = srContainer._lastFilepath
			or ("scenes/%s.json"):format(tostring(child):lower())},
		{type = "body", text = "File Path"},
		{id = "format", type = "dropdown", items = FORMAT_OPTIONS,
				value = srContainer and srContainer._lastFormat == "binary" and 2 or 1},
	}

	local vbox, sheet = FormBuilder.build(form)
	---@cast vbox VBox

	vbox:setAnchorsAndOffsets(
			0, 0, 1, 1,
			10, 10, -10, 0
		)
		:setResizeToContent(true)
		:setMargin(4)

	local pathField = sheet:getElement("path")
	---@cast pathField LineEdit
	pathField
		:setUnfocusedPosition("right")
		:setSubmitOnFocusLost(false)
	pathField.textSubmitted:connect(window, "submit", false, false)

	-- Add those fields
	window:addChild(vbox)

	-- Connect events
	window:addAction("Cancel", "close")
	window:addAction("Save", "submit")
	window.submit = function(...)
		srContainer._lastFilepath = pathField._submittedText
		local item = sheet:getValue("format")
		---@cast item PopupMenu.Item
		srContainer._lastFormat = item.label
		if self:saveScene() then window:close() end
	end

	-- Show the popup
	self:addChild(window)
	window:popup()
	pathField:grabFocus(false)
end

---Loads the scene and opens it
function MainWindow:loadScene()
	local srContainer = self:getSubrootContainer()

	-- Create the popup
	local window = WindowPopup()
	window:setAnchorsAndOffsets(
		0.5, 0.5, 0.5, 0.5,
		-90, -76, 90, 76
	)

	window:getTitleLabel():setText("Load scene...")

	---@type Form
	local form = {
		{type = "body", text = "File Path"},
		{id = "path", type = "textfield",
				value = srContainer and srContainer._lastFilepath or "scenes/myscene.json"},
		{type = "body", text = "File Path"},
		{id = "format", type = "dropdown", items = FORMAT_OPTIONS,
				value = srContainer and srContainer._lastFormat == "binary" and 2 or 1},
	}

	local vbox, sheet = FormBuilder.build(form)
	---@cast vbox VBox
	vbox:setOffsets(10, 10, -10, 0)
		:setResizeToContent(true)
		:setMargin(4)

	local pathField = sheet:getElement("path")
	---@cast pathField LineEdit
	pathField
		:setUnfocusedPosition("right")
		:setSubmitOnFocusLost(false)
		.textSubmitted:connect(window, "submit", false, false)
	window:addChild(vbox)

	-- Connect events
	window:addAction("Cancel", "close")
	window:addAction("Load", "submit")
	window.submit = function(...)
		local path = pathField._submittedText
		local format = sheet:getValue("format").label

		local scene, err = ObjectSaver.loadFromFilePath(path, format, "SceneFactory", true)
		if scene then
			-- Create the scene and add the tab
			local eScene = EditableScene()
			eScene:createSubroot()
			eScene:changeSceneTo(scene)
			eScene._lastFilepath = path
			eScene._lastFormat = format

			local fileName = path:match(".*[/\\](.*)$")
			eScene.name = fileName

			self.tabContainer:addChild(eScene)
			self.tabContainer:selectTab(eScene)
			window:close()
		else
			print(err)
		end
	end

	-- Show the popup
	self:addChild(window)
	window:popup()
	sheet:getElement("path"):grabFocus(false)
end

function MainWindow:addNode()
	local srContainer = self:getSubrootContainer()
	if not srContainer then return end
	local instanceUnder = self.sceneTree:getSelectedNode() or srContainer.subroot._instancedScene
	if not (instanceUnder and instanceUnder._valid) then
		instanceUnder = srContainer.subroot
	end

	-- Create the popup
	local window = WindowPopup()
	window:setAnchorsAndOffsets(
		0.5, 0.5, 0.5, 0.5,
		-90, -56, 90, 56
	)

	window:getTitleLabel():setText("Add node...")

	---@type Form
	local form = {
		{type = "body", text = "Class Name"},
		{id = "class", type = "textfield",
				value = (instanceUnder ~= srContainer.subroot and instanceUnder.CLASS_NAME) or "Node"},
	}

	local vbox, sheet = FormBuilder.build(form)
	---@cast vbox VBox
	vbox:setAnchorsAndOffsets(
			0, 0, 1, 1,
			10, 10, -10, 0
		)
		:setResizeToContent(true)
		:setMargin(4)

	local classField = sheet:getElement("class")
	---@cast classField LineEdit
	classField:setUnfocusedPosition("right")
		:setSubmitOnFocusLost(false)
	classField.textSubmitted:connect(window, "submit", false, false)
	window:addChild(vbox)

	-- Connect events
	window:addAction("Cancel", "close")
	window:addAction("Add", "submit")
	window.submit = function(...)
		local className = classField._submittedText

		local success, ClassOrErr = pcall(Adore.Any, className)
		if success then
			if ClassOrErr:is(Node) or ClassOrErr == Node then
				-- Create the scene and add the tab
				srContainer:pushSubroot()

				local newNode = ClassOrErr()
				instanceUnder:addChild(newNode)

				srContainer:popSubroot()
				self.sceneTree:updateNodes()
				self.sceneTree:selectNode(newNode)
				window:close()
			else
				print(("Class '%s' is not a Node"):format(className))
			end
		else
			print(ClassOrErr)
		end
	end

	-- Show the popup
	self:addChild(window)
	window:popup()
	classField:grabFocus(false)
end

function MainWindow:extendNode()
	local srContainer = self:getSubrootContainer()
	if not srContainer then return end
	local selectedNode = self.sceneTree:getSelectedNode()
	if not (selectedNode and selectedNode:is(Node)) then return end

	-- Create the popup
	local window = WindowPopup()
	window:setAnchorsAndOffsets(
		0.5, 0.5, 0.5, 0.5,
		-90, -121, 90, 121
	)

	window:getTitleLabel():setText("Extend node...")

	local defaultNewClassName = "New"..((selectedNode ~= srContainer.subroot and selectedNode.CLASS_NAME) or "Node")

	---@type Form
	local form = {
		{type = "body", text = "Base Class Name"},
		{id = "baseClass", type = "textfield", value = selectedNode.CLASS_NAME},
		{type = "body", text = "New Class Name"},
		{id = "newClass", type = "textfield", value = defaultNewClassName},
		{type = "body", text = "Template"},
		{id = "template", type = "dropdown", items = SCRIPT_OPTIONS},
		{id = "newClassPath", type = "textfield", value =
			("src/nodes/%s.lua"):format(defaultNewClassName:lower())},
	}

	local vbox, sheet = FormBuilder.build(form)
	---@cast vbox VBox
	vbox:setOffsets(10, 10, -10, 0)
		:setResizeToContent(true)
		:setMargin(4)

	local baseClassField = sheet:getElement("baseClass")
	---@cast baseClassField LineEdit
	baseClassField:setUnfocusedPosition("right")

	local newClassField = sheet:getElement("newClass")
	---@cast newClassField LineEdit
	newClassField:setUnfocusedPosition("right")

	local pathField = sheet:getElement("newClassPath")
	---@cast pathField LineEdit
	pathField:setUnfocusedPosition("right")
		:setSubmitOnFocusLost(false)
	pathField.textSubmitted:connect(window, "submit", false, false)
	window:addChild(vbox)

	-- Connect events
	window:addAction("Cancel", "close")
	window:addAction("Extend", "submit")
	window.submit = function(...)
		local baseClassName = baseClassField._submittedText
		local newClassName = newClassField._submittedText
		local savePath = pathField._submittedText

		-- Check if the base class exists
		local success, baseClassOrErr = pcall(Adore.Any, baseClassName)
		if not success then print(baseClassOrErr) return end
		-- Check if the new class DOESN'T exist
		local err
		success, err = pcall(Adore.Any, newClassName)
		if success then print(("Class '%s' already exists"):format(newClassField)) return end

		-- Create the directories and open the file
		local NativeFS = Adore.Libraries("NativeFS")
		if NativeFS.getInfo(savePath) then
			print(("Location '%s' is not empty"):format(savePath))
			return
		end

		NativeFS.createDirectory(savePath:match("(.*)[/\\].*$"))
		local file = NativeFS.newFile(savePath)
		if not (file:isOpen() or file:open("w") or file:getMode() == "w") then
			print("Can't open file")
			return false
		end

		local dropdown = sheet:getElement("template")
		---@cast dropdown DropdownButton
		local dropdownOption = dropdown:getSelectedItem().template

		if baseClassOrErr:is(Adore.Nodes("Physical2d")) then
			-- Get a different template for Physical2d
			dropdownOption = dropdownOption.."Physical2d"
		end

		local template = Templates[dropdownOption]

		local symbols = {
			BASE = baseClassName,
			NEW = newClassName,
			ADOREPATH = Adore.PATH
		}
		local newSource = template:gsub("%$(%u*)", function(match)
			return symbols[match] or error(match)
		end)

		success, err = file:write(newSource)
		if not success then print(err) return end

		window:close()
	end

	-- Show the popup
	self:addChild(window)
	window:popup()
	newClassField:grabFocus(false)
end

function MainWindow:deleteSelectedNode()
	local srContainer = self:getSubrootContainer()
	if not srContainer then return end
	local selectedNode = self.sceneTree:getSelectedNode()
	if not (selectedNode and selectedNode:is(Node)) then return end

	srContainer:pushSubroot()
	selectedNode.parent:removeChild(selectedNode)
	srContainer:popSubroot()

	local sceneTree = self.sceneTree
	sceneTree:selectNode(nil)
	sceneTree:updateNodes()
end

return MainWindow
