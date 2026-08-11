local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local Label = Nodes("Label")

local Previewers = require(ADORE_PATH..".toolbox.ui.inspector.previewers")

---@class Toolbox.Inspector: Control
---@field super Control
---@overload fun(toolbox: Toolbox, sceneTree: Toolbox.SceneTree): Toolbox.Inspector
local Inspector = Nodes("Control"):extend()
Inspector.CLASS_NAME = "Inspector"

local FontLoader = Adore.Loader.getCollection("FontLoader")
local BOLD_FONT = FontLoader:get("")

local BOLD_SIZE = 16

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
		:setOffsets(5, 0, 0, 30)
		:setAlign("left")
		:setJustify("center")
		:setFont(BOLD_FONT)
		:setFontSize(BOLD_SIZE)

	local vbox = Nodes("VBox")()
	self.vbox = vbox
	vbox:setAnchorsAndOffsets(
		0, 0, 1, 1,
		0, 36, 0, 0
	)
	:setMargin(4)

	self:addChild(nameLabel)
	self:addChild(vbox)

	self.sceneTree.nodeSelected:connect(self, "onNodeSelectionChanged")
end

---Fired when a Node is (de)selected
---@param node Node?
function Inspector:onNodeSelectionChanged(node)
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

return Inspector
