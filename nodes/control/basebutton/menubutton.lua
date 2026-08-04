---@type AdoreInit
local Adore = require ""
local Button = Adore.Nodes("Button")
local PopupMenu = Adore.Nodes("PopupMenu")

---A Button that opens a PopupMenu when clicked
---@class MenuButton: Button
---@field super Button
---@overload fun(text: string?, icon: TextureSource?, items: PopupMenu.Item[]?): MenuButton
local MenuButton = Button:extend()
MenuButton.CLASS_NAME = "MenuButton"
MenuButton.DEFAULT_VARIANT = "flat"

---@param text string
---@param icon TextureSource
---@param items PopupMenu.Item[]?
function MenuButton:new(text, icon, items)
	MenuButton.super.new(self, text, icon)
	self:setVariant(self.DEFAULT_VARIANT)

	---@type PopupMenu # The internal PopupMenu
	local popupMenu = PopupMenu(items)
	popupMenu
		:setAnchors(0, 1, 0, 1)
	popupMenu._adorePersist = false
	self._popupMenu = popupMenu
	self:addChild(popupMenu)

	self.clicked:connect(popupMenu, "popup", false, false)
end

---Gets the internal PopupMenu inside of this MenuButton
---@return PopupMenu
function MenuButton:getPopupMenu()
	return self._popupMenu
end

return MenuButton
