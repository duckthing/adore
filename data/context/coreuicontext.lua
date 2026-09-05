---@type AdoreInit
local Adore = require ""
local ShortcutContext = Adore.Resources("ShortcutContext")
local Vec2 = Adore.Common("Vec2")
local Signal = Adore.Common("Signal")

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

---Returns the currently focused Control if it's visible in the tree.
---If not, it gets unfocused, and returns nil.
---@param root RootNode
---@return Control? focused
local function ensureValidFocused(root)
	local focused = root:getFocusedControl()
	if focused and focused:isVisibleInTree() then
		return focused
	end
	return nil
end

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
		local root = context.root
		local focusMode = context.allowTabFocus
		if ensureValidFocused(root) -- Something is already focused
			or focusMode == "always" -- Can select something from nothing
			or (focusMode == "withModal" and #root._modalStack > 0) -- Can select when there's a modal
		then
			return context.root:uiSelectNext()
		end
		return false
	end,
	uiSelectPrevious = function(context)
		local root = context.root
		local focusMode = context.allowTabFocus
		if ensureValidFocused(root) -- Something is already focused
			or focusMode == "always" -- Can select something from nothing
			or (focusMode == "withModal" and #root._modalStack > 0) -- Can select when there's a modal
		then
			return context.root:uiSelectPrevious()
		end
		return false
	end,
	uiUnfocus = function(context)
		-- TODO: Default unfocus check is in shortcut action, while default focus check is in navigation method.
		-- Should these be moved together?

		local root = context.root
		if context.allowUnfocus then
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
		ensureValidFocused(context.root)
		return context.root:uiSelectUp()
	end,
	uiSelectDown = function(context)
		ensureValidFocused(context.root)
		return context.root:uiSelectDown()
	end,
	uiSelectLeft = function(context)
		ensureValidFocused(context.root)
		return context.root:uiSelectLeft()
	end,
	uiSelectRight = function(context)
		ensureValidFocused(context.root)
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

---@alias CoreUIContext.GrabFocusMode
---| "always" # Always allow grabbing focus of a Control
---| "withModal" # Only allow grabbing focus of a Control when a modal is pushed (ex. WindowPopup)
---| "never" # Grabbing focus when there is no Control focused is disallowed

---@param root RootNode
function CoreUIContext:new(root)
	CoreUIContext.super.new(self, actions, pressedKeybinds, releasedKeybinds, pressedGamepadBinds, releasedGamepadBinds)
	self.root = root
	self._priority = 1000

	---@type boolean # Does pressing Escape unfocus the UI?
	self.allowUnfocus = true
	---@type CoreUIContext.GrabFocusMode # Does pressing (Shift+)Tab focus the UI when there is no focus currently?
	self.allowTabFocus = "always"

	---@type Vec2 # Where the user started pressing from, in window space.
	---* Used for drag-and-drop
	---* Gets set to `(-1, -1)` when not used
	self._pressedPos = Vec2(-1, -1)
	---@type Control? # The Control the user began pressing on
	self._pressedControl = nil
	---@type Control? # The drag preview; set to the cursor position and will be destroyed afterwards
	self._dragPreview = nil
	---@type any # Data returned from the dragged Control
	self._dragData = nil
	---@type boolean # If the user is pressing down
	self._pressing = false
	---@type boolean # If the user is dragging
	self._dragging = false
	---@type number # [Default: `64`, which is 8^2] How far to move until we're considered dragging, squared
	self._distanceToDrag2 = 64

	---@type Signal # Fired when the user starts a drag, with (CoreUIContext, dragData, pressedControl)
	self.draggingStarted = Signal.new(self)
	---@type Signal # Fired when the user stops dragging, with (CoreUIContext, stopX, stopY, dragData, overControl)
	self.draggingEnded = Signal.new(self)
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

---@param control Control
---@param x number
---@param y number
---@return boolean
local function checkCanReceiveMouseInput(control, x, y)
	return control:canReceiveInput(true, x, y)
end

---Starts a drag operation
---@param dragData any
---@param dragPreview Control?
---@param fromControl Control?
function CoreUIContext:startDrag(dragData, dragPreview, fromControl)
	assert(not self._dragging, "Cannot start dragging while another drag operation is occurring")
	self._dragging = true
	self._dragData, self._pressedControl =
		dragData, fromControl

	if dragPreview then
		-- TODO: Make setting drag preview independent from this method
		self._dragPreview = dragPreview
		self.root:addChild(dragPreview)
	end

	self.root:uiUnfocus()
	self.draggingStarted:fire(self, dragData, fromControl)
end

---Stops dragging
---@param x number
---@param y number
---@param ontoControl Control?
function CoreUIContext:stopDrag(x, y, ontoControl)
	assert(self._dragging, "Can only stop dragging while currently dragging")
	local dragData = self._dragData
	self._dragging = false
	self._dragData = nil
	if dragData ~= nil and ontoControl and ontoControl:_canDropData(x, y, dragData) then
		-- Drop the data
		ontoControl:_dropData(x, y, dragData)
	end
	local preview = self._dragPreview
	if preview then
		-- Destroy the drag preview
		self._dragPreview = nil
		if preview._valid then
			preview:queueDestroy(true)
		end
	end
	self.draggingEnded:fire(self, x, y, ontoControl, dragData)
end

function CoreUIContext:mousemoved(x, y, dx, dy, isTouch)
	local root = self.root
	if not self._dragging then
		local pressedPos = self._pressedPos
		local pressedX, pressedY = pressedPos.x, pressedPos.y
		if pressedX >= 0 and ((x - pressedX) + (y - pressedY))^2 > self._distanceToDrag2 then
			-- Start dragging
			local pressedControl = self._pressedControl
			local data, preview
			if pressedControl then
				-- Set the data and preview
				data, preview = pressedControl:_getDragData()
				if preview then
					preview:setPosition(x, y)
				end
			end
			self:startDrag(data, preview, pressedControl)
		end
	else
		-- Dragging, move the preview
		local preview = self._dragPreview
		if preview then
			preview:setPosition(x, y)
		end
	end

	local rootViewport = root._viewport

	-- The RootNode might have an irregular Viewport (ex. fixed resolution, scaled pixels)
	-- All points should be relative to the Viewport and not the window
	local rx, ry = rootViewport:windowToViewportPoint(x, y)

	do
		-- Send to focused
		local focused = root._focusedControl
		if focused then
			local fMouseMoved = focused.mousemoved
			-- Instead of using the mouse variant of :canReceiveInput, do the check manually
			-- in case there is a Control that is clipping it
			if fMouseMoved and focused:canReceiveInput(false) and focused._mouseInputMode ~= "ignore" then
				-- Viewports in CanvasLayers all rely on the RootNode's Viewport, no matter what
				-- Make the points relative to the Viewport the Control belongs to
				local focusedX, focusedY = controlToLocal(rootViewport, focused, rx, ry)
				---@type boolean? # Was uiMouseEntered handled?
				local uiEnterOrLeftHandled = false

				-- Send mousemoved events to focused Control, even if there's no overlap with the Control
				local mouseMovedHandled = fMouseMoved(focused, focusedX, focusedY, dx, dy, isTouch)

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
	local newControl, nx, ny = root:getControlAtPoint(x, y, checkCanReceiveMouseInput, x, y)

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
		if ncMouseMoved and newControl:canReceiveInput(true, x, y) and ncMouseMoved(newControl, nx, ny, dx, dy, isTouch) then
			return self.sinkHandledInput
		end
	else
		-- Send to modal
		if modal then
			local mMouseMoved = modal.mousemoved
			if mMouseMoved and modal:canReceiveInput(true, x, y) then
				local modalX, modalY = controlToLocal(rootViewport, modal, rx, ry)

				if mMouseMoved(modal, modalX, modalY, dx, dy, isTouch) then
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
	if button == 1 then
		-- Set the starting press position
		self._pressedPos:iSetComponents(x, y)
		self._pressedControl = root._hoveredControl
		self._pressing = true
	end

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
	if button == 1 then
		-- Reset the starting press position
		self._pressedPos:iSetComponents(-1, -1)
		self._pressing = false
		self._pressedControl = nil
		if self._dragging then
			-- Stop dragging
			self:stopDrag(x, y, root._hoveredControl)
		end
	end

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
	local focused = ensureValidFocused(root)
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
