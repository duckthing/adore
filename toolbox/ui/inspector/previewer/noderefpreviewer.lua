local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local Previewer = require(ADORE_PATH..".toolbox.ui.inspector.previewer")

local Button = Nodes("Button")

---@class Previewer.NodeRef: Previewer
local NodeRefP = Previewer:extend()

function NodeRefP:new(node, property, propertyName, inspector)
	NodeRefP.super.new(self, node, property, propertyName)
	---@type Toolbox.Inspector
	self.inspector = inspector
end

function NodeRefP:newValueLabel(object, property, propertyName, inspector)
	---@type boolean
	local val = property:get(object, propertyName)
	local button = Button(tostring(val))
		:setAnchors(1, 0, 1, 1)
		:setOffsets(0, 0, -40, 0)
	button.clicked:connect(self, "onInput")

	return button
end

function NodeRefP:onInput()
	local object, property, propertyName =
		self.object, self.property, self.propertyName
	---@type boolean
	local val = property:get(object, propertyName)
	if val then
		self.inspector.sceneTree:selectNode(val)
	end
end

return NodeRefP
