local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.-)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local Common = Adore.Common
local Libraries = Adore.Libraries

local ObjectLoader = Adore.Loader.getCollection("ObjectLoader")

local Node = Nodes("Node")
local WindowPopup = Nodes("WindowPopup")
local FormBuilder = Common("FormBuilder")
local fzy = Libraries("fzy")
local LuaPath = Libraries("LuaPath")

local Templates = require(ADORE_PATH..".toolbox.scripttemplates")
local FORMAT_OPTIONS = {{label = "json"}, {label = "lua"}, {label = "binary"}}
local SCRIPT_OPTIONS = {{label = "Normal", template = "normal"}, {label = "No comments", template = "noComments"}}

---@class Toolbox.Popups
local ToolboxPopups = {}

---@type Toolbox.MainWindow
local mw
---Sets the MainWindow so that popups know where to put their popups
---@param mainWindow Toolbox.MainWindow
function ToolboxPopups.setMainWindow(mainWindow)
	mw = mainWindow
end

---@type Toolbox.Actions
local ToolboxActions
---Sets the MainWindow so that popups know where to put their popups
---@param actions Toolbox.Actions
function ToolboxPopups.setActions(actions)
	ToolboxActions = actions
end

---Shows the "save scene as" popup
function ToolboxPopups.popupSaveSceneAs()
	local srContainer = mw:getSubrootContainer()
	if not srContainer then return end
	local sceneRoot = srContainer:getSceneRoot()
	if not sceneRoot then return end

	-- Create the popup
	local window = WindowPopup()
	window:setAnchorsAndOffsets(
		0.5, 0.5, 0.5, 0.5,
		0, 0, 180, 152
	)

	window:getTitleLabel():setText("Save to...")

	---@type Form
	local form = {
		{type = "body", text = "File Path"},
		{id = "path", type = "textfield",
				value = srContainer._lastFilepath
			or ("scenes/%s.json"):format(tostring(sceneRoot):lower())},
		{type = "body", text = "Format"},
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

	local pathField = sheet:getElement("path", "LineEdit")
	pathField
		:setUnfocusedPosition("right")
		:setSubmitOnFocusLost(false)
	pathField.textSubmitted:connect(window, "submit", false, false)

	-- Add those fields
	window:addChild(vbox)

	-- Connect events
	window:addAction("Cancel", "close")
	window:addAction("Save", "submit")
	window.submit = function()
		local path = pathField._submittedText
		if not srContainer._lastFilepath then
			mw.toolbox.addFilePath(path)
		end
		srContainer._lastFilepath = path
		srContainer.name = LuaPath:file_name(path)
		local item = sheet:getValue("format")
		---@cast item PopupMenu.Item
		srContainer._lastFormat = item.label
		if ToolboxActions.saveScene() then
			window:close()
			mw.gameTabContainer:updateTabs()
		end
	end

	-- Show the popup
	mw:addChild(window)
	window:popupCentered()
	pathField:grabFocus(false)
end

---Shows the "load scene" popup
function ToolboxPopups.popupLoadScene()
	local srContainer = mw:getSubrootContainer()

	-- Create the popup
	local window = WindowPopup()
	window:setAnchorsAndOffsets(
		0.0, 0.5, 0.0, 0.5,
		-90, -71, 90, 56
	)

	window:getTitleLabel():setText("Load scene...")

	---@type Form
	local form = {
		{type = "body", text = "File Path"},
		{id = "path", type = "textfield",
				value = srContainer and srContainer._lastFilepath or "scenes/myscene.json"},
		{id = "searchMatch", type = "body", text = "Search result..."},
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

	-- Search result label
	local matchLabel = sheet:getElement("searchMatch", "Label")
	pathField.textChanged:connectCallable(function(_, text)
		local match = fzy.get_best_match(text, mw.toolbox.getFilePaths())
		if match then
			matchLabel:setText(match)
		else
			matchLabel:setText("(no match)")
		end
	end)

	-- Connect events
	window:addAction("Cancel", "close")
	window:addAction("Load", "submit")
	window.submit = function()
		local enteredPath = pathField._submittedText
		local path = fzy.get_best_match(enteredPath, mw.toolbox.getFilePaths())
		if not path then
			return
		end

		local _, sceneOrErr = pcall(ObjectLoader.get, ObjectLoader, path, "SceneFactory")
		if sceneOrErr then
			ToolboxActions.loadSceneFromFactory(sceneOrErr, path)
			window:close()
		else
			print(sceneOrErr)
		end
	end

	-- Show the popup
	mw:addChild(window)
	window:popupCentered()
	pathField:grabFocus(false)
end

---Show the "add node" popup
function ToolboxPopups.popupAddNode()
	local srContainer = mw:getSubrootContainer()
	if not srContainer then return end
	local sceneRoot = srContainer:getSceneRoot()
	local instanceUnder = mw.sceneTree:getPressedNode() or sceneRoot
	if not (instanceUnder and instanceUnder._valid) then
		instanceUnder = srContainer.subroot
	end

	-- Create the popup
	local window = WindowPopup()
	window:setAnchorsAndOffsets(
		0.5, 0.5, 0.5, 0.5,
		0, 0, 180, 127
	)

	window:getTitleLabel():setText("Add node...")

	---@type Form
	local form = {
		{type = "body", text = "Class Name"},
		{id = "class", type = "textfield",
				value = (instanceUnder ~= srContainer.subroot and instanceUnder.CLASS_NAME) or "Node"},
		{id = "searchMatch", type = "body", text = "Search result..."},
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

	-- Search result label
	local matchLabel = sheet:getElement("searchMatch", "Label")
	classField.textChanged:connectCallable(function(_, text)
		local match = fzy.get_best_match(text, Adore.getClassNames())
		if match then
			matchLabel:setText(match)
		else
			matchLabel:setText("(no match)")
		end
	end)

	-- Connect events
	window:addAction("Cancel", "close")
	window:addAction("Add", "submit")
	window.submit = function()
		local enteredClassName = classField._submittedText

		local className = fzy.get_best_match(enteredClassName, Adore.getClassNames())
		if not className then
			return
		end

		local success, ClassOrErr = pcall(Adore.Any, className)
		if success then
			if ClassOrErr.is and ClassOrErr:is(Node) or ClassOrErr == Node then
				-- Create the scene and add the tab
				srContainer:pushSubroot()

				---@type Node
				local newNode = ClassOrErr()
				srContainer:handleInsideSubroot(instanceUnder.addChild, instanceUnder, newNode)
				newNode._owner = sceneRoot

				srContainer:popSubroot()
				mw.sceneTree:updateNodes()
				mw.sceneTree:focusNode(newNode)
				window:close()
			else
				print(("Class '%s' is not a Node"):format(className))
			end
		else
			print(ClassOrErr)
		end
	end

	-- Show the popup
	mw:addChild(window)
	window:popupCentered()
	classField:grabFocus(false)
end

---Shows the "extend Node" popup
function ToolboxPopups.popupExtendNode()
	local srContainer = mw:getSubrootContainer()
	if not srContainer then return end
	local selectedNode = mw.sceneTree:getPressedNode()
	if not (selectedNode and selectedNode:is(Node)) then return end

	-- Create the popup
	local window = WindowPopup()
	window:setAnchorsAndOffsets(
		0.5, 0.5, 0.5, 0.5,
		0, 0, 180, 242
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
		{type = "body", text = "File Path"},
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
	window.submit = function()
		local baseClassName = baseClassField._submittedText
		local newClassName = newClassField._submittedText
		local savePath = pathField._submittedText

		-- Check if the base class exists
		local success, baseClassOrErr = pcall(Adore.Any, baseClassName)
		if not success then print(baseClassOrErr) return end
		-- Check if the new class DOESN'T exist
		local err
		success, err = pcall(Adore.Any, newClassName)
		if success then print(("Class '%s' already exists"):format(newClassName)) return end

		-- Create the directories and open the file
		local NativeFS = Adore.Libraries("NativeFS")
		if NativeFS.getInfo(savePath) then
			print(("Location '%s' is not empty"):format(savePath))
			return
		end

		NativeFS.createDirectory(LuaPath:dir_name(savePath))
		local file = NativeFS.newFile(savePath)
		if not (file:isOpen() or file:open("w") or file:getMode() == "w") then
			print("Can't open file")
			return false
		end

		local dropdown = sheet:getElement("template", "DropdownButton")
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

		-- Make it searchable
		local requirePath = savePath:match("(.*)%.lua"):gsub("/", ".")
		Adore.addUserPaths({[newClassName] = requirePath})

		-- Write the configuration
		local toolbox = mw.toolbox
		local config = toolbox.projectConfig
		if config then
			config.userPaths = config.userPaths or {}
			config.userPaths[newClassName] = requirePath
			toolbox.godRoot:writeConfiguration()
		end

		-- Make the selected Node the new type
		ToolboxActions.changeTypeOfNode(selectedNode, newClassName)

		window:close()
	end

	-- Show the popup
	mw:addChild(window)
	window:popupCentered()
	newClassField:grabFocus(false)
end

---Shows the "link scene" popup
function ToolboxPopups.popupLinkScene()
	local srContainer = mw:getSubrootContainer()
	if not srContainer then return end
	local sceneRoot = srContainer:getSceneRoot()
	if not sceneRoot then return end
	local instanceUnder = mw.sceneTree:getPressedNode() or sceneRoot
	if not instanceUnder then return end

	-- Create the popup
	local window = WindowPopup()
	window:setAnchorsAndOffsets(
		0.5, 0.5, 0.5, 0.5,
		0, 0, 180, 132
	)

	window:getTitleLabel():setText("Link scene...")

	---@type Form
	local form = {
		{type = "body", text = "File Path"},
		{id = "path", type = "textfield",
				value = "scenes/myscene.json"},
		{id = "searchMatch", type = "body", text = "Search result..."},
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

	-- Search result label
	local matchLabel = sheet:getElement("searchMatch", "Label")
	pathField.textChanged:connectCallable(function(_, text)
		local match = fzy.get_best_match(text, mw.toolbox.getFilePaths())
		if match then
			matchLabel:setText(match)
		else
			matchLabel:setText("(no match)")
		end
	end)

	-- Connect events
	window:addAction("Cancel", "close")
	window:addAction("Link", "submit")
	window.submit = function()
		local enteredPath = pathField._submittedText
		local path = fzy.get_best_match(enteredPath, mw.toolbox.getFilePaths()) or enteredPath
		if not path then
			return
		end

		local success, sceneOrErr = pcall(ObjectLoader.get, ObjectLoader, path)
		if success then
			---@cast sceneOrErr SceneFactory
			-- Add it
			ToolboxActions.linkScene(sceneOrErr, instanceUnder)
			window:close()
		else
			print(sceneOrErr)
		end
	end

	-- Show the popup
	mw:addChild(window)
	window:popupCentered()
	sheet:getElement("path"):grabFocus(false)
end

---Shows the popup for changing the type of the selected node
function ToolboxPopups.popupChangeType()
	local srContainer = mw:getSubrootContainer()
	if not srContainer then return end
	local sceneRoot = srContainer:getSceneRoot()
	local selected = mw.sceneTree:getPressedNode()
	if not selected then return end

	-- Create the popup
	local window = WindowPopup()
	window:setAnchorsAndOffsets(
		0.5, 0.5, 0.5, 0.5,
		0, 0, 180, 127
	)

	window:getTitleLabel():setText(("Change type of %s (%s)..."):format(tostring(selected), selected.CLASS_NAME))

	---@type Form
	local form = {
		{type = "body", text = "Class Name"},
		{id = "class", type = "textfield",
				value = (selected ~= srContainer.subroot and selected.CLASS_NAME) or "Node"},
		{id = "searchMatch", type = "body", text = "Search result..."},
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

	-- Search result label
	local matchLabel = sheet:getElement("searchMatch", "Label")
	classField.textChanged:connectCallable(function(_, text)
		local match = fzy.get_best_match(text, Adore.getClassNames())
		if match then
			matchLabel:setText(match)
		else
			matchLabel:setText("(no match)")
		end
	end)

	-- Connect events
	window:addAction("Cancel", "close")
	window:addAction("Add", "submit")
	window.submit = function()
		local enteredClassName = classField._submittedText

		local className = fzy.get_best_match(enteredClassName, Adore.getClassNames())
		if not className then
			return
		end

		local success, ClassOrErr = pcall(Adore.Any, className)
		if success then
			if ClassOrErr.is and ClassOrErr:is(Node) or ClassOrErr == Node then
				-- Create the scene and add the tab
				srContainer:pushSubroot()

				---@type Node
				srContainer:handleInsideSubroot(ToolboxActions.changeTypeOfNode, mw, selected, ClassOrErr)
				selected._owner = sceneRoot

				srContainer:popSubroot()
				mw.sceneTree:updateNodes()
				mw.sceneTree:focusNode()
				mw.sceneTree:focusNode(selected)
				window:close()
			else
				print(("Class '%s' is not a Node"):format(className))
			end
		else
			print(ClassOrErr)
		end
	end

	-- Show the popup
	mw:addChild(window)
	window:popupCentered()
	classField:grabFocus(false)
end

return ToolboxPopups
