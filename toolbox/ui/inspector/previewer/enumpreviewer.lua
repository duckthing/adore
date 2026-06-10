local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local Previewer = require(ADORE_PATH..".toolbox.ui.inspector.previewer")

local Button = Nodes("Button")

---@class Previewer.Enum: Previewer
local EnumP = Previewer:extend()

function EnumP:newValueLabel(object, property, propertyName)
	local val = property:get(object, propertyName)
	local button = Button(tostring(val))
		:setAnchors(1, 0, 1, 1)
		:setOffsets(0, 0, -80, 0)
	button.clicked:connect(self, "attemptSet")

	return button
end

function EnumP:onInput()
	local object, property, propertyName =
		self.object, self.property, self.propertyName
	---@cast property Property.Enum

	local currVal = property:get(object, propertyName)
	local validValues = property.values
	local newVal = next(validValues, currVal)
	if newVal == nil then
		newVal = next(validValues)
	end

	property:set(object, propertyName, newVal)
	self.value:setText(tostring(newVal))
end

return EnumP
