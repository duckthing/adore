local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local Previewer = require(ADORE_PATH..".toolbox.ui.inspector.previewer")

local Button = Nodes("Button")

---@class Previewer.Method: Previewer
local MethodP = Previewer:extend()

function MethodP:new(node, property, propertyName, inspector)
	MethodP.super.new(self, node, property, propertyName)
	---@type Toolbox.Inspector
	self.inspector = inspector
end

function MethodP:construct(object, property, propertyName)
	---@cast property Property.Method
	local button = Button(property.label)
		:setAnchors(0, 0, 1, 1)
		:setOffsets(20, 0, -20, 0)
	button.clicked:connect(object, propertyName)

	self:addChild(button)
end

return MethodP
