local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local Previewer = require(ADORE_PATH..".toolbox.ui.inspector.previewer")

local LineEdit = Nodes("LineEdit")

---@class Previewer.String: Previewer
local StringP = Previewer:extend()

function StringP:newValueLabel(object, property, propertyName)
	local edit = LineEdit()
		:setAnchors(1, 0, 1, 1)
		:setOffsets(-150, 0, 0, 0)
		:setText(property:get(object, propertyName))
		:setAlign("right")
	edit.textSubmitted:connect(self, "attemptSet")
	self.edit = edit

	return edit
end

function StringP:onInput(text)
	local object, property, propertyName =
		self.object, self.property, self.propertyName

	property:set(object, propertyName, text)
	self.edit:setText(property:get(object, propertyName))
end

return StringP
