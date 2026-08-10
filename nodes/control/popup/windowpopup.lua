---@type AdoreInit
local Adore = require ""
local Nodes = Adore.Nodes
local max = math.max

local Label = Nodes("Label")
local Button = Nodes("Button")
local Popup = Nodes("Popup")
local ColorRect = Nodes("ColorRect")
local HBox = Nodes("HBox")

---@class WindowPopup: Popup
---@overload fun(): WindowPopup
local WindowPopup = Popup:extend()
WindowPopup.CLASS_NAME = "WindowPopup"
WindowPopup._destroyOnClose = true

---@type integer # The space the titlebar will take
WindowPopup._titleHeight = 20
---@type integer # The space the actionbar will take
WindowPopup._actionbarHeight = 34
---@type integer # The vertical padding above and below the actions
WindowPopup._actionVerticalPadding = 4
---@type integer # The padding around the action text
WindowPopup._actionTextPadding = 4

function WindowPopup:new()
	WindowPopup.super.new(self)

	local titleHeight = self._titleHeight

	---@type ColorRect # The ColorRect that contains the titlebar elements
	self._titlebar = ColorRect()
		:setAnchorsAndOffsets(
			0, 0, 1, 0,
			0, 0, 0, titleHeight
		)
	self._titlebar.albedo = {0.17, 0.17, 0.2, 1}

	---@type Label # The title Label
	self._title = Label("Window")
		:setAnchors(0, 0, 1, 1)
		:setAlign("center")
		:setJustify("center")
	self._title._adorePersist = false

	---@type Button # The close Button
	self._closeButton = Button("X")
		:setAnchorsAndOffsets(
			1, 0, 1, 0,
			0, 0, -titleHeight, titleHeight
		)
		:setTextAlign("center")
		:setVariant("flat")
	self._closeButton.focusMode = "click"
	self._closeButton._adorePersist = false

	---@type HBox? # The actionbar HBox, which may not exist yet
	self._actionbar = nil

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

---Returns the actionbar, if it exists
---@return HBox?
function WindowPopup:getActionBar()
	return self._actionbar
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

---Override; returns `true` if the WindowPopup was closed
---@return boolean closed
function WindowPopup:submit()
	self:close()
	return true
end

---Adds the given Button to the actionbar, and then returns it so you can connect to it
---@param name string
---@param defaultMethod "close" | "submit" | string? # The method on this WindowPopup connected to this Button
---@return Button
function WindowPopup:addAction(name, defaultMethod)
	local bar = self._actionbar
	if not bar then
		-- Create the actionbar if it doesn't exist
		bar = HBox()
		local height = self._actionbarHeight
		local padding = self._actionVerticalPadding
		bar:setAnchorsAndOffsets(
			0, 1, 1, 1,
			0, -height + padding, 0, -padding
		)
			:setMargin(4)
			:setSortMode("center")
		bar._adorePersist = false
		self:addChild(bar)
		self._actionbar = bar
	end

	-- Create the action
	local button = Button(name)
	local width = button._textBatch:getWidth() + self._actionTextPadding * 2
	button:setAnchorsAndOffsets(
		0, 0, 0, 1,
		width * -0.5, 0, width * 0.5, 0
	)
	bar:addChild(button)

	if defaultMethod then
		-- Connect a default method (like :close)
		button.clicked:connect(self, defaultMethod, false, false)
	end

	return button
end

function WindowPopup:_simpleRefresh(child, w, h)
	local offsetY = 0
	if child == self._titlebar or child == self._actionbar then
		-- Resize the titlebar/actionbar like normal
		return WindowPopup.super._simpleRefresh(self, child, w, h)
	else
		-- Change the available space
		offsetY = self._titleHeight
		local endH = 0
		if self._actionbar then
			-- If the actionbar exists, reduce the space available
			endH = self._actionbarHeight
		end
		h = max(0, h - offsetY - endH)
	end
	local lcr = self._localContentRect
	local childX, childY, childW, childH = child:_getRectFromParentSize(w, h)
	child:_setCanonRect(childX + lcr.x, childY + lcr.y + offsetY, childW, childH)
	child:onRefreshed()
end

---Removes all children from this WindowPopup
---@param shouldDestroy boolean?
function WindowPopup:clearChildren(shouldDestroy)
	local children = self.children
	local titlebar = self._titlebar
	for i = #children, 1, -1 do
		local child = children[i]
		if child ~= titlebar then
			-- Only remove children that aren't the titlebar
			self:removeChildAtIndex(i, shouldDestroy)
		end
	end
end

return WindowPopup
