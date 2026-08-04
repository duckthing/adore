---@type AdoreInit
local Adore = require ""
local Popup = Adore.Nodes("Popup")

local FontLoader = Adore.Loader.getCollection("FontLoader")
local ceil = math.ceil

---@class PopupMenu: Popup
---@overload fun(items: PopupMenu.Item[]?): PopupMenu
local PopupMenu = Popup:extend()
PopupMenu.CLASS_NAME = "PopupMenu"

---@class PopupMenu.Item
---@field label string?
---@field separator boolean? # Make `true` to use this item as a separator

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
	---@type integer # The index of the element that is being hovered over
	self._hoveredIndex = 0
	---@type boolean # If something is 'pressed' on this PopupMenu, but not selected yet
	self._pressed = false

	---@type Signal # Fired when an item is selected, with (PopupMenu, itemIndex, item)
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
		-- TODO: This should be (totalItems - 1), but it seems to clip off the end of the PopupMenu
		+ margin * totalItems
		+ padding * 2

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

	self:setMinimumSize(minWidth + padding * 2, minHeight)
end

function PopupMenu:mousemoved(mx, my)
	if not self:doesPointOverlap(mx, my) then return true end

	local itemCount = #self._items
	if itemCount > 0 then
		local _, ly = self:toLocal(mx, my)
		local padding, margin = self._padding, self._margin

		local font = self._font[self._fontSize]
		local itemHeight = font:getHeight() + margin

		local index = ceil((ly - padding) / (itemHeight))
		if index > 0 and index <= itemCount then
			-- Within bounds
			self._hoveredIndex = index
		else
			-- Outside of valid indices
			self._hoveredIndex = 0
		end
	else
		-- No items
		self._hoveredIndex = 0
	end

	return true
end

function PopupMenu:mousepressed(mx, my, button, isTouch, pressCount)
	if button == 1 then
		self._pressed = true
	end
	return PopupMenu.super.mousepressed(self, mx, my, button, isTouch, pressCount)
end

function PopupMenu:mousereleased(mx, my, button)
	if not self:doesPointOverlap(mx, my) then
		-- Handle off-screen clicks here
		self._pressed = false
		return true
	end

	if not self._pressed or button ~= 1 then return true end
	self._pressed = false

	local itemIndex = self._hoveredIndex
	if itemIndex == 0 then return true end
	local item = self._items[itemIndex]
	if not item then return true end

	-- If it's a separator, do nothing
	if item.separator then return true end
	self.itemSelected:fire(self, itemIndex, item)
	self:close()
	return true
end

function PopupMenu:uiMouseExited()
	self._hoveredIndex = 0
	PopupMenu.super.uiMouseExited(self)
end

return PopupMenu
