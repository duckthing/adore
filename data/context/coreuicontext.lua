---@type AdoreInit
local Adore = require ""
local ShortcutContext = Adore.Resources("ShortcutContext")

---CoreUIContext is used by the RootNode for default UI navigation. You shouldn't need to instance this.
---@class CoreUIContext: ShortcutContext
---@field super ShortcutContext
---@overload fun(root: RootNode): CoreUIContext
local CoreUIContext = ShortcutContext:extend()
CoreUIContext.CLASS_NAME = "CoreUIContext"
-- Send every Love2D event to this, so we can then send it to the focused UI element
CoreUIContext.HANDLERS = {
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

	mousefocus = true,
	postUpdate = true,
}

---@alias CoreUIContext.Action fun(context: CoreUIContext, isRepeat: boolean?): boolean?
---@alias CoreUIContext.ActionMap {[ShortcutContext.ActionName]: CoreUIContext.Action}

-- Create the UI navigation shortcuts
---@type CoreUIContext.ActionMap
local actions = {
	uiActivate = function(context, isRepeat)
		if not isRepeat then
			return context.root:uiActivate()
		end
	end,
	uiDeactivate = function(context)
		return context.root:uiDeactivate()
	end,

	uiSelectNext = function(context)
		return context.root:uiSelectNext()
	end,
	uiSelectPrevious = function(context)
		return context.root:uiSelectPrevious()
	end,
	uiUnfocus = function(context)
		-- TODO: Default unfocus check is in shortcut action, while default focus check is in navigation method.
		-- Should these be moved together?

		local root = context.root
		if root.allowUnfocus then
			-- Can unfocus Controls
			if root._focusedControl then
				-- A Control is focused; unfocus it
				return root:uiUnfocus()
			end
		end

		-- Close modals when trying to unfocus a non-existent Control
		---@type Popup?
		local modal = root._modalStack[#root._modalStack]
		if modal and modal._unfocusToClose then
			modal:close()
			return context.sinkHandledInput
		end

		return false
	end,

	uiSelectUp = function(context)
		return context.root:uiSelectUp()
	end,
	uiSelectDown = function(context)
		return context.root:uiSelectDown()
	end,
	uiSelectLeft = function(context)
		return context.root:uiSelectLeft()
	end,
	uiSelectRight = function(context)
		return context.root:uiSelectRight()
	end,
}

-- Shortcuts on a keyboard
---@type ShortcutContext.Keybinds
local pressedKeybinds = {
	normal = {
		space = "uiActivate",
		tab = "uiSelectNext",
		up = "uiSelectUp",
		down = "uiSelectDown",
		left = "uiSelectLeft",
		right = "uiSelectRight",
		escape = "uiUnfocus",
	},
	shift = {
		tab = "uiSelectPrevious",
	}
}
---@type ShortcutContext.Keybinds
local releasedKeybinds = {
	normal = {space = "uiDeactivate"}
}

-- Shortcuts on a gamepad
---@type ShortcutContext.GamepadBinds
local pressedGamepadBinds = {
	a = "uiActivate",
	dpup = "uiSelectUp",
	dpdown = "uiSelectDown",
	dpleft = "uiSelectLeft",
	dpright = "uiSelectRight",
}
---@type ShortcutContext.GamepadBinds
local releasedGamepadBinds = {
	a = "uiDeactivate"
}

---@param root RootNode
function CoreUIContext:new(root)
	CoreUIContext.super.new(self, actions, pressedKeybinds, releasedKeybinds, pressedGamepadBinds, releasedGamepadBinds)
	self.root = root
	self._priority = 1000
end

---Makes points relative to the Control's Viewport
---@param rootViewport Viewport
---@param control Control
---@param rootX integer
---@param rootY integer
local function controlToLocal(rootViewport, control, rootX, rootY)
	-- TODO: Find why checking `cViewport` for existing is necessary
	-- In Toolbox, removing a focused button caused `cViewport` to be nil
	local cViewport = control:getViewport()
	if cViewport ~= rootViewport and cViewport then
		-- Not under the RootNode's Viewport, transform it
		return cViewport:windowToViewportPoint(rootX, rootY)
	end
	-- Under the RootNode's Viewport, do nothing
	return rootX, rootY
end

function CoreUIContext:mousemoved(x, y, dx, dy, isTouch)
	local root = self.root
	local rootViewport = root._viewport

	-- The RootNode might have an irregular Viewport (ex. fixed resolution, scaled pixels)
	-- All points should be relative to the Viewport and not the window
	local rx, ry = rootViewport:windowToViewportPoint(x, y)

	do
		-- Send to focused
		local focused = root._focusedControl
		if focused then
			local fMouseMoved = focused.mousemoved
			if fMouseMoved and focused:canReceiveInput(true, x, y) then
				-- Viewports in CanvasLayers all rely on the RootNode's Viewport, no matter what
				-- Make the points relative to the Viewport the Control belongs to
				local focusedX, focusedY = controlToLocal(rootViewport, focused, rx, ry)
				---@type boolean? # Was uiMouseEntered handled?
				local uiEnterOrLeftHandled = false

				-- Send mousemoved events to focused Control, even if there's no overlap with the Control
				local mouseMovedHandled = fMouseMoved(focused, focusedX, focusedY)

				if focused:doesPointOverlap(focusedX, focusedY) then
					if not focused._hovered then
						-- Cursor just entered the element
						uiEnterOrLeftHandled = focused:uiMouseEntered(focusedX, focusedY)
						focused._hovered = true
					end
				else
					if focused._hovered then
						-- Cursor just left the element
						uiEnterOrLeftHandled = focused:uiMouseExited()
						focused._hovered = false
					end
				end

				if mouseMovedHandled or uiEnterOrLeftHandled then
					return self.sinkHandledInput
				end
			end
		end
	end

	-- Check if we're hovering a different Control
	local oldControl = root._hoveredControl
	local newControl, nx, ny = root:getControlAtPoint(x, y)

	if oldControl ~= newControl then
		-- If we're here, they're different
		root._hoveredControl = newControl
		if oldControl then
			oldControl:uiMouseExited()
		end

		if newControl then
			newControl:uiMouseEntered(nx, ny)
		end
	end

	-- Send to the new hovered control
	local modal = root._modalStack[#root._modalStack]
	if newControl then
		local ncMouseMoved = newControl.mousemoved
		-- The "new control" might be the same as the old one
		if ncMouseMoved and newControl:canReceiveInput(true, x, y) and ncMouseMoved(newControl, nx, ny) then
			return self.sinkHandledInput
		end
	else
		-- Send to modal
		if modal then
			local mMouseMoved = modal.mousemoved
			if mMouseMoved and modal:canReceiveInput(true, x, y) then
				local modalX, modalY = controlToLocal(rootViewport, modal, rx, ry)

				if mMouseMoved(modal, modalX, modalY) then
					return self.sinkHandledInput
				end
			end
		end
	end

	-- Check if there is a modal as well, as it should block ALL input
	return CoreUIContext.super.mousemoved(self, x, y, dx, dy, isTouch) or modal ~= nil
end

function CoreUIContext:mousepressed(x, y, button, isTouch, pressCount)
	local root = self.root
	local rootViewport = root._viewport

	local rx, ry = rootViewport:windowToViewportPoint(x, y)

	-- Send to hovered
	local hovered = root._hoveredControl
	if hovered then
		local hMousePressed = hovered.mousepressed
		if hMousePressed and hovered:canReceiveInput(true, x, y) then
			local hoveredX, hoveredY = controlToLocal(rootViewport, hovered, rx, ry)

			if hMousePressed(hovered, hoveredX, hoveredY, button, isTouch, pressCount) then
				return self.sinkHandledInput
			end
		end
	end

	do
		-- TODO: Is there a better way than having to look up twice?
		-- Send to something that has `mousepressed` and can receive mouse inputs
		local found, fx, fy = root:getControlAtPointWithMember(x, y, "mousepressed", true)
		if found and found ~= hovered then
			if found:mousepressed(fx, fy, button, isTouch, pressCount) then
				return self.sinkHandledInput
			end
		end
	end

	do
		-- Send to focused
		local focused = root._focusedControl
		if focused then
			local focusedX, focusedY = controlToLocal(rootViewport, focused, rx, ry)

			if not focused:doesPointOverlap(focusedX, focusedY) then
				-- Clicked out of bounds, release focus
				focused:releaseFocus()
				return self.sinkHandledInput
			end
		end
	end

	-- Send to modal
	local modal = root._modalStack[#root._modalStack]
	if modal then
		local mMousePressed = modal.mousepressed
		if mMousePressed and modal:canReceiveInput(true, x, y) then
			local modalX, modalY = controlToLocal(rootViewport, modal, rx, ry)

			if mMousePressed(modal, modalX, modalY, button, isTouch, pressCount) then
				return self.sinkHandledInput
			end
		end
	end

	-- Check if there is a modal as well, as it should block ALL input
	return CoreUIContext.super.mousepressed(self, x, y, button, isTouch, pressCount) or modal ~= nil
end

function CoreUIContext:mousereleased(x, y, button, isTouch, pressCount)
	local root = self.root
	local rootViewport = root._viewport

	local rx, ry = rootViewport:windowToViewportPoint(x, y)

	do
		-- Send to focused
		local focused = root._focusedControl
		if focused then
			local fMouseReleased = focused.mousereleased
			-- Instead of using the mouse variant of :canReceiveInput, do the check manually
			-- in case there is a Control that is clipping it
			if fMouseReleased and focused:canReceiveInput(false) and focused._mouseInputMode ~= "ignore" then
				local focusedX, focusedY = controlToLocal(rootViewport, focused, rx, ry)
				fMouseReleased(focused, focusedX, focusedY, button)
			end
		end
	end

	-- Send to modal
	local modal = root._modalStack[#root._modalStack]
	if modal then
		local mMouseReleased = modal.mousereleased
		if mMouseReleased and modal:canReceiveInput(true, x, y) then
			local modalX, modalY = controlToLocal(rootViewport, modal, rx, ry)
			if mMouseReleased(modal, modalX, modalY, button) then
				root:uiUnfocus()
				return self.sinkHandledInput
			end
		end
	end

	-- Send to hovered
	local hovered = root._hoveredControl
	if hovered then
		local hMouseReleased = hovered.mousereleased
		if hMouseReleased and hovered:canReceiveInput(true, x, y) then
			local hoveredX, hoveredY = controlToLocal(rootViewport, hovered, rx, ry)
			if hMouseReleased(hovered, hoveredX, hoveredY, button) then
				return self.sinkHandledInput
			end
		end
	end

	do
		-- TODO: Is there a better way than having to look up twice?
		-- Send to something that has `mousereleased` and can receive mouse inputs
		local found, foundX, foundY = root:getControlAtPointWithMember(x, y, "mousereleased", true)
		if found and found ~= hovered then
			if found:mousereleased(foundX, foundY, button) then
				return self.sinkHandledInput
			end
		end
	end

	-- Check if there is a modal as well, as it should block ALL input
	return CoreUIContext.super.mousereleased(self, x, y, button, isTouch, pressCount) or modal ~= nil
end

function CoreUIContext:wheelmoved(x, y)
	local mx, my = love.mouse.getPosition()
	local root = self.root

	local hovered, _, _ = root:getControlAtPointWithMember(mx, my, "wheelmoved", true)
	if hovered then
		local hWheelMoved = hovered.wheelmoved
		if hWheelMoved and hWheelMoved(hovered, x, y) then
			return self.sinkHandledInput
		end
	end

	return CoreUIContext.super.wheelmoved(self, x, y)
end

function CoreUIContext:mousefocus(inWindow)
	if not inWindow then
		-- When the mouse leaves the window, any hovered Control will lose its hovered status.
		local root = self.root
		local oldControl = root._hoveredControl
		if oldControl then
			oldControl:uiMouseExited()
			root._hoveredControl = nil
			return false -- TODO: Should mousefocus get sunk?
		end
	end

	return CoreUIContext.super.mousefocus(self, inWindow)
end

---Handle any other Love events by sending them to the focused Control
---@param event string
---@param ... unknown
---@return boolean
function CoreUIContext:_miscInput(event, ...)
	local root = self.root
	local focused = root._focusedControl
	if focused then
		local fMethod = focused[event]
		if fMethod and fMethod(focused, ...) then
			return self.sinkHandledInput
		end
	end

	-- Check if there is a modal as well, as it should block ALL input
	return CoreUIContext.super[event](self, ...) or root._modalStack[#root._modalStack] ~= nil
end

-- Add any missing handlers for the CoreUIContext (with :_miscInput())
for handler, _ in pairs(CoreUIContext.HANDLERS) do
	if not rawget(CoreUIContext, handler) then
		CoreUIContext[handler] = function(self, ...)
			return self:_miscInput(handler, ...)
		end
	end
end

return CoreUIContext
