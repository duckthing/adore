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
	local window = toolbox.mainWindow:getSubrootContainer()
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
	local toolbox = self._toolbox
	local srContainer = toolbox:getSubrootContainer()
	if not srContainer or not srContainer:isRunning() then return false end

	local lx, ly, scaleX, scaleY = self:pointToWindow(x, y)

	local subroot = assert(srContainer.subroot)

	if lx then
		-- Inside the window
		srContainer:pushSubroot()
		if not self._mouseInside then
			-- Tell it that it has focus
			self._mouseInside = true
			subroot:mousefocus(true)
		end
		subroot:mousemoved(lx, ly, dx * scaleX, dy * scaleY, isTouch)
		srContainer:popSubroot()
		return true
	elseif self._mouseInside then
		-- Lost mouse focus
		srContainer:pushSubroot()
		self._mouseInside = false
		subroot:mousefocus(false)
		srContainer:popSubroot()
		return false
	end
end

function SubrootC:mousepressed(x, y, button, isTouch, presses)
	local toolbox = self._toolbox
	local srContainer = toolbox:getSubrootContainer()
	if not srContainer or not srContainer:isRunning() then return false end

	local lx, ly, _, _ = self:pointToWindow(x, y)

	if lx then
		srContainer:pushSubroot()
		srContainer.subroot:mousepressed(lx, ly, button, isTouch, presses)
		srContainer:popSubroot()
		return true
	end
	return false
end

function SubrootC:mousereleased(x, y, button, isTouch, presses)
	local toolbox = self._toolbox
	local srContainer = toolbox:getSubrootContainer()
	if not srContainer or not srContainer:isRunning() then return false end

	local lx, ly, _, _ = self:pointToWindow(x, y)

	if lx then
		srContainer:pushSubroot()
		srContainer.subroot:mousereleased(lx, ly, button, isTouch, presses)
		srContainer:popSubroot()
		return true
	end
	return false
end

function SubrootC:touchmoved(id, x, y, dx, dy, pressure)
	local toolbox = self._toolbox
	local srContainer = toolbox:getSubrootContainer()
	if not srContainer or not srContainer:isRunning() then return false end

	local lx, ly, scaleX, scaleY = self:pointToWindow(x, y)

	if lx then
		srContainer:pushSubroot()
		srContainer.subroot:touchmoved(id, lx, ly, dx * scaleX, dy * scaleY, pressure)
		srContainer:popSubroot()
		return true
	end
	return false
end

function SubrootC:touchpressed(id, x, y, dx, dy, pressure)
	local toolbox = self._toolbox
	local srContainer = toolbox:getSubrootContainer()
	if not srContainer or not srContainer:isRunning() then return false end

	local lx, ly, scaleX, scaleY = self:pointToWindow(x, y)

	if lx then
		srContainer:pushSubroot()
		srContainer.subroot:touchpressed(id, lx, ly, dx * scaleX, dy * scaleY, pressure)
		srContainer:popSubroot()
		return true
	end
	return false
end

function SubrootC:touchreleased(id, x, y, dx, dy, pressure)
	local toolbox = self._toolbox
	local srContainer = toolbox:getSubrootContainer()
	if not srContainer or not srContainer:isRunning() then return false end

	local lx, ly, scaleX, scaleY = self:pointToWindow(x, y)

	if lx then
		srContainer:pushSubroot()
		srContainer.subroot:touchreleased(id, lx, ly, dx * scaleX, dy * scaleY, pressure)
		srContainer:popSubroot()
		return true
	end
	return false
end

function SubrootC:update(dt)
	local toolbox = self._toolbox
	local srContainer = toolbox:getSubrootContainer()
	if not srContainer or not srContainer:isRunning() then return false end

	srContainer:pushSubroot()
	srContainer.subroot:update(dt)
	srContainer:popSubroot()
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
			local toolbox = c._toolbox
			local srContainer = toolbox:getSubrootContainer()
			if not srContainer or not srContainer:isRunning() then return false end

			srContainer:handleOnSubroot(handler, ...)
			return false
		end
	end
end

return SubrootC
