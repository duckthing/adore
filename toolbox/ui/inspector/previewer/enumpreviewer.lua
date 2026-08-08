local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local Previewer = require(ADORE_PATH..".toolbox.ui.inspector.previewer")

local Button = Nodes("Button")
---@type PopupMenu
local PopupMenu = Nodes("PopupMenu")

---@class Previewer.Enum: Previewer
local EnumP = Previewer:extend()

function EnumP:newValueLabel(object, property, propertyName)
	local val = property:get(object, propertyName)
	local button = Button(tostring(val))
		:setAnchors(1, 0, 1, 1)
		:setOffsets(0, 0, -80, 0)
	button.clicked:connect(self, "showPopup")

	return button
end

function EnumP:showPopup()
	local property = self.property
	---@cast property Property.Enum

	-- Create the list of items from the valid enum map
	local map = property:getValueMap(self.object, self.propertyName)
	---@type PopupMenu.Item[]
	local items = {}
	for name, _ in pairs(map) do
		items[#items+1] = {label = tostring(name), value = name}
	end

	local menu = PopupMenu(items)
	menu._destroyOnClose = true
	menu.itemSelected:connect(self, "onItemSelected")
	menu:setAnchors(0, 1, 0, 1)
	-- Add it to the button
	self.children[2]:addChild(menu)
	menu:popup()
end

function EnumP:onItemSelected(menu, itemIndex, item)
	self:attemptSet(item.value)
end

function EnumP:onInput(item)
	local object, property, propertyName =
		self.object, self.property, self.propertyName
	---@cast property Property.Enum

	property:set(object, propertyName, item)
	self.value:setText(tostring(item))
end

return EnumP
