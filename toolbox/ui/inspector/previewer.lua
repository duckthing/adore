local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes

local Control = Nodes("Control")
local HBox = Nodes("HBox")
local Label = Nodes("Label")

---@class Previewer: Control
---@field super Control
local Previewer = Control:extend()
Previewer.CLASS_NAME = "Previewer"
---@type Toolbox
Previewer.Toolbox = nil

---@param object Object
---@param property Property
---@param propertyName string
function Previewer:new(object, property, propertyName, inspector)
	Previewer.super.new(self)
	self:setAnchors(0, 0, 1, 0)
		:setOffsets(0, 0, 0, 25)

	self.object, self.property, self.propertyName =
		object, property, propertyName

	self:construct(object, property, propertyName)
end

---@param object Object
---@param property Property
---@param propertyName string
function Previewer:construct(object, property, propertyName)
	self.nameLabel = self:newNameLabel(object, property, propertyName)
	self.value = self:newValueLabel(object, property, propertyName)

	self:addChild(self.nameLabel)
	self:addChild(self.value)
end

---(Pushes the subroot if needed, and) calls `:onInput`, which should set the property
---@param ... unknown
function Previewer:attemptSet(...)
	local toolbox = Previewer.Toolbox
	local srContainer = toolbox:getSubrootContainer()
	if srContainer:isPushed() then
		-- Pushed from outside; don't pop
		self:onInput(...)
	else
		-- Not pushed yet; push for this action
		srContainer:pushSubroot()
		self:onInput(...)
		srContainer:popSubroot()
	end
end

---Sets the property; should be overridden
---@param ... unknown
function Previewer:onInput(...) end

---@param object Object
---@param property Property
---@param propertyName string
---@return Label
function Previewer:newNameLabel(object, property, propertyName)
	return Label(propertyName)
		:setJustify("center")
		:setAlign("left")
		:setAnchors(0, 0, 0.5, 1)
		:setOffsets(0, 0, 0, 0)
end

---@param object Object
---@param property Property
---@param propertyName string
---@return Label
function Previewer:newValueLabel(object, property, propertyName)
	return Label(tostring(property:get(object, propertyName)))
		:setJustify("center")
		:setAlign("right")
		:setAnchors(0.5, 0, 1, 1)
		:setOffsets(0, 0, 0, 0)
end

return Previewer
