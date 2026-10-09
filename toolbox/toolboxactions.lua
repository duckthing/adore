local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.-)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local Common = Adore.Common
local Resources = Adore.Resources

local ObjectSaver = Common("ObjectSaver")
local ObjectLoader = Adore.Loader.getCollection("ObjectLoader")
local TableScene = Resources("TableScene")
local tclear = Common("Structures").tableClear

local Node = Nodes("Node")
local LuaPath = Adore.Libraries("LuaPath")

---@type Toolbox.EditableScene
local EditableScene = require(ADORE_PATH..".toolbox.editablescene")
---@type Toolbox.GameScene
local GameScene = require(ADORE_PATH..".toolbox.gamescene")

---@class Toolbox.Actions
local ToolboxActions = {}

---@type Toolbox.MainWindow
local mw
---Sets the MainWindow so that actions know what to operate on
---@param mainWindow Toolbox.MainWindow
function ToolboxActions.setMainWindow(mainWindow)
	mw = mainWindow
end

---@type Toolbox.Popups
local ToolboxPopups
---Sets the MainWindow so that popups know where to put their popups
---@param popups Toolbox.Popups
function ToolboxActions.setPopups(popups)
	ToolboxPopups = popups
end

---Toggles the pause mode of the current tab
function ToolboxActions.togglePause()
	local srContainer = mw:getSubrootContainer()
	if srContainer then
		if srContainer:is(GameScene) then
			srContainer._running = not srContainer._running
			srContainer._errorMessage = nil
			mw:updateButtonTexture()
		else
			-- Run the scene
			local gScene
			if not srContainer._fromScript then
				-- Only save if this EditableScene wasn't from a script
				local path, format = srContainer._lastFilepath, srContainer._lastFormat
				if not (path and format) then return ToolboxPopups.popupSaveSceneAs() end
				ToolboxActions.saveScene()

				gScene = GameScene()
				gScene:createSubroot()

				-- Load from file
				local scene, err = ObjectSaver.loadFromFilePath(path, format, "SceneFactory", true)
				if scene then
					gScene:changeSceneTo(scene)
				else
					print(err)
					return
				end
			else
				-- Load from script
				gScene = GameScene()
				gScene:createSubroot()
				local path = srContainer._lastFilepath
				if not path then return ToolboxPopups.popupSaveSceneAs() end
				local requirePath = path:match("(.*)%.lua"):gsub("/", ".")
				gScene:changeSceneTo(requirePath)
				gScene.name = ("Game (%s)"):format(LuaPath:file_name(path))
			end

			-- Insert this tab
			gScene.name = ("Game (%s)"):format(LuaPath:file_name(srContainer._lastFilepath))
			local tabContainer = mw.gameTabContainer
			local index = (tabContainer:getIndexOfChild(mw:getSubrootContainer()) or #tabContainer.children) + 1
			tabContainer:insertChild(gScene, index)
			tabContainer:selectTab(gScene)
		end
	end
end

---Toggles fullscreen of the current tab
function ToolboxActions.toggleFull()
	if not mw._fullView then
		-- We are going to fullscreen
		-- Remove the current tab from the TabContainer, and make it fullscreen on the main window
		local tab = mw.gameTabContainer:getActiveTab()
		if tab then
			mw._fullView = true
			mw._tabIndex = mw.gameTabContainer:getIndexOfChild(tab)

			mw:addChild(tab)
			tab:setVisible(true)
			mw._currentTab = tab

			mw.editor:setVisible(false)
		end
	else
		-- We are exiting fullscreen
		-- Re-insert it into the TabContainer
		local tab = mw._currentTab
		if tab then
			mw._fullView = false
			mw.gameTabContainer:insertChild(tab, mw._tabIndex)
			mw.gameTabContainer:selectTab(tab)

			mw.editor:setVisible(true)
		end
	end
end

---Reloads the scene of the current tab
function ToolboxActions.reloadScene()
	local srContainer = mw:getSubrootContainer()
	if not srContainer then return end
	if srContainer:is(GameScene) then
		srContainer._running = true
		srContainer:handleOnSubroot("reloadCurrentScene")
	end
end

---Creates an empty EditableScene and selects it
function ToolboxActions.newScene()
	local tabContainer = mw.gameTabContainer
	local eScene = EditableScene()
	eScene:createSubroot()
	eScene.name = "(Empty)"

	local index = (tabContainer:getIndexOfChild(mw:getSubrootContainer()) or #tabContainer.children) + 1

	tabContainer:insertChild(eScene, index)
	tabContainer:selectTab(eScene)
end

---Closes the current tab
function ToolboxActions.closeScene()
	local srContainer = mw:getSubrootContainer()
	if not srContainer then return end
	local index = mw.gameTabContainer:getIndexOfChild(srContainer)
	if index then
		mw.gameTabContainer:removeChildAtIndex(index)
	end
end

---Saves the scene of the current tab, if it has its filepath set
---@return boolean success
function ToolboxActions.saveScene()
	local srContainer = mw:getSubrootContainer()
	if not srContainer then return false end
	local sceneRoot = srContainer:getSceneRoot()
	if not sceneRoot then return false end
	local savePath = srContainer._lastFilepath
	local format = srContainer._lastFormat
	if not savePath or not format then return ToolboxPopups.popupSaveSceneAs() or false end

	-- Create the directories, and error early if we can't open that file
	local NativeFS = Adore.Libraries("NativeFS")
	NativeFS.createDirectory(LuaPath:dir_name(savePath))
	local file = NativeFS.newFile(savePath)
	if not (file:isOpen() or file:open("w") or file:getMode() == "w") then
		print("Can't open file at", savePath)
		return false
	end

	-- Pack the scene object
	---@type SceneFactory
	local scene
	if format == "binary" then
		local PackedScene = Resources("PackedScene")
		scene = PackedScene()
	else
		scene = TableScene()
	end
	scene:pack(sceneRoot)
	scene.source = savePath

	-- Write to the file
	local success, err = ObjectSaver.saveToFile(file, scene, format)
	if success then
		print("Written to path:", savePath)
		-- Remove it from ObjectLoader so that it gets reloaded
		if ObjectLoader:has(savePath) then
			ObjectLoader:destructor((ObjectLoader:get(savePath)), scene)
		end
		ObjectLoader:register(scene, savePath)
		ToolboxActions.prepareReloadDependency(savePath)
		ObjectLoader:updateModifiedSceneProperties(sceneRoot, savePath)
		ToolboxActions.performReloadDependency(savePath)
	else
		-- Errored
		print(err)
	end

	return success
end

---Creates the subroot and instances the EditableScene
---@param scene SceneFactory
---@param path string
function ToolboxActions.loadSceneFromFactory(scene, path)
	-- Create the scene and add the tab
	local eScene = EditableScene()
	eScene:createSubroot()
	eScene:changeSceneTo(scene)
	eScene._lastFilepath = path

	local extension = LuaPath:extension_name(path)
	local format = extension
	if not (extension == "json" or extension == "lua") then
		format = "binary"
	end
	eScene._lastFormat = format

	local fileName = LuaPath:file_name(path)
	eScene.name = fileName

	mw.gameTabContainer:addChild(eScene)
	mw.gameTabContainer:selectTab(eScene)
end

function ToolboxActions.deleteSelectedNode()
	local srContainer = mw:getSubrootContainer()
	if not srContainer then return end
	local selectedNode = mw.sceneTree:getPressedNode()
	if not (selectedNode and selectedNode:is(Node)) then return end

	srContainer:handleInsideSubroot(selectedNode.unparent, selectedNode)

	local sceneTree = mw.sceneTree
	sceneTree:focusNode()
	sceneTree:updateNodes()
end

do
---@param node Node
---@param owner Node
local setOwner = function(node, owner) node._owner = owner end
---@param node Node
---@param owner Node
local ignoreSubScenes = function(node, owner)
	if node._sceneFilePath ~= nil then
		node._owner = owner
		return false
	end
	return true
end

function ToolboxActions.duplicateSelectedNode()
	local srContainer = mw:getSubrootContainer()
	if not srContainer then return end
	local selectedNode = mw.sceneTree:getPressedNode()
	if not (selectedNode and selectedNode:is(Node)) then return end
	local sceneRoot = srContainer:getSceneRoot()
	if not (sceneRoot and sceneRoot ~= selectedNode) then return end

	local parent = selectedNode.parent
	if parent then
		srContainer:pushSubroot()
		local index = parent:getIndexOfChild(selectedNode)
		local clone = selectedNode:duplicate()

		clone._owner = sceneRoot
		clone:traverseDownSelf(setOwner, ignoreSubScenes, sceneRoot)

		parent:insertChild(clone, index + 1)
		srContainer:popSubroot()

		local sceneTree = mw.sceneTree
		sceneTree:updateNodes()
		sceneTree:focusNode(clone)
	end
end
end

---Links a scene under a Node, with an optional index
---@param scene SceneFactory
---@param instanceUnder Node
---@param index integer?
function ToolboxActions.linkScene(scene, instanceUnder, index)
	local srContainer = mw:getSubrootContainer()
	if not srContainer then return end
	local sceneRoot = srContainer:getSceneRoot()
	if not sceneRoot then return end

	local shouldPush = not srContainer:isPushed()
	if shouldPush then
		srContainer:pushSubroot()
	end

	local instanced = scene:instantiate(instanceUnder)
	if instanced then
		instanced._owner = sceneRoot
		if index then
			instanceUnder:insertChild(instanced, index)
		end
	end

	mw.sceneTree:updateNodes()
	if instanced then
		mw.sceneTree:focusNode(instanced)
	end

	if shouldPush then
		srContainer:popSubroot()
	end
end

---Changes the type of `node` to `class` while keeping relevant properties
---@param node Node
---@param class string | Node
function ToolboxActions.changeTypeOfNode(node, class)
	if type(class) == "string" then class = Adore.Any(class) end
	if not class:is(Node) then
		print(("Class '%s' is not a Node"):format(tostring(class)))
		return
	end
	local parent = node.parent
	if not parent then
		print(("Node '%s' does not have a parent"):format(tostring(node)))
		return
	end
	local childIndex = parent:getIndexOfChild(node)

	local resources = {}
	local header, body = ObjectSaver.getPropertyPairs(node, resources, false)
	node:forceDestroy()
	setmetatable(node, class)
	class.new(node)
	local deferredProperties = ObjectSaver.setPropertiesFromPairs(node, header, body)
	ObjectSaver.setDeferredProperties(node, deferredProperties, resources)
	parent:insertChild(node, childIndex)
end

do
---The packed contents of each tab that will get reloaded
---@type {[Toolbox.EditableScene]: TableScene}
local tabToPackedContents = {}

---Called before default scene properties are updated.
---Here, existing scenes are packed for use after the properties are updated.
---@param dependencyPath string
function ToolboxActions.prepareReloadDependency(dependencyPath)
	tclear(tabToPackedContents)
	local tabbar = mw.gameTabContainer._internalTabBar
	local tabs = tabbar._tabs

	for i = 1, #tabs do
		-- For each tab, pack it if it's a good idea
		local tab = tabs[i]
		---@type Toolbox.EditableScene
		local eScene = tab.node
		local sceneRoot = eScene:getSceneRoot()
		local path = eScene._lastFilepath
		if eScene.CLASS_NAME == "EditableScene" and path and sceneRoot then
			-- Only look at EditableScenes from a filepath with something underneath them
			---@type SceneFactory
			local asset = ObjectLoader:has(path)
			if asset then
				if asset._dependencyMap[dependencyPath] then
					-- This opened scene relies on the dependency we're reloading
					-- Pack it and clear it
					local packed = TableScene()
					packed:pack(eScene:getSceneRoot())
					tabToPackedContents[eScene] = packed
				end
			end
		end
	end
end

---Called after scene properties are updated.
---Re-instances each packed scene with the new default properties.
---@param dependencyPath string
function ToolboxActions.performReloadDependency(dependencyPath)
	for eScene, packed in pairs(tabToPackedContents) do
		eScene:pushSubroot()
		print("Reloading", eScene)
		eScene:changeSceneTo(packed)
		tabToPackedContents[eScene] = nil
		eScene:popSubroot()
	end
end
end

return ToolboxActions
