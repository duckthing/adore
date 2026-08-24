local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local Previewer = require(ADORE_PATH..".toolbox.ui.inspector.previewer")
local Expression = Adore.Libraries("Expression")
local Vec2 = Adore.Common("Vec2")

local LineEdit = Nodes("LineEdit")

---@class Previewer.Vec2: Previewer
---@field super Previewer
local Vec2P = Previewer:extend()

function Vec2P:construct(object, property, propertyName)
	self:setOffsets(0, 0, 0, 50)

	self.nameLabel = self:newNameLabel(object, property, propertyName)
	self.nameLabel:setAnchorBottom(0.5)
	self.xField = self:newValueLabel(object, property, propertyName, "x")
	self.yField = self:newValueLabel(object, property, propertyName, "y")
	self.yField:translate(0, 25)

	self:addChild(self.nameLabel)
	self:addChild(self.xField)
	self:addChild(self.yField)
end

function Vec2P:newValueLabel(object, property, propertyName, component)
	---@type boolean
	local val = property:get(object, propertyName)

	local edit = LineEdit(tostring(val and val[component]))
		:setAnchors(1, 0, 1, 0)
		:setOffsets(-150, 0, 0, 25)
		:setAlign("right")

	local method = (component == "x" and "onXInput") or "onYInput"
	edit.textSubmitted:connect(self, method)

	return edit
end

function Vec2P:onXInput(_, text) self:onInput(text, "x") end
function Vec2P:onYInput(_, text) self:onInput(text, "y") end

local symbols = {self = 0}
local tempVec2 = Vec2(0, 0)
function Vec2P:onInput(text, component)
	local object, property, propertyName =
		self.object, self.property, self.propertyName

	-- Set the symbol with the component, if the Vec2 exists
	local currVec = property:get(object, propertyName)
	if currVec then
		symbols.self = currVec[component]
	else
		symbols.self = 0
	end

	local num = tonumber(text)
	if not num then
		-- Try solving it
		local success, x = Expression.solve(text, math, symbols)
		if success then num = x end
	end

	if num then
		-- Number input is valid
		if currVec == nil then
			tempVec2.x, tempVec2.y = 0, 0
		else
			tempVec2.x, tempVec2.y =
				currVec.x, currVec.y
		end

		tempVec2[component] = num
		property:set(object, propertyName, tempVec2)

		local newVec = property:get(object, propertyName)
		self.xField:setText(tostring(newVec.x))
		self.yField:setText(tostring(newVec.y))
	else
		-- Number input is invalid
		if currVec == nil then
			self.xField:setText("nil")
			self.yField:setText("nil")
		else
			self.xField:setText(tostring(currVec.x))
			self.yField:setText(tostring(currVec.y))
		end
	end
end

return Vec2P
