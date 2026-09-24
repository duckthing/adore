local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local Label = Nodes("Label")
local MenuButton = Nodes("MenuButton")
local WindowPopup = Nodes("WindowPopup")
local FormBuilder = Adore.Common("FormBuilder")
local LuaPath = Adore.Libraries("LuaPath")
local ObjectSaver = Adore.Common("ObjectSaver")
local ObjectLoader = Adore.Loader.getCollection("ObjectLoader")

local Previewers = require(ADORE_PATH..".toolbox.ui.inspector.previewers")

---@class Toolbox.Inspector: Control
---@field super Control
---@overload fun(toolbox: Toolbox, sceneTree: Toolbox.SceneTree): Toolbox.Inspector
local Inspector = Nodes("Control"):extend()
Inspector.CLASS_NAME = "Inspector"

local FontLoader = Adore.Loader.getCollection("FontLoader")
local BOLD_FONT = FontLoader:get("")
local BOLD_SIZE = 16
local FORMAT_OPTIONS = {{label = "json"}, {label = "lua"}, {label = "binary"}}

local function getAddr(t)
	local mt = getmetatable(t)
	setmetatable(t, nil)
	local addr = tostring(t):match("(0x.*)")
	setmetatable(t, mt)
	return addr
end

---@param toolbox Toolbox
---@param sceneTree Toolbox.SceneTree
function Inspector:new(toolbox, sceneTree)
	Inspector.super.new(self)
	self:setVariant("panel")

	self.toolbox = toolbox
	self.sceneTree = sceneTree
	---@type Node? # The selected Node
	self.selected = nil

	local nameLabel = Label()
	self.nameLabel = nameLabel
	nameLabel
		:setAnchors(0, 0, 1, 0)
		:setOffsets(5, 0, -35, 30)
		:setAlign("left")
		:setJustify("center")
		:setFont(BOLD_FONT)
		:setFontSize(BOLD_SIZE)
		:setClipText(true)

	---@type PopupMenu.Item[]
	local menuItems = {
		{label = "Reload", func = "reload"},
		{label = "New Resource...", func = "newResource"},
		{label = "Save as...", func = "saveResourceAs"},
	}
	local menuButton = MenuButton("...", nil, menuItems)
		:setAnchorsAndOffsets(
			1, 0, 1, 0,
			-35, 0, -5, 30
		)
		:setVariant("")

	---@param item PopupMenu.Item | {func: string}
	menuButton:getPopupMenu().itemSelected:connectCallable(function(_, _, item)
		self[item.func](self)
	end)

	local vbox = Nodes("VBox")()
	self.vbox = vbox
	vbox:setAnchorsAndOffsets(
		0, 0, 1, 1,
		0, 36, 0, 0
	)
		:setMargin(4)
		:setClipChildren(true)

	self:addChild(nameLabel)
	self:addChild(menuButton)
	self:addChild(vbox)

	self.sceneTree.nodeFocused:connect(self, "onNodeFocusChanged")
end

---Fired when a Node is (un)focused
---@param viewer Toolbox.SceneTree
---@param node Node?
---@param inTree boolean
function Inspector:onNodeFocusChanged(viewer, node, inTree)
	-- Node selection is the same
	if self.selected == node then return end

	self.selected = node
	local vbox = self.vbox
	vbox:clearChildren(true)

	-- Node is nil/not selectable
	if not (node and node._adoreSelectable) then
		self.nameLabel:setText("")
		return
	end

	-- Node exists, create the properties
	local entry = node:getClassDBEntry()
	local lastClass = nil
	self.nameLabel:setText(tostring(node)..(" (%s)"):format(getAddr(node)))

	entry:forEachProperty(node, true, function(obj, property, propertyName, fromClass, ...)
		if fromClass ~= lastClass then
			-- Make the new class header
			lastClass = fromClass
			local header = Label(fromClass.CLASS_NAME)
				:setJustify("center")
				:setAlign("center")
				:setAnchors(0, 0, 1, 0)
				:setOffsets(0, 0, 0, 35)
				:setFont(BOLD_FONT)
				:setFontSize(BOLD_SIZE)
			vbox:addChild(header)
		end

		if not property.visible then return end

		local Previewer = Previewers[property.TYPE] or Previewers.any

		vbox:addChild(Previewer(obj, property, propertyName, self))
	end)
end

function Inspector:reload()
end

---Shows a popup for saving this resource
function Inspector:saveResourceAs()
	local selected = self.selected
	if not selected then return end
	-- Create the popup
	local window = WindowPopup()
	window:setAnchorsAndOffsets(
		0.5, 0.5, 0.5, 0.5,
		-90, -76, 90, 76
	)
	window._resizeWithParent = false

	window:getTitleLabel():setText("Save resource to...")

	---@type Form
	local form = {
		{type = "body", text = "File Path"},
		{id = "path", type = "textfield", value = "data/resource.json"},
		{type = "body", text = "Format"},
		{id = "format", type = "dropdown", items = FORMAT_OPTIONS, value = 1},
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
		local path = pathField._submittedText
		---@type string
		local format = sheet:getValue("format").item
		local success, err = ObjectSaver.saveToFilePath(path, selected, format)
		if not success then
			print(err)
		else
			if ObjectLoader:has(path) then
				print("we have", path)
				ObjectLoader:destructor(ObjectLoader:get(path), selected)
			else
				print("registering", path)
				ObjectLoader:register(selected, path)
			end
			print(("Saved resource to: %s"):format(path))
			window:close()
		end
	end

	-- Show the popup
	self:addChild(window)
	window:popup()
	pathField:grabFocus(false)
end

return Inspector
