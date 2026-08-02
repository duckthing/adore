---@type AdoreInit
local Adore = require ""
local Nodes = Adore.Nodes

local Label = Nodes("Label")
local Button = Nodes("Button")
local Popup = Nodes("Popup")
local Control = Nodes("Control")
local ColorRect = Nodes("ColorRect")

---@class WindowPopup: Popup
---@overload fun(): WindowPopup
local WindowPopup = Popup:extend()
WindowPopup.CLASS_NAME = "WindowPopup"
-- WindowPopup._resizeWithParent = false

---@type integer # The space the titlebar will take
WindowPopup._titleHeight = 20

function WindowPopup:new()
	WindowPopup.super.new(self)

	local titleHeight = self._titleHeight

	---@type ColorRect # The ColorRect that contains the titlebar elements
	self._titlebar = ColorRect()
		:setAnchorsAndOffsets(
			0, 0, 1, 0,
			0, 0, 0, titleHeight
		)
	self._titlebar.albedo = {0.15, 0.15, 0.2, 1}

	---@type Label # The titlebar Label
	self._title = Label("Window")
		:setAnchors(0, 0, 1, 1)
		:setAlign("center")
		:setJustify("center")
	self._title._adorePersist = false

	---@type Button # The close button
	self._closeButton = Button("X")
		:setAnchorsAndOffsets(
			1, 0, 1, 0,
			0, 0, -titleHeight, titleHeight
		)
		:setTextAlign("center")
		:setVariant("flat")
	self._closeButton._adorePersist = false

	---@type Control # The Control where it is safe to put Controls under
	self._body = Control()
		:setAnchorsAndOffsets(
			0, 0, 1, 1,
			0, titleHeight, 0, 0
		)

	---@type boolean # If the close button is visible
	self._showCloseButton = self:canClose()
	self._closeButton:setVisible(self._showCloseButton)

	self._closeButton.clicked:connect(self, "close")

	self._titlebar:addChild(self._title)
	self._titlebar:addChild(self._closeButton)
	self:addChild(self._titlebar)
end

---Returns the Control that contains the titlebar elements
---@return Control
function WindowPopup:getTitlebar()
	return self._titlebar
end

---Returns the Control where Controls can be safely put under
---@return Control
function WindowPopup:getBody()
	return self._body
end

---Returns the titlebar Label
---@return Label
function WindowPopup:getTitleLabel()
	return self._title
end

---Returns the close Button
---@return Button
function WindowPopup:getCloseButton()
	return self._closeButton
end

---Sets the visibility of the close button
---@param visible boolean
---@return self
function WindowPopup:setCloseButtonVisible(visible)
	if self._showCloseButton ~= visible then
		self._showCloseButton = visible
		self:getCloseButton():setVisible(visible)
	end
	return self
end

return WindowPopup
