---@type AdoreInit
local Adore = require ""
local Control = Adore.Nodes("Control")
local bit = Adore.Common("bitlib")

---@class BaseButton: Control
---@field super Control
---@overload fun(): BaseButton
local BaseButton = Control:extend()
BaseButton.CLASS_NAME = "BaseButton"
BaseButton._mouseMode = "sink"
BaseButton.focusMode = "all"
BaseButton.subclassMap = {
	normal = "",
	hovered = "hovered",
	pressed = "pressed",
	focused = "hovered",
	disabled = "disabled",
}

---@type integer # What button registers as a 'click', in binary. 1 registers left-click, 3 registers left and right, and 7 registers left, middle, and right.
BaseButton.buttonFilter = 1

function BaseButton:new()
	BaseButton.super.new(self)

	---@type boolean # If the button is 'down'
	self._pressed = false
	---@type boolean # If the button should not be pressable or focusable
	self._disabled = false

	---@type Signal # Triggered whenever the button is pressed, NOT RELEASED.
	self.pressed = self:newSignal()
	---@type Signal # Triggered whenever the button is released.
	self.released = self:newSignal()
	---@type Signal # Triggered whenever the button is pressed and then released with the pointer over it.
	self.clicked = self:newSignal()
end

function BaseButton:canFocus(isMouse)
	return not self._disabled and BaseButton.super.canFocus(self, isMouse)
end

---Connects a simple Callable to the BaseButton.
---**Bad practice!** Use `self.clicked` and connect to a `Node` to get more benefits.
---For info on this, see `Signal` and its documentation between `:connect` and `:connectCallable`.
---@param func fun(self: BaseButton, buttonIndex: integer)
---@param oneShot boolean?
---@return self
function BaseButton:onClick(func, oneShot)
	self.clicked:connectCallable(func, oneShot)
	return self
end

---Sets the `disabled` state, which prevents the button from being pressed and focused
---@param disabled boolean
---@return self
function BaseButton:setDisabled(disabled)
	if self._disabled ~= disabled then
		self._disabled = disabled
		self:_updateSubclass()
	end
	return self
end

function BaseButton:_updateSubclass()
	if self._disabled then
		self:setSubclass("disabled")
	elseif self._pressed then
		self:setSubclass("pressed")
	elseif self._hovered then
		self:setSubclass("hovered")
	elseif self._focused then
		self:setSubclass("focused")
	else
		self:setSubclass("normal")
	end
end

---@param x integer
---@param y integer
---@param button integer
function BaseButton:mousepressed(x, y, button)
	if not self._disabled and not self._pressed and bit.band(self.buttonFilter, bit.lshift(1, button - 1)) > 0 then
		self._pressed = true
		self:grabFocus(true)
		self.pressed:fire(self, button)
		self:_updateSubclass()
	end
end

---@param x integer
---@param y integer
---@param button integer
function BaseButton:mousereleased(x, y, button)
	if self._pressed and bit.band(self.buttonFilter, bit.lshift(1, button - 1)) > 0 then
		self._pressed = false
		self:releaseFocus()
		self.released:fire(self, button)
		if not self._disabled and self:doesPointOverlap(x, y) then
			self.clicked:fire(self, button)
		end
		self:_updateSubclass()
	end
end

function BaseButton:uiMouseEntered(x, y)
	BaseButton.super.uiMouseEntered(self, x, y)
	self:_updateSubclass()
end

function BaseButton:uiMouseExited()
	BaseButton.super.uiMouseExited(self)
	self:_updateSubclass()
end

function BaseButton:uiFocused(f)
	BaseButton.super.uiFocused(self, f)
	self:_updateSubclass()
end

function BaseButton:uiFocusLost()
	BaseButton.super.uiFocusLost(self)
	self._pressed = false
	self:_updateSubclass()
end

function BaseButton:uiActivate()
	BaseButton.super.uiActivate(self)
	if not self._disabled then
		self._pressed = true
		self.pressed:fire(self)
		self:_updateSubclass()
	end
end

function BaseButton:uiDeactivate()
	BaseButton.super.uiDeactivate(self)
	if not self._disabled then
		self._pressed = false
		self.released:fire(self)
		self.clicked:fire(self, 1)
		self:_updateSubclass()
	end
end

function BaseButton:forceDestroy(recursive)
	BaseButton.super.forceDestroy(self, recursive)
	self.pressed:release()
	self.released:release()
	self.clicked:release()

	self.pressed = nil
	self.released = nil
	self.clicked = nil
end

function BaseButton._addDefinition(entry)
	entry:newBoolean("_disabled", false, "setDisabled")
	entry:newSignal("clicked")
	entry:newSignal("pressed")
	entry:newSignal("released")
end

return BaseButton
