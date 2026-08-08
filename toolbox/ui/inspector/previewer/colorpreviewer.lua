local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local Previewer = require(ADORE_PATH..".toolbox.ui.inspector.previewer")
local Expression = Adore.Libraries("Expression")

local LineEdit = Nodes("LineEdit")

---@class Previewer.Color: Previewer
---@field super Previewer
local Color2P = Previewer:extend()

function Color2P:construct(object, property, propertyName)
	self:setOffsets(0, 0, 0, 100)

	self.nameLabel = self:newNameLabel(object, property, propertyName)
	self.nameLabel:setAnchorBottom(0.5)
	self.rField = self:newValueLabel(object, property, propertyName, 1)
	self.gField = self:newValueLabel(object, property, propertyName, 2)
	self.gField:translate(0, 25)
	self.bField = self:newValueLabel(object, property, propertyName, 3)
	self.bField:translate(0, 50)
	self.aField = self:newValueLabel(object, property, propertyName, 4)
	self.aField:translate(0, 75)

	self:addChild(self.nameLabel)
	self:addChild(self.rField)
	self:addChild(self.gField)
	self:addChild(self.bField)
	self:addChild(self.aField)
end

local componentToMethod = {
	"onRInput",
	"onGInput",
	"onBInput",
	"onAInput"
}

function Color2P:newValueLabel(object, property, propertyName, component)
	---@type boolean
	local val = property:get(object, propertyName)

	local edit = LineEdit(tostring(val and val[component]))
		:setAnchors(1, 0, 1, 0)
		:setOffsets(-150, 0, 0, 25)
		:setAlign("right")

	local method = componentToMethod[component]
	edit.textSubmitted:connect(self, method)

	return edit
end

function Color2P:onRInput(text) self:onInput(text, 1) end
function Color2P:onGInput(text) self:onInput(text, 2) end
function Color2P:onBInput(text) self:onInput(text, 3) end
function Color2P:onAInput(text) self:onInput(text, 4) end

local symbols = {self = 0}
local tempColor = {1, 1, 1, 1}

function Color2P:onInput(text, component)
	local object, property, propertyName =
		self.object, self.property, self.propertyName
	local currColor = property:get(object, propertyName)

	local num = tonumber(text)
	if not num then
		-- Try solving it
		symbols.self = (currColor and currColor[component]) or 0
		local success, x = Expression.solve(text, math, symbols)
		if success then num = x end
	end

	if num then
		-- Number input is valid
		if currColor == nil then
			tempColor[1], tempColor[2], tempColor[3], tempColor[4]
				= 1, 1, 1, 1
		else
			tempColor[1], tempColor[2], tempColor[3], tempColor[4]
				= currColor[1], currColor[2], currColor[3], currColor[4]
		end

		tempColor[component] = num
		property:set(object, propertyName, tempColor)

		local newColor = property:get(object, propertyName)
		self.rField:setText(tostring(newColor[1]))
		self.gField:setText(tostring(newColor[2]))
		self.bField:setText(tostring(newColor[3]))
		self.aField:setText(tostring(newColor[4]))
	else
		-- Number input is invalid
		if currColor == nil then
			self.rField:setText("nil")
			self.gField:setText("nil")
			self.bField:setText("nil")
			self.aField:setText("nil")
		else
			self.rField:setText(tostring(currColor[1]))
			self.gField:setText(tostring(currColor[2]))
			self.bField:setText(tostring(currColor[3]))
			self.aField:setText(tostring(currColor[4]))
		end
	end
end

return Color2P
