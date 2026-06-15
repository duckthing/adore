local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes

local SceneTreeViewer = require(ADORE_PATH..".toolbox.ui.scenetree")
local Inspector = require(ADORE_PATH..".toolbox.ui.inspector")

---@class Toolbox.MainWindow: Control
---@overload fun(toolbox: Toolbox): Toolbox.MainWindow
local MainWindow = Nodes("Control"):extend()
MainWindow.CLASS_NAME = "MainWindow"

local gameActions = {
	{
		"Reload",
		"reloadLevel",
	},
	{
		"Pause",
		"togglePause",
	},
}

local menuActions = {
	{
		"Save",
		"saveScene",
	},
	{
		"Load",
		"loadScene",
	},
}

---@param toolbox Toolbox
function MainWindow:new(toolbox)
	MainWindow.super.new(self)
	self:setAnchors(0, 0, 1, 1)

	self.toolbox = toolbox
	local subRoot = toolbox.subRoot

	---@type boolean # Whether the game window takes up the whole window
	self._fullView = true

	---@type ViewportContainer # Where the game is rendered to
	local subWindow
	local tabContainer = Nodes("TabContainer")()
	tabContainer:setAnchorsAndOffsets(
			0.5, 0, 0.5, 0,
			-220, 40, 220, 300 + 26
	)
	tabContainer._internalTabBar.tabSelected:connectCallable(function(_, index, tabInfo)
		if toolbox.subrootContext then
			toolbox.subrootContext._visible = tabInfo.node == subWindow
		end
	end)

	self.tabContainer = tabContainer

	local label = Nodes("Label")("Test Tab")
	label:setOffsets(0, 0, 100, 100)
	self.tabContainer:addChild(label)

	subWindow = Nodes("ViewportContainer")(subRoot._viewport)
	subWindow.name = "[ Game ]"

	subWindow:setAnchors(0, 0, 1, 1)
	subWindow.paused = true
	self.subWindow = subWindow

	subWindow.resizeViewport = function(_, w, h)
		if subRoot then
			local viewport = subWindow._subViewport
			if viewport then
				toolbox:pushSubroot()

				subRoot:resize(w, h)
				subRoot:drawToViewport()

				toolbox:popSubroot()
			end
		end
	end

	local editor = Nodes("Control")()
	editor:setAnchors(0, 0, 1, 1)
	self.editor = editor

	local gameActionBar = Nodes("HBox")()
	gameActionBar:setAnchorsAndOffsets(
		1, 0, 1, 0,
		-176, 0, -4, 32
	)
	-- gameActionBar:setSortMode("center")
	gameActionBar:setMargin(4)
	gameActionBar:setPadding(4)

	for i = 1, #gameActions do
		local action = gameActions[i]
		local button = Nodes("Button")(action[1])
		button:setAnchorsAndOffsets(
			0, 0, 0, 1,
			0, -2, 80, -4
		)
		button.clicked:connect(self, action[2])
		gameActionBar:addChild(button)
	end

	local menuBar = Nodes("HBox")()
	menuBar:setAnchorsAndOffsets(
		0, 0, 1, 0,
		4, 0, -180, 32
	)
	menuBar:setMargin(4)
	menuBar:setPadding(4)

	for i = 1, #menuActions do
		local action = menuActions[i]
		local button = Nodes("Button")(action[1])
		button:setAnchorsAndOffsets(
			0, 0, 0, 1,
			0, -2, 80, -4
		)
		button.clicked:connect(self, action[2])
		menuBar:addChild(button)
	end

	local sceneTree = SceneTreeViewer(toolbox)
	self.sceneTree = sceneTree
	sceneTree:setAnchorsAndOffsets(
		0, 0, 0, 1,
		0, 40, 252, 0
	)

	local inspector = Inspector(toolbox, sceneTree)
	self.inspector = inspector
	inspector:setAnchorsAndOffsets(
		1, 0, 1, 1,
		-252, 40, 0, 0
	)

	editor:addChild(sceneTree)
	editor:addChild(inspector)
	editor:addChild(gameActionBar)
	editor:addChild(menuBar)
	editor:addChild(tabContainer)
	editor:hide()

	self:addChild(editor)
	self:addChild(subWindow)
end

function MainWindow:togglePause()
	local toolbox = self.toolbox
	local c = toolbox.subrootContext
	c.running = not c.running
end

function MainWindow:reloadLevel()
	local toolbox = self.toolbox
	local subRoot = toolbox.subRoot
	local c = toolbox.subrootContext
	c.running = true

	toolbox:pushSubroot()
	subRoot:reloadCurrentScene()
	toolbox:popSubroot()
end

function MainWindow:onSubrootPushed()
	self.sceneTree:onSubrootPushed()
end

function MainWindow:onSubrootPopped()
	self.sceneTree:onSubrootPopped()
end

function MainWindow:toggleFull()
	local full = not self._fullView
	self._fullView = full
	local subWindow = self.subWindow

	self.editor:setVisible(not full)
	if full then
		self:addChild(subWindow)
		subWindow:setVisible(true)
		self.toolbox.subrootContext._visible = true
		-- subWindow:setAnchorsAndOffsets(
		-- 	0, 0, 1, 1,
		-- 	0, 0, 0, 0
		-- )
	else
		self.tabContainer:insertChild(subWindow, 1)
		self.tabContainer:selectTab(subWindow)
		-- subWindow:setAnchorsAndOffsets(
		-- 	0.5, 0, 0.5, 0,
		-- 	-220, 40 + 26, 220, 300
		-- )
	end
end

return MainWindow
