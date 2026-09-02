local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
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

function NodeRefP:construct(object, property, propertyName)
	self.nameLabel = self:newNameLabel(object, property, propertyName)
	self.value = self:newValueLabel(object, property, propertyName)

	local nilButton = Button("x")
		:setAnchors(1, 0, 1, 1)
		:setOffsets(-20, 0, 0, 0)
	nilButton.clicked:connect(self, "onInput")

	self:addChild(self.nameLabel)
	self:addChild(self.value)
	self:addChild(nilButton)
end

function NodeRefP:newValueLabel(object, property, propertyName, inspector)
	---@type Object
	local val = property:get(object, propertyName)
	local selectable = val and val._adoreSelectable
	local name = tostring(val)
	if not selectable and selected ~= nil then name = ("%s [INTERNAL]"):format(name) end
	local button = Button(name)
		:setAnchors(1, 0, 1, 1)
		:setOffsets(-120, 0, -20, 0)
	button.clicked:connect(self, "focusNode")
	button:setDisabled(not selectable)

	return button
end

-- Focuses on the set Node
function NodeRefP:focusNode()
	local object, property, propertyName =
		self.object, self.property, self.propertyName
	---@type boolean
	local val = property:get(object, propertyName)
	if val then
		self.inspector.sceneTree:focusNode(val)
	end
end

function NodeRefP:onInput()
	local object, property, propertyName =
		self.object, self.property, self.propertyName
	property:set(object, propertyName, nil)
	self.value:setText(property:get(object, propertyName) or "nil")
	self.value:setDisabled(true)
end

return NodeRefP
