local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local Previewer = require(ADORE_PATH..".toolbox.ui.inspector.previewer")

local Button = Nodes("Button")

---@class Previewer.Boolean: Previewer
local BooleanP = Previewer:extend()

function BooleanP:newValueLabel(object, property, propertyName)
	---@type boolean
	local val = property:get(object, propertyName)
	local button = Button(tostring(val))
		:setAnchors(1, 0, 1, 1)
		:setOffsets(0, 0, -40, 0)
	button.clicked:connect(self, "attemptSet")

	return button
end

function BooleanP:onInput()
	local object, property, propertyName =
		self.object, self.property, self.propertyName
	---@type boolean
	local val = property:get(object, propertyName)
	property:set(object, propertyName, not val)
	self.value:setText(tostring(not val))
end

return BooleanP
