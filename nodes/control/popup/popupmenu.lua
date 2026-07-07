---@type AdoreInit
local Adore = require ""
local Popup = Adore.Nodes("Popup")
local Vec2 = Adore.Common("Vec2")

local FontLoader = Adore.Loader.getCollection("FontLoader")
local max = math.max

---@class PopupMenu: Popup
---@overload fun(items: PopupMenu.Item[]?): PopupMenu
local PopupMenu = Popup:extend()
PopupMenu.CLASS_NAME = "PopupMenu"

---@class PopupMenu.Item
---@field label string?

local DEFAULT_FONT = FontLoader:get("")
---@type FontSource? # The overridden font
PopupMenu._font = DEFAULT_FONT
---@type integer?
PopupMenu._fontSize = 0
---@type number # The padding around the edges of this menu
PopupMenu._padding = 8
---@type number # The margin between menu items
PopupMenu._margin = 4

---@param items PopupMenu.Item[]?
function PopupMenu:new(items)
	PopupMenu.super.new(self)

	---@type PopupMenu.Item[]
	self._items = nil

	self.itemSelected = self:newSignal()

	self:setItems(items or {})
end

---Sets the menu items and updates the PopupMenu
---@param items PopupMenu.Item[]
function PopupMenu:setItems(items)
	self._items = items

	local padding, margin = self._padding, self._margin
	local font = self._font[self._fontSize]
	local totalItems = #items
	local minWidth = 0
	local minHeight = font:getHeight() * totalItems

	if totalItems > 1 then
		minHeight = minHeight + margin * (totalItems - 1)
	end

	-- Get the width required to fit all items
	for i = 1, #items do
		local item = items[i]
		if item.label then
			local currWidth = font:getWidth(item.label)
			if currWidth > minWidth then
				minWidth = currWidth
			end
		end
	end

	self:setMinimumSize(minWidth + padding * 2, minHeight + padding * 2)
end

return PopupMenu
