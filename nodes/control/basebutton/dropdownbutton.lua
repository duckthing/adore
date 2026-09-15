---@type AdoreInit
local Adore = require ""
local MenuButton = Adore.Nodes("MenuButton")

---@class DropdownButton: MenuButton
---@field super MenuButton
---@overload fun(icon: TextureSource?, items: PopupMenu.Item[]): DropdownButton
local DropdownButton = MenuButton:extend()
DropdownButton.CLASS_NAME = "DropdownButton"
DropdownButton.DEFAULT_VARIANT = ""

---@param icon TextureSource
---@param items PopupMenu.Item[]
function DropdownButton:new(icon, items)
	local firstItem = items[1]
	DropdownButton.super.new(self, (firstItem and firstItem.label) or "", icon, items)
	self._selectedItem = firstItem
	self._selectedItemIndex= 1
	self:getPopupMenu().itemSelected:connect(self, "_onPopupMenuItemSelected", false, false)
end

---Returns the last selected item
---@return PopupMenu.Item?
function DropdownButton:getSelectedItem()
	return self._selectedItem
end

function DropdownButton:_onPopupMenuItemSelected(_, itemIndex, item)
	if item ~= self._selectedItem then
		self:setText(item.label or "")
		self._selectedItem = item
		self._selectedItemIndex = itemIndex
	end
end

return DropdownButton
