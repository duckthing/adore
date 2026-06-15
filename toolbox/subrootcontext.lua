local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
local Adore = require(ADORE_PATH)

---@class Toolbox.SubrootContext: Context
---@overload fun(toolbox: Toolbox): Toolbox.SubrootContext
local SubrootC = Adore.Resources("Context"):extend()
SubrootC.CLASS_NAME = "SubrootContext"

---@param toolbox Toolbox
function SubrootC:new(toolbox)
	SubrootC.super.new(self)

	self._priority = -1
	self._toolbox = toolbox

	self.running = true
	self._mouseInside = false
	self._visible = true
end

function SubrootC:pointToWindow(mx, my)
	local toolbox = self._toolbox
	local window = toolbox.mainWindow.subWindow
	local lcr = window._localContentRect

	if lcr:containsPoint(mx, my) then
		local subViewport = window._subViewport
		local scaleX, scaleY =
			lcr.w / subViewport._windowW,
			lcr.h / subViewport._windowH

		local lx, ly =
			(mx - lcr.x) * scaleX,
			(my - lcr.y) * scaleX


		return lx, ly, scaleX, scaleY
	else
		return nil, nil
	end
end

function SubrootC:mousemoved(x, y, dx, dy, isTouch)
	if not self.running or not self._visible then return false end
	local toolbox = self._toolbox
	local lx, ly, scaleX, scaleY = self:pointToWindow(x, y)

	if lx then
		toolbox:pushSubroot()

		if not self._mouseInside then
			self._mouseInside = true
			toolbox.subRoot:mousefocus(true)
		end
		toolbox.subRoot:mousemoved(lx, ly, dx * scaleX, dy * scaleY, isTouch)

		toolbox:popSubroot()
		return true
	elseif self._mouseInside then
		-- Lost mouse focus
		self._mouseInside = false
		toolbox:pushSubroot()

		toolbox.subRoot:mousefocus(false)

		toolbox:popSubroot()
	end
	return false
end

function SubrootC:mousepressed(x, y, button, isTouch, presses)
	if not self.running or not self._visible then return false end
	local toolbox = self._toolbox
	local lx, ly, _, _ = self:pointToWindow(x, y)
	if lx then
		toolbox:pushSubroot()
		toolbox.subRoot:mousepressed(lx, ly, button, isTouch, presses)
		toolbox:popSubroot()
		return true
	end
	return false
end

function SubrootC:mousereleased(x, y, button, isTouch, presses)
	if not self.running or not self._visible then return false end
	local toolbox = self._toolbox
	local subroot = toolbox.subRoot
	local lx, ly, _, _ = self:pointToWindow(x, y)

	-- If we're pressing a button, make sure it receives mousereleased when outside the window
	if subroot and subroot._focusedControl then
		lx, ly = subroot.mouseX, subroot.mouseY
	end

	if lx then
		toolbox:pushSubroot()
		subroot:mousereleased(lx, ly, button, isTouch, presses)
		toolbox:popSubroot()
		return true
	end
	return false
end

function SubrootC:touchmoved(id, x, y, dx, dy, pressure)
	if not self.running or not self._visible then return false end
	local toolbox = self._toolbox
	local lx, ly, scaleX, scaleY = self:pointToWindow(x, y)
	if lx then
		toolbox:pushSubroot()
		toolbox.subRoot:touchmoved(id, lx, ly, dx * scaleX, dy * scaleY, pressure)
		toolbox:popSubroot()
		return true
	end
	return false
end

function SubrootC:touchpressed(id, x, y, dx, dy, pressure)
	if not self.running or not self._visible then return false end
	local toolbox = self._toolbox
	local lx, ly, scaleX, scaleY = self:pointToWindow(x, y)
	if lx then
		toolbox:pushSubroot()
		toolbox.subRoot:touchpressed(id, lx, ly, dx * scaleX, dy * scaleY, pressure)
		toolbox:popSubroot()
		return true
	end
	return false
end

function SubrootC:touchreleased(id, x, y, dx, dy, pressure)
	if not self.running or not self._visible then return false end
	local toolbox = self._toolbox
	local lx, ly, scaleX, scaleY = self:pointToWindow(x, y)
	if lx then
		toolbox:pushSubroot()
		toolbox.subRoot:touchreleased(id, lx, ly, dx * scaleX, dy * scaleY, pressure)
		toolbox:popSubroot()
		return true
	end
	return false
end

function SubrootC:update(dt)
	if not self.running or not self._visible then return false end
	local toolbox = self._toolbox
	local subroot = toolbox.subRoot
	if subroot then
		toolbox:pushSubroot()
		subroot:update(dt)
		subroot:drawToViewport()
		toolbox:popSubroot()
	end
end

SubrootC.HANDLERS = {
	keypressed = true,
	keyreleased = true,
	textinput = true,
	mousemoved = true,
	mousepressed = true,
	mousereleased = true,
	wheelmoved = true,
	gamepadaxis = true,
	gamepadpressed = true,
	gamepadreleased = true,
	joystickadded = true,
	joystickaxis = true,
	joystickhat = true,
	joystickpressed = true,
	joystickreleased = true,
	joystickremoved = true,
	touchmoved = true,
	touchpressed = true,
	touchreleased = true,

	update = true,
	-- resize = true,

	-- mousefocus = true,

	-- pushed = true,
	-- popped = true,
}

for handler, _ in pairs(SubrootC.HANDLERS) do
	if not rawget(SubrootC, handler) then
		---@param c Toolbox.SubrootContext
		SubrootC[handler] = function(c, ...)
			if not c.running or not c._visible then return false end
			local toolbox = c._toolbox
			local subroot = toolbox.subRoot
			if subroot then
				toolbox:pushSubroot()
				local handled = subroot[handler](subroot, ...)
				toolbox:popSubroot()
				return handled
			end
			return false
		end
	end
end

return SubrootC
