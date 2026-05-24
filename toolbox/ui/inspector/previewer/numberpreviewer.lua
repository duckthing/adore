local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local Previewer = require(ADORE_PATH..".toolbox.ui.inspector.previewer")
local Expression = Adore.Libraries("Expression")

local LineEdit = Nodes("LineEdit")

---@class Previewer.Number: Previewer
local NumberP = Previewer:extend()

function NumberP:newValueLabel(object, property, propertyName)
	local edit = LineEdit()
		:setAnchors(1, 0, 1, 1)
		:setOffsets(-150, 0, 0, 0)
		:setText(tostring(property:get(object, propertyName)))
		:setAlign("right")
	edit.textSubmitted:connect(self, "attemptSet")
	self.edit = edit

	return edit
end

local symbols = {self = 0}
function NumberP:onInput(text)
	local object, property, propertyName =
		self.object, self.property, self.propertyName
	local currNum = property:get(object, propertyName)

	local num = tonumber(text)
	if not num then
		-- Try solving it
		symbols.self = currNum
		local success, x = Expression.solve(text, math, symbols)
		if success then num = x end
	end

	if num then
		property:set(object, propertyName, num)
		self.edit:setText(tostring(property:get(object, propertyName)))
	else
		self.edit:setText(tostring(currNum))
	end
end

return NumberP
