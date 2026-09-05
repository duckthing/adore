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
	nilButton.clicked:connect(self, "makeNil")

	self:addChild(self.nameLabel)
	self:addChild(self.value)
	self:addChild(nilButton)
end

---@param self Button
local function _canDropData(self, posX, posY, data)
	if data and type(data) == "table" and data.IS_NODE then
		return true
	end
end

---@param self Button
local function _getDragData(self)
	-- Return the contained Node
	---@type Previewer.NodeRef
	local previewer = self.previewer
	return previewer.property:get(previewer.object, previewer.propertyName)
end

---@param self Button
local function _dropData(self, posX, posY, data)
	if data and type(data) == "table" and data.IS_NODE then
		---@type Previewer.NodeRef
		local previewer = self.previewer
		previewer:attemptSet(data)
	end
end

function NodeRefP:newValueLabel(object, property, propertyName, inspector)
	---@type Object
	local val = property:get(object, propertyName)
	local name = tostring(val)
	local selectable = val and val._adoreSelectable
	if not selectable and val ~= nil then name = ("%s [INTERNAL]"):format(name) end
	local button = Button(name)
		:setAnchors(1, 0, 1, 1)
		:setOffsets(-120, 0, -20, 0)
	button.clicked:connect(self, "focusNode")
	button:setDisabled(not selectable)

	button._canDropData = _canDropData
	button._getDragData = _getDragData
	button._dropData = _dropData
	button.previewer = self

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

---Used for a Button connection; sets this property to `nil`
function NodeRefP:makeNil()
	return self:attemptSet()
end

function NodeRefP:onInput(node)
	local object, property, propertyName =
		self.object, self.property, self.propertyName
	property:set(object, propertyName, node)

	local val = property:get(object, propertyName)
	local name = tostring(val)
	local selectable = val and val._adoreSelectable
	if not selectable and val ~= nil then name = ("%s [INTERNAL]"):format(name) end
	self.value:setText(name)
		:setDisabled(not selectable)
end

return NodeRefP
