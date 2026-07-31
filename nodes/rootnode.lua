---@type AdoreInit
local Adore = require("")
local Nodes = Adore.Nodes
local Resources = Adore.Resources

local Node = Nodes("Node")
local Control = Nodes("Control")
local Timer = Nodes("TimerNode")
local Tween = Resources("Tween")
local Viewport = Resources("Viewport")
local CoreUIContext = Resources("CoreUIContext")
local MainLoopContext = Resources("MainLoopContext")

local min, max = math.min, math.max

local _, shaderAssets = Adore.Loader.getCollection("ShaderLoader")

---INTERNAL! Don't use this!

---@alias RootNode.MouseMode
---| "unlocked"
---| "locked"
---| "centered"

---@class RootNode.Options: Viewport.Options
---@field hideSceneWarning boolean? # Pass `true` to hide the "no scene" warning
---@field drawControlDebug boolean? # Draw an outline around Controls without a DrawRequest

---@class RootNode: Node
---@field super Node
---@field focus fun(self:RootNode, focused: boolean): boolean
---@field mousefocus fun(self: RootNode, inWindow: boolean): boolean
---@field keypressed fun(self: RootNode, ...): boolean
---@field keyreleased fun(self: RootNode, ...): boolean
---@field textinput fun(self: RootNode, ...): boolean
---@field wheelmoved fun(self: RootNode, ...): boolean
---@field gamepadaxis fun(self: RootNode, ...): boolean
---@field gamepadpressed fun(self: RootNode, ...): boolean
---@field gamepadreleased fun(self: RootNode, ...): boolean
---@field joystickadded fun(self: RootNode, ...): boolean
---@field joystickaxis fun(self: RootNode, ...): boolean
---@field joystickhat fun(self: RootNode, ...): boolean
---@field joystickpressed fun(self: RootNode, ...): boolean
---@field joystickreleased fun(self: RootNode, ...): boolean
---@field joystickremoved fun(self: RootNode, ...): boolean
---@field touchmoved fun(self: RootNode, ...): boolean
---@field touchpressed fun(self: RootNode, ...): boolean
---@field touchreleased fun(self: RootNode, ...): boolean
---@overload fun(viewportOptions: RootNode.Options, defaultTheme: Theme): RootNode
local Root = Node:extend()
Root.CLASS_NAME = "Root"
Root.albedo = {1, 1, 1, 1}
Root._adorePersist = false
MainLoopContext.Root = Root

do
	local arr = Node.OVERRIDES_VIEWPORT
	arr[#arr+1] = Root
end

---@type number # The minimum distance that will be allowed for focusing adjacent; smaller distances won't focus
local SELECT_FOCUS_OFFSET = 0.1
local cheapEmit

---@type boolean # Used for Toolbox; does a RootNode exist yet?
local rootExistsAlready = false

---@param rootOptions RootNode.Options?
---@param defaultTheme Theme
function Root:new(rootOptions, defaultTheme)
	if Node._root ~= nil then
		error("RootNode was created more than once")
	end
	Root.super.new(self)

	---@type boolean # `true` if this RootNode is not embedded inside of Toolbox
	self.firstRoot = not rootExistsAlready
	rootExistsAlready = true

	self.name = "root"
	self._inTree = true
	self._ancestorsVisible = true
	self._ready = true
	self._layerIndex = 1
	Node._root = self

	---@type (fun(parent: Node?, ...): Node?)? # When reloading the current scene, what will be used?
	self.lastScene = nil
	---@type Node # The instanced Node from the scene; destroyed when reloading or switching scenes
	self._instancedScene = nil

	---@type number # What deltatime should be multiplied by before passed to `:update()`.
	---Important notes:
	---* If the game speed is high, it may step multiple times in one frame, depending on the Viewport's PhysicsSpeedMultiplier.
	---* If relying on the GameContext's `isJustPressed/Released`, you'll need to sink it with the second parameter.
	--- * Physics can step multiple times per `:update` at a high game speed.
	self.gameSpeed = 1
	---@type boolean # If :update() is called at all (see Node._pauseMode)
	self._paused = false


	---======== VIEWPORT
	do
		local windowW, windowH = love.graphics.getDimensions()
		---@type integer, integer # The passed dimensions into RootNode:resize(), which the Viewport tries to fit into
		self._windowW, self._windowH =
			(rootOptions and rootOptions.windowWidth) or windowW,
			(rootOptions and rootOptions.windowHeight) or windowH
	end

	-- We probably own the physics world if nil
	if rootOptions and rootOptions.physicsWorld and rootOptions.ownsPhysicsWorld == nil then
		rootOptions.ownsPhysicsWorld = true
	end

	---@type Viewport
	local viewport = Viewport(rootOptions)
	viewport:fitInto(self._windowW, self._windowH)
	viewport._adorePersist = false

	---Returns the safe area of the Viewport
	---@param viewport Viewport
	local function viewportGetSafeArea(viewport)
		local gx, gy, gw, gh = love.window.getSafeArea()
		local x, y = viewport:windowToViewportPoint(gx, gy)
		local w, h = viewport:windowToViewportPoint(gx + gw, gy + gh)

		return
			max(0, x),
			max(0, y),
			min(w, viewport._canvasW),
			min(h, viewport._canvasH)
	end
	viewport.getSafeArea = viewportGetSafeArea
	self._viewport = viewport

	---@type boolean # (CanvasLayer) If this RootNode should get post-processing applied
	self._applyParentProcessing = true
	---@type number, number # The calculated canvas scale
	self._canvasScaleW, self._canvasScaleH = 1, 1
	---@type number, number # The calculated canvas offset (to put it in the middle)
	self._canvasOffsetX, self._canvasOffsetY = 0, 0


	---======== QUEUES
	---@type table[]
	self.methodQueue1 = {}
	---@type table[]
	self.methodQueue2 = {}
	---@type boolean # Used for switching between queue 1 and 2
	self._firstQueueActive = true

	---@type table[] # Updated with the game speed
	self.gameTimerMethods = {}
	---@type table[] # Updated independent of the game speed
	self.realTimerMethods = {}

	---@type Tween[] # Tweens that are updated with the game speed
	self.gameTweens = {}
	---@type Tween[] # Tweens that are updated independent of the game speed
	self.realTweens = {}
	-- TODO: Should tweens/queued methods update their time based off if their Node is being updated?


	---======== DATA
	---@type integer, integer # The current mouse position relative to the Viewport
	self.mouseX, self.mouseY =
		0, 0
	---@type integer, integer # The mouse position in the last :update()
	self.lastMouseX, self.lastMouseY =
		0, 0
	---@type RootNode.MouseMode # How the mouse should behave. "centered" keeps track of all mouse movement.
	self._mouseMode = "unlocked"


	---======== CONTROL
	---@type Theme
	self._defaultTheme = defaultTheme
	---@type boolean # Does pressing Escape unfocus the UI?
	self.allowUnfocus = true
	---@type boolean # Does pressing (Shift+)Tab focus the UI when there is no focus currently?
	self.allowTabFocus = true

	---@type Control? # The current Control being hovered over
	self._hoveredControl = nil
	---@type Control? # The current Control that is focused. Can navigate around with this.
	self._focusedControl = nil
	---@type boolean # If we're currently activating a Control, outside of a mouse click.
	self._activatingControl = false
	---@type Control[] # The Control to send all input events to first. Stack, FILO.
	self._modalStack = {}
	---@type {[Control]: CanvasLayer | RootNode} # What CanvasLayer or RootNode is above the top-level Control
	self._controlTopLevelLayers = {}


	---======== LOGIC ORDER
	self._pauseMode = "pausable"
	---@type Node[] # The top-level Nodes with a process mode that is not "inherit"
	self._topLevelProcessors = {self}
	---@type (CanvasLayer | RootNode)[] # The layers that are drawn, in order from first drawn to last drawn
	self._canvasLayers = {self}
	---@type AudioListener2d? # The AudioListener2d, where audio is received relatively
	self._activeAudioListener = nil
	---@type boolean # If the AudioListener2d is nil, should audio be played relatively to the viewport transform?
	self._defaultRelativeAudio = true
	---@type number # If using the default relative audio, what's the Z axis?
	self._defaultRelativeAudioZ = 0


	---======== INPUT ORDER
	---@type Context[]
	self._contextStack = {}
	---@type CoreUIContext
	self._coreUIContext = CoreUIContext(self)
	---@type MainLoopContext
	self._mainLoopContext = MainLoopContext(self)

	---@type Context[] # When `:resetInputContexts()` is called, which Contexts will be pushed?
	self._defaultContexts = {
		self._mainLoopContext,
		self._coreUIContext,
	}

	---The default Love callbacks that will be used when `:addMissingCallbacks()` is called.
	---If not found, it will create a default wrapper that does nothing.
	---@type {[string]: fun(self: RootNode, ...): boolean?}
	self._defaultCallbacks = {}

	self:resetInputContexts()

	if not rootOptions or not rootOptions.hideSceneWarning then
		-- Create a Timer that warns if a scene hasn't been loaded
		local timer = Timer(1, true, true)
		timer.completed:connectCallable(function()
			print("[Adore.Root] No scene after 1 second; did you forget to call 'root:changeSceneTo()'?")
			print("[Adore.Root] Disable this message by setting 'hideSceneWarning' to true in the Root initialization")
			timer:queueDestroy(true)
		end, true)
		-- Add the timer as the instanced scene (so changing scenes will destroy it)
		self._instancedScene = timer
		self:addChild(timer)
	end

	if rootOptions and rootOptions.drawControlDebug then
		-- Gives all Controls without a DrawRequest an outline
		defaultTheme:setDrawable(Control, nil, Resources("DrawRequest.DebugBox")())
	end
end

---The check for determining where top-level processors go; lower priority is earlier in the array
---@param a Node
---@param b Node
---@return boolean
local function tlpSorterCheck(a, b)
	return a._processPriority < b._processPriority
end

---Sorts the top-level processor array; does NOT run anything!
---@param arr Node[]
local function sortTopLevelProcessorArray(arr)
	-- Remove any processors that were destroyed
	for i = #arr, 1, -1 do
		if not arr[i]._valid then
			table.remove(arr, i)
		end
	end

	-- Sort the remaining ones
	table.sort(arr, tlpSorterCheck)
end

---This is where the Root actually draws the scene
function Root:drawLayer()
	self:_beforeDraw()
	self:_drawChildren()
	self:_afterDraw()
end

---Reloads the current scene
function Root:reloadCurrentScene()
	if self.lastScene then
		self:changeSceneTo(self.lastScene)
	end
end

---Changes the scene to the PackedScene/SceneFactory by calling :instantiate() on it.
---Has the following effects on the game:
---* Resets the pause mode and game speed
---* Resets all queued methods
---* Resets pushed input contexts to their default state
---@param constructor SceneFactory | SceneFunction
function Root:changeSceneTo(constructor)
	local makeLastScene = true
	if type(constructor) == "table" then
		if not constructor.IS_NODE then
			-- It's a SceneFactory, turn it into a function
			constructor = constructor:asSceneFunction()
		else
			-- We got a Node?
			---@cast constructor Node
			if constructor._inTree then
				-- It's already in the tree, do nothing
				print("[RootNode:changeSceneTo] Passed a Node which was already in the scene; doing nothing")
				return
			end

			-- Add it to the tree later
			local node = constructor
			constructor = function() return node end
			makeLastScene = false
		end
	end
	---@cast constructor SceneFunction

	self:uiUnfocus()
	while self:popControlModal() do end

	if self._instancedScene then
		-- Destroy the old scene
		self._instancedScene:forceDestroy(true)
		self._instancedScene = nil
	end

	-- Reset to a playable state
	self:resetInputContexts()
	self:setPauseMode("pausable")
	self.gameSpeed = 1
	do
		local albedo = self.albedo
		albedo[1], albedo[2], albedo[3], albedo[4] =
			1, 1, 1, 1
	end

	if makeLastScene then
		self.lastScene = constructor
	else
		self.lastScene = nil
	end

	-- Clear the queued methods
	for i = 1, 4 do
		local queue = nil

		-- Ugly but it works
		if i == 1 then
			queue = self.methodQueue1
		elseif i == 2 then
			queue = self.methodQueue2
		elseif i == 3 then
			queue = self.gameTimerMethods
		else
			queue = self.realTimerMethods
		end

		-- Clear this queue
		for j = #queue, 1, -1 do
			queue[j] = nil
		end
	end

	self:resume()

	local result = constructor(self)
	if result then
		-- Set the new instanced scene
		self._instancedScene = result
		-- Add it to the Root if it's not already
		if result.parent ~= self then
			self:addChild(result)
		end
	end
end

---Sends an event to a Context, and returns `true` if any of them handled it.
---@param event any
---@param ... unknown
---@return boolean handled
function Root:isContextHandled(event, ...)
	local stack = self._contextStack

	for i = #stack, 1, -1 do
		local context = stack[i]
		if context.HANDLERS[event] then
			-- Context can handle this
			if context[event](context, ...) then
				-- Context DID handle this, return true
				return true
			end
		end
	end

	-- No context in this stack handled this
	return false
end

---Resets the Context stack to the default state.
---This means there would only be `CoreUIContext` in the stack.
---Called automatically when changing scenes.
function Root:resetInputContexts()
	local stack = self._contextStack
	for j = #stack, 1, -1 do
		stack[j]:pop()
	end

	local defaults = self._defaultContexts
	for i = 1, #defaults do
		defaults[i]:push()
	end
end

---Focuses a Control; pass in nil to unfocus something
---@param control Control?
---@param isMouse boolean
function Root:focusOnControl(control, isMouse)
	local oldFocused = self._focusedControl
	if oldFocused then
		-- Unfocus the old Control
		oldFocused:uiFocusLost()
		self._focusedControl = nil
	end

	if control then
		self._focusedControl = control
		control:uiFocused(isMouse)
	end
end

---Unfocuses the currently focused control. Like pressing Escape.
---@return boolean handled
function Root:uiUnfocus()
	local oldFocused = self._focusedControl
	if oldFocused then
		oldFocused:uiFocusLost()
		self._focusedControl = nil
		-- Return `handled` if this Control could receive input
		-- If this Control was hidden, it should not be handled
		return oldFocused:canReceiveInput(false)
	end
	return false
end

---Called :uiActivate() on a focused Control
---@return boolean handled
function Root:uiActivate()
	if not self._activatingControl then
		local focused = self._focusedControl
		if focused then
			if focused:canReceiveInput(false) then
				-- This Control can receive input
				focused:uiActivate()
				self._activatingControl = true
				return true
			end
		end
	end
	return false
end

---Called :uiDeactivate() on a focused Control
---@return boolean handled
function Root:uiDeactivate()
	if self._activatingControl then
		local focused = self._focusedControl
		if focused then
			focused:uiDeactivate()
		end
		-- Outside, in case we're not focusing something anymore
		self._activatingControl = false
		return true
	end
	return false
end

---@param node Node
local function isControl(node) return node:is(Control) end

---@param node Control
local function forEachCanFocus(node)
	if node:canFocus(false) and node:canReceiveInput(false) then return node end
end

---Attempts to select the "next" Control that can be focused. Like pressing Tab.
---@return boolean handled
function Root:uiSelectNext()
	if self._activatingControl then return false end

	local oldFocused = self._focusedControl
	if not oldFocused then
		-- Missing a Control to navigate from, select the first Control found
		if not self.allowTabFocus then
			-- Navigation without an existing element is disabled
			return false
		else
			-- Pick the first element
			for control, _ in pairs(self._controlTopLevelLayers) do
				local result = control:traverseDownwards(forEachCanFocus, isControl)
				if result then
					result:grabFocus(false)
					return true
				end
			end
			return false
		end
	else
		-- Navigate from an existing Control

		---@cast oldFocused Control
		---@type Control?
		local result = nil

		do
			local handled, foundNode = oldFocused:uiSelectNext()
			result = foundNode
		end

		if not result then
			-- Go down from the old focused Control
			result = oldFocused:traverseDownwards(forEachCanFocus, function(node) return node ~= oldFocused and isControl(node) end)
		end

		if not result then
			-- Go to the highest node of the top-level Control and go forwards
			-- ...but do not refocus the old focused Control
			local startPoint = oldFocused._topLevelNode.parent
			if startPoint then
				result = startPoint:traverseDownExcludeSelf(forEachCanFocus, function(node) return node ~= oldFocused and isControl(node) end)
			end
		end

		if result then
			if result ~= oldFocused then
				result:grabFocus(false)
			end
			return true
		end
	end
	return false
end

---Attempts to select the "previous" Control that can be focused. Like pressing Shift + Tab.
---@return boolean handled
function Root:uiSelectPrevious()
	if self._activatingControl then return false end

	local oldFocused = self._focusedControl
	if not oldFocused then
		-- Missing a Control to navigate from, select the first Control found
		if not self.allowTabFocus then
			-- Navigation without an existing element is disabled
			return false
		else
			-- Pick the first element
			for control, _ in pairs(self._controlTopLevelLayers) do
				local result = control
					:getDeepestNode()
					:traverseUpwards(function(node) return (node ~= oldFocused and node:canFocus(false) and node:canReceiveInput(false) and node) or nil end, isControl)
				if result then
					result:grabFocus(false)
					return true
				end
			end
			return false
		end
	else
		-- Navigate from an existing Control

		---@cast oldFocused Control
		---@type Control?
		local result = nil

		do
			local handled, foundNode = oldFocused:uiSelectPrevious()
			result = foundNode
		end

		if not result then
			-- Go upwards from the old focus
			result = oldFocused
				:traverseUpwards(function(node) return (node ~= oldFocused and node:canFocus(false) and node:canReceiveInput(false) and node) or nil end, isControl)
		end

		if not result then
			-- Go to the farthest node of the top-level Control and go in reverse
			-- ...but do not refocus the old focused Control
			if oldFocused._topLevelNode.parent then
				result = oldFocused._topLevelNode.parent
					:getDeepestNode()
					:traverseUpwards(function(node) return (node ~= oldFocused and node:canFocus(false) and node:canReceiveInput(false) and node) or nil end, isControl)
			end
		end

		if result and result ~= oldFocused then
			result:grabFocus(false)
			return true
		end
	end
	return false
end

---Attempts to select the Control above the currently focused Control that can be focused. Like pressing Up.
---@return boolean handled
function Root:uiSelectUp()
	if self._activatingControl then return false end

	local oldFocused = self._focusedControl
	if not oldFocused then return false end
	---@type Control?
	local result = nil

	do
		local handled, foundNode = oldFocused:uiSelectUp()
		result = foundNode
	end

	if not result then
		-- Go through the shash and pick the closest element to the top of this Control
		---@type Control?
		local closestControl = nil
		local shash = oldFocused:getViewport()._controlShash
		local closestY = math.huge

		local largestAxis = max(self:getViewportSize())

		local x = oldFocused._localContentRect.x
		local y = oldFocused._localContentRect.y - largestAxis
		local w = oldFocused._localContentRect.w
		local h = largestAxis - SELECT_FOCUS_OFFSET

		---@param control Control
		shash:each(x, y, w, h, function(control)
			if control:canFocus(false) and control:canReceiveInput(false) and control ~= oldFocused then
				local diff = oldFocused._localContentRect.y - control._localContentRect.y
				if diff < closestY then
					closestControl = control
					closestY = diff
				end
			end
		end)

		result = closestControl
	end

	if result and result ~= oldFocused then
		result:grabFocus(false)
		return true
	end
	return false
end

---Attempts to select the Control below the currently focused Control that can be focused. Like pressing Down.
---@return boolean handled
function Root:uiSelectDown()
	if self._activatingControl then return false end

	local oldFocused = self._focusedControl
	if not oldFocused then return false end
	---@type Control?
	local result = nil

	do
		local handled, foundNode = oldFocused:uiSelectDown()
		result = foundNode
	end

	if not result then
		-- Go through the shash and pick the closest element to the bottom of this Control
		---@type Control?
		local closestControl = nil
		local shash = oldFocused:getViewport()._controlShash
		local closestY = math.huge

		local largestAxis = max(self:getViewportSize())

		local x = oldFocused._localContentRect.x
		local y = oldFocused._localContentRect.y + oldFocused._localContentRect.h + SELECT_FOCUS_OFFSET
		local w = oldFocused._localContentRect.w
		local h = largestAxis

		---@param control Control
		shash:each(x, y, w, h, function(control)
			if control:canFocus(false) and control:canReceiveInput(false) and control ~= oldFocused then
				local diff = control._localContentRect.y - oldFocused._localContentRect.y
				if diff < closestY then
					closestControl = control
					closestY = diff
				end
			end
		end)

		result = closestControl
	end

	if result and result ~= oldFocused then
		result:grabFocus(false)
		return true
	end
	return false
end

---Attempts to select the Control to the left of the currently focused Control that can be focused. Like pressing Left.
---@return boolean handled
function Root:uiSelectLeft()
	if self._activatingControl then return false end

	local oldFocused = self._focusedControl
	if not oldFocused then return false end
	---@type Control?
	local result = nil

	do
		local handled, foundNode = oldFocused:uiSelectLeft()
		result = foundNode
	end

	if not result then
		-- Go through the shash and pick the closest element to the left of this Control
		---@type Control?
		local closestControl = nil
		local shash = oldFocused:getViewport()._controlShash
		local closestX = math.huge

		local largestAxis = max(self:getViewportSize())

		local x = oldFocused._localContentRect.x - largestAxis
		local y = oldFocused._localContentRect.y
		local w = largestAxis - SELECT_FOCUS_OFFSET
		local h = oldFocused._localContentRect.h

		---@param control Control
		shash:each(x, y, w, h, function(control)
			if control:canFocus(false) and control:canReceiveInput(false) and control ~= oldFocused then
				local diff = oldFocused._localContentRect.x - control._localContentRect.x
				if diff < closestX then
					closestControl = control
					closestX = diff
				end
			end
		end)

		result = closestControl
	end

	if result and result ~= oldFocused then
		result:grabFocus(false)
		return true
	end
	return false
end

---Attempts to select the Control to the right of the currently focused Control that can be focused. Like pressing Right.
---@return boolean handled
function Root:uiSelectRight()
	if self._activatingControl then return false end

	local oldFocused = self._focusedControl
	if not oldFocused then return false end
	---@type Control?
	local result = nil

	do
		local handled, foundNode = oldFocused:uiSelectLeft()
		result = foundNode
	end

	if not result then
		-- Go through the shash and pick the closest element to the right of this Control
		---@type Control?
		local closestControl = nil
		local shash = oldFocused:getViewport()._controlShash
		local closestX = math.huge

		local largestAxis = max(self:getViewportSize())

		local x = oldFocused._localContentRect.x + oldFocused._localContentRect.w + SELECT_FOCUS_OFFSET
		local y = oldFocused._localContentRect.y
		local w = largestAxis
		local h = oldFocused._localContentRect.h

		---@param control Control
		shash:each(x, y, w, h, function(control)
			if control:canFocus(false) and control:canReceiveInput(false) and control ~= oldFocused then
				local diff = control._localContentRect.x - oldFocused._localContentRect.x
				if diff < closestX then
					closestControl = control
					closestX = diff
				end
			end
		end)

		result = closestControl
	end

	if result and result ~= oldFocused then
		result:grabFocus(false)
		return true
	end
	return false
end

---Queues a method to be called when not busy, which is usually before the end of `:update`.
---If you queue a method in `:draw`, it won't take effect until the next frame.
---You can queue any function if `node` is `false` or `nil`.
---@param node Node?
---@param method fun(self: unknown, ...: unknown)
---@param ... unknown
---@overload fun(self: RootNode, node: false?, method: function, ...)
function Root:queue(node, method, ...)
	local queue = (self._firstQueueActive and self.methodQueue1) or self.methodQueue2
	queue[#queue+1] = {node or false, method, ...}
end

---Queues a method to be called after a certain amount of time, depending on the game's speed.
---You can queue any function if `node` is `false` or `nil`.
---@param duration number
---@param node Node
---@param method fun(self: unknown, ...: unknown)
---@param ... unknown
---@overload fun(self: RootNode, duration: number, node: false?, method: function, ...)
function Root:queueAfterGameTime(duration, node, method, ...)
	local queue = self.gameTimerMethods
	queue[#queue+1] = {duration, node or false, method, ...}
end

---Queues a method to be called after a certain amount of time, depending on the real time passed.
---You can queue any function if `node` is `false` or `nil`.
---@param duration number
---@param node Node
---@param method fun(self: unknown, ...: unknown)
---@param ... unknown
---@overload fun(self: RootNode, duration: number, node: false?, method: function, ...)
function Root:queueAfterRealTime(duration, node, method, ...)
	local queue = self.realTimerMethods
	queue[#queue+1] = {duration, node or false, method, ...}
end

---Inserts a Node with a special `_pauseMode` into the top-level processors array
---@param node Node
function Root:insertTopLevelProcess(node)
	if node._pauseMode == "inherit" then return end
	for i = 1, #self._topLevelProcessors do
		if self._topLevelProcessors[i] == node then
			return
		end
	end
	self._topLevelProcessors[#self._topLevelProcessors+1] = node
	sortTopLevelProcessorArray(self._topLevelProcessors)
end

---Removes a Node (with a special `_pauseMode`) from the top-level processors array
---@param node Node
function Root:removeTopLevelProcess(node)
	for i = 1, #self._topLevelProcessors do
		if self._topLevelProcessors[i] == node then
			table.remove(self._topLevelProcessors, i)
			return
		end
	end
end

---Sets the Theme used at the top-level of all Controls.
---@param theme Theme
function Root:setDefaultTheme(theme)
	self._defaultTheme = theme
	self:emit("_eOnThemeChanged", theme)
end

function Root:_beforeDraw()
	love.graphics.push("all")
	love.graphics.origin()
	love.graphics.applyTransform(self._viewport._viewportTransform)
end

function Root:_afterDraw()
	love.graphics.pop()
end

function Root:_eAncestorViewportChanged()
	-- Do nothing; this emit should not get called at all
end

---Converts a window point to a viewport point.
---The viewport may be offset and scaled, which is why this method is required.
---@param x integer
---@param y integer
---@return integer viewportX
---@return integer viewportY
function Root:screenToViewportPoint(x, y)
	return self._viewport:windowToViewportPoint(x, y)
end

---Converts a viewport point into a window point.
---The viewport may be offset and scaled, which is why this method is required.
---@param x integer
---@param y integer
---@return integer screenX
---@return integer screenY
function Root:viewportToScreenPoint(x, y)
	return self._viewport:viewportToWindowPoint(x, y)
end

---Converts a viewport point into a world point. Useful for converting a mouse position into the world.
---@param x number
---@param y number
---@return number worldX
---@return number worldY
function Root:viewportToWorldPoint(x, y)
	return self._viewport:getCanvasTransform():inverseTransformPoint(x, y)
end

---Converts a world point into a viewport point. Useful for converting an object's position into a UI point.
---@param x number
---@param y number
---@return number screenX
---@return number screenY
function Root:worldToViewportPoint(x, y)
	return self._viewport:getCanvasTransform():transformPoint(x, y)
end

---Gets the default Theme used for all Controls
---@return Theme
function Root:getDefaultTheme()
	return self._defaultTheme
end

---Returns the Viewport
---@return Viewport
function Root:getViewport()
	return self._viewport
end

---Returns the Viewport dimensions
---@return integer
---@return integer
function Root:getViewportSize()
	return self._viewport:getDimensions()
end

---Returns the window-relative mouse position that is used for processing.
---If you want to get the mouse position in the world, use `self:getViewport():getWorldMousePosition()`
---@return integer x
---@return integer y
function Root:getMousePosition()
	return self.mouseX, self.mouseY
end

---Returns how much the mouse moved since the last :update()
---@return integer
---@return integer
function Root:getMouseMovement()
	return self.mouseX - self.lastMouseX, self.mouseY - self.lastMouseY
end

---Sets the mouse mode. "centered" puts the mouse in the center and keeps track of all movement.
---@param mode RootNode.MouseMode
function Root:setMouseMode(mode)
	mode = mode or "unlocked"
	self._mouseMode = mode
	love.mouse.setGrabbed(mode ~= "unlocked")
	love.mouse.setRelativeMode(mode == "centered")
end

local deepestDepth = -math.huge
local deepestLayer = -math.huge
local deepestElement = nil

---@param obj Control
---@param mouseX integer
---@param mouseY integer
local function shashForEachControl(obj, mouseX, mouseY)
	if obj._visible then
		---@type CanvasLayer
		local layerNode = Node._root._controlTopLevelLayers[obj._topLevelNode]
		if layerNode == nil then return end

		-- Only continue if the current layer is equal or greater than the deepest layer depth
		-- TODO: Remove layer depth? The loop already starts from the highest layer
		local layerDepth = layerNode._layerIndex
		-- if layerDepth < deepestLayer then return end

		local objDepth = obj._depth

		if objDepth > deepestDepth then
			-- Found the new deepest object
			if obj:canReceiveInput(true, mouseX, mouseY) then
				deepestDepth = objDepth
				deepestLayer = layerDepth
				deepestElement = obj
			end
		end
	end
end


---@param obj Control
---@param mouseX integer
---@param mouseY integer
---@param check fun(control: Control, ...): boolean
---@param ... unknown
local function shashForEachControlWithCheck(obj, mouseX, mouseY, check, ...)
	if obj._visible then
		---@type CanvasLayer
		local layerNode = Node._root._controlTopLevelLayers[obj._topLevelNode]
		if layerNode == nil then return end

		-- Only continue if the current layer is equal or greater than the deepest layer depth
		-- TODO: Remove layer depth? The loop already starts from the highest layer
		local layerDepth = layerNode._layerIndex
		-- if layerDepth < deepestLayer then return end

		local objDepth = obj._depth

		if objDepth > deepestDepth then
			-- Found the new deepest object
			-- print("woah", obj, obj:canReceiveInput(true, mouseX, mouseY), obj:doesPointOverlap(mouseX, mouseY))
			if check(obj, ...) and obj:canReceiveInput(true, mouseX, mouseY) and obj:doesPointOverlap(mouseX, mouseY) then
				deepestDepth = objDepth
				deepestLayer = layerDepth
				deepestElement = obj
			end
		end
	end
end

---@param obj Control
---@param mouseX integer
---@param mouseY integer
---@param member string
local function shashForEachWithMember(obj, mouseX, mouseY, member)
	if obj._visible and obj[member] then
		---@type CanvasLayer
		local layerNode = Node._root._controlTopLevelLayers[obj._topLevelNode]
		if layerNode == nil then return end

		-- Only continue if the current layer is equal or greater than the deepest layer depth
		local layerDepth = layerNode._layerIndex
		if layerDepth < deepestLayer then return end

		local objDepth = obj._depth

		if objDepth > deepestDepth then
			-- Found the new deepest object
			if obj:canReceiveInput(false, mouseX, mouseY) then
				deepestDepth = objDepth
				deepestLayer = layerDepth
				deepestElement = obj
			end
		end
	end
end

local function noop() return true end

---Returns the highest Control at a certain **screen** point.
---@param x integer
---@param y integer
---@param check (fun(control: Control, ...): boolean)?
---@param ... unknown # These are sent into the check function
---@return Control?
---@return integer? px # The local X coordinate for the Control
---@return integer? py # The local Y coordinate for the Control
function Root:getControlAtPoint(x, y, check, ...)
	deepestLayer = -math.huge
	deepestDepth = -math.huge
	deepestElement = nil

	-- Goes from the highest layer to the lowest
	-- If at any point we find a Control, its the highest one, and we can break

	local rootViewport = self._viewport
	local tx, ty = rootViewport:windowToViewportPoint(x, y)
	local fx, fy = nil, nil

	local modal = self._modalStack[#self._modalStack]
	if modal then
		-- If there's a modal, we only check the Viewport that it is in
		local viewport = modal:getViewport()
		local lx, ly = tx, ty
		if viewport ~= rootViewport then
			---@diagnostic disable-next-line: need-check-nil
			lx, ly = viewport:windowToViewportPoint(tx, ty)
			---@cast viewport Viewport
		end
		local shash = viewport._controlShash
		shash:each(lx, ly, 1, 1, shashForEachControlWithCheck, lx, ly, check or noop, ...)
		if deepestElement then
			return deepestElement, lx, ly
		else
			return
		end
	end

	for i = #self._canvasLayers, 1, -1 do
		-- Check all layers for the best Control
		local layer = self._canvasLayers[i]
		local viewport = layer._viewport
		local lx, ly = tx, ty
		if viewport ~= rootViewport then
			lx, ly = viewport:windowToViewportPoint(tx, ty)
		end
		local shash = viewport._controlShash
		shash:each(lx, ly, 1, 1, shashForEachControlWithCheck, lx, ly, check or noop, ...)

		if deepestElement then
			fx, fy = lx, ly
			break
		end
	end

	return deepestElement, fx, fy
end

---Returns the highest Control at a certain point that has 'member'.
---@param x integer
---@param y integer
---@param member string
---@return Control?
---@return integer? px # The local X coordinate for the Control
---@return integer? py # The local Y coordinate for the Control
function Root:getControlAtPointWithMember(x, y, member)
	deepestDepth = -math.huge
	deepestElement = nil

	local rootViewport = self._viewport
	local tx, ty = rootViewport:windowToViewportPoint(x, y)
	local fx, fy = nil, nil

	for i = #self._canvasLayers, 1, -1 do
		local layer = self._canvasLayers[i]
		local viewport = layer:getViewport()
		---@cast viewport Viewport
		local shash = viewport._controlShash
		local lx, ly = tx, ty
		if viewport ~= rootViewport then
			lx, ly = viewport:windowToViewportPoint(tx, ty)
		end
		shash:each(lx, ly, 1, 1, shashForEachWithMember, lx, ly, member)

		if deepestElement then
			fx, fy = lx, ly
			break
		end
	end

	return deepestElement, fx, fy
end

---Pushes the Control to the focused stack. The Control at the top receives all input events first.
---@param control Control
function Root:pushControlModal(control)
	if not control._pushedAsModal then
		-- Add it to the stack
		control._pushedAsModal = true
		self._modalStack[#self._modalStack+1] = control

		-- Unfocus and unhover the last element
		if self._hoveredControl then
			self._hoveredControl:uiMouseExited()
		end

		if self._focusedControl then
			control._previousFocused = self._focusedControl
			self._focusedControl:releaseFocus()
		end
	end
end

---Pops the Control off the top of the stack.
---Returns whatever was popped; `nil` is returned if the stack is empty.
---@param control Control?
---@return Control? poppedModal
function Root:popControlModal(control)
	if not control then
		control = self._modalStack[#self._modalStack]
	end

	if control and control._pushedAsModal then
		control._pushedAsModal = false
		local found = -1
		local stack = self._modalStack

		-- Find the index
		for i = #stack, 1, -1 do
			if stack[i] == control then
				found = i
				break
			end
		end

		-- If the index was found, we pop it.
		if found ~= -1 then
			table.remove(stack, found)
		end

		-- Focus the last element before this modal was pushed
		if control._previousFocused then
			control._previousFocused:grabFocus(false)
			control._previousFocused = nil
		end
	end

	return control
end

local RootTween = {}

---Creates a Tween that the Root updates while the game is unpaused with the game speed.
---Pass in `true` to make this Tween run regardless of the pause state or game speed.
---
---When creating a Tween in the Root, it won't be removed when a Node is. Use `Node:createTween()` or `tween:bindNode(node)`.
---@param realTime boolean?
---@return Tween
function Root:createTween(realTime)
	local tween = Tween.new()
	tween.play = RootTween.play
	tween.stop = RootTween.stop
	tween._realTime = realTime or false
	return tween
end

function RootTween:play()
	local wasRunning = self:isRunning()
	Tween.play(self)
	if not wasRunning and self:isRunning() then
		local list = (self._realTime and Node._root.realTweens) or Node._root.gameTweens
		list[#list+1] = self
	end
end

function RootTween:stop()
	if self:isRunning() then
		Tween.stop(self)
		local list = (self._realTime and Node._root.realTweens) or Node._root.gameTweens
		for i = 1, #list do
			if list[i] == self then
				table.remove(list, i)
				return
			end
		end
	end
end

---@type Node[]
local parents = {}
---@type integer[]
local childIndices = {}

---Similar to Node:emit(), but without tail calls
---@param start Node
---@param eventName string
---@param ... unknown
function cheapEmit(start, eventName, ...)
	parents[1] = start
	childIndices[1] = 1

	while #parents > 0 do
		local i = #parents
		local parent = parents[i]
		local childIndex = childIndices[i]
		local child = parent.children[childIndex]

		if not child then
			-- Child doesn't exist, go up one level
			parents[i] = nil
			childIndices[i] = nil
		else
			-- Child exists
			local method = child[eventName]
			if method and method(child, ...) then
				-- Method exists and returned true, exit
				break
			end

			if #child.children > 0 then
				-- Add this child to the array
				parents[i + 1] = child
				childIndices[i + 1] = 1
			end

			childIndices[i] = childIndex + 1
		end
	end

	for i = #parents, 1, -1 do
		parents[i] = nil
		childIndices[i] = nil
	end
end

function Root:emit(eventName, ...)
	cheapEmit(self, eventName, ...)
end

---Returns `true` if the `node` is running. If `node` is nil, the `RootNode` will be checked instead.
---@param node Node?
---@return boolean running
function Root:isRunning(node)
	if not node then node = self end
	local paused = self._paused
	local allowedMode = (paused and "whenPaused") or "pausable"

	-- Iterate through all parents
	-- If none of the parents are guaranteed to run, return false
	local currNode = node
	while currNode do
		local pauseMode = currNode._pauseMode
		if pauseMode == "inherit" then
			-- The parent handles processing
			currNode = currNode.parent
		elseif pauseMode == "always" or pauseMode == allowedMode then
			-- This pause mode allows running
			return true
		else
			-- This pause mode disallows running right now
			return false
		end
	end

	-- All parents are "inheriting", but there's no ancestor that is running
	-- Return false
	return false
end

---Pauses the game. Counterpart to `RootNode:resume()`.
function Root:pause()
	if self._paused then return end
	self._paused = true

	-- Only tell the processors which rely on the RootNode's pause status
	for i = 1, #self._topLevelProcessors do
		local tl = self._topLevelProcessors[i]
		local mode = tl._pauseMode
		if mode == "pausable" then
			tl:_pauseStatusChanged(true)
		elseif mode == "whenPaused" then
			tl:_pauseStatusChanged(false)
		end
	end
end

---Resumes the game. Counterpart to `RootNode:pause()`.
function Root:resume()
	if not self._paused then return end
	self._paused = false

	-- Only tell the processors which rely on the RootNode's pause status
	for i = 1, #self._topLevelProcessors do
		local tl = self._topLevelProcessors[i]
		local mode = tl._pauseMode
		if mode == "pausable" then
			tl:_pauseStatusChanged(false)
		elseif mode == "whenPaused" then
			tl:_pauseStatusChanged(true)
		end
	end
end

-- local appleCakeProfileRootUpdate
-- local appleCakeProfileRootPostUpdate
-- local appleCakeProfileMem = 0

---The default handler for `love.update`.
---Runs all the game logic by calling `:update()` on Nodes underneath.
---@param originalDelta number
function Root:update(originalDelta)
	-- appleCakeProfileMem = appleCakeProfileMem + originalDelta
	-- appleCakeProfileRootUpdate = AppleCake.profile("Root:update", nil, appleCakeProfileRootUpdate)
	-- Scene tree is updated under `MainLoopContext:update()`
	self:isContextHandled("update", originalDelta)
	-- appleCakeProfileRootUpdate:stop()
	-- appleCakeProfileRootPostUpdate = AppleCake.profile("Root:update(Post)", nil, appleCakeProfileRootPostUpdate)
	self:isContextHandled("postUpdate")
	-- appleCakeProfileRootPostUpdate:stop()
	-- if appleCakeProfileMem > 0.1 then
	-- 	AppleCake.countMemory()
	-- 	appleCakeProfileMem = 0
	-- end
end

-- local appleCakeProfileDTV

---@param modalStack Popup[]
local function drawModals(modalStack)
	for i = #modalStack, 1, -1 do
		local popup = modalStack[i]
		if popup._drawOnTop then
			popup:_intModalDraw()
		end
		if not popup._drawPreviousModals then
			-- Don't draw the other modals
			return
		end
	end
end

---This method draws the contents of the RootNode into the Viewport.
---It's already handled in `RootNode:draw()`.
function Root:drawToViewport()
	-- appleCakeProfileDTV = AppleCake.profile("Root:drawToViewport", nil, appleCakeProfileDTV)
	local viewport = self._viewport
	local modalStack = self._modalStack

	viewport:push(true)

	-- * Without post-processing, we don't have the alt-canvas
	-- * Without the alt-canvas, we can't apply color to CanvasLayers
	-- Keep that in mind if you rely on CanvasLayer colors

	love.graphics.origin()
	love.graphics.setColor(1, 1, 1)
	love.graphics.clear()

	if viewport._allowPostProcessing and viewport.applyPostProcessing then
		-- We apply the post-processing

		-- For each CanvasLayer (and RootNode), draw the contents into the final viewport
		---@type CanvasLayer[]
		local layers = self._canvasLayers
		local layerWantsNoProcessing = false

		-- First, draw everything that wants post-processing
		for i = 1, #layers do
			local layer = layers[i]
			if layer:isVisibleInTree() then
				if layer._applyParentProcessing then
					local shaderId = layer.appliedShaderID
					layer:drawLayer()
					viewport:applyToBuffer(layer.albedo, (shaderId and shaderAssets[shaderId]))
				else
					layerWantsNoProcessing = true
				end
			end
		end

		layerWantsNoProcessing = layerWantsNoProcessing or modalStack[#modalStack] ~= nil
		viewport:pop(true)

		-- And then draw everything else that doesn't want post-processing
		if layerWantsNoProcessing then
			viewport:push(false)
			love.graphics.origin()
			love.graphics.setColor(1, 1, 1)
			love.graphics.clear()
			for i = 1, #layers do
				local layer = layers[i]
				if layer:isVisibleInTree() and not layer._applyParentProcessing then
					local shaderId = layer.appliedShaderID
					layer:drawLayer()
					viewport:applyToBuffer(layer.albedo, (shaderId and shaderAssets[shaderId]))
				end
			end
			drawModals(modalStack)
			viewport:pop(false)
		end
	else
		-- No post-processing, do a simple draw
		---@type CanvasLayer[]
		local layers = self._canvasLayers
		for i = 1, #layers do
			local layer = layers[i]
			if layer:isVisibleInTree() then
				layer:drawLayer()
				viewport:applyToBuffer(layer.albedo)
			end
		end
		drawModals(modalStack)
		viewport:pop(false)
	end

	-- appleCakeProfileDTV:stop()
end

-- local appleCakeProfileDraw
-- local appleCakeProfileDrawFitted

---This method draws all CanvasLayers and the RootNode.
---If you're looking for how the RootNode draws, look at `:drawLayer()`
function Root:draw()
	-- appleCakeProfileDraw = AppleCake.profile("Root:draw", nil, appleCakeProfileDraw)
	self:drawBackground()
	self:drawToViewport()
	-- appleCakeProfileDraw.args = love.graphics.getStats()
	-- appleCakeProfileDraw:stop()

	-- appleCakeProfileDrawFitted = AppleCake.profile("Root:draw(Fitted)", nil, appleCakeProfileDrawFitted)
	love.graphics.setColor(self.albedo)
	self._viewport:drawFittedContents(0, 0)
	-- appleCakeProfileDrawFitted:stop()
	-- AppleCake.flush()
end

---This method should be overridden; it draws the background when the viewport doesn't fit the window
function Root:drawBackground()
end

---The handler for love.mousemoved
---@param x integer
---@param y integer
---@param dx integer
---@param dy integer
---@param isTouch boolean
---@return boolean handled
function Root:mousemoved(x, y, dx, dy, isTouch)
	self.mouseX, self.mouseY =
		x, y

	return self:isContextHandled("mousemoved", x, y, dx, dy, isTouch)
end

---The handler for love.mousepressed
---@param x integer
---@param y integer
---@param button integer
---@param isTouch boolean
---@param pressCount integer
---@return boolean handled
function Root:mousepressed(x, y, button, isTouch, pressCount)
	self:mousemoved(x, y, 0, 0, isTouch)
	return self:isContextHandled("mousepressed", x, y, button, isTouch, pressCount)
end

---The default handler for love.mousereleased
---@param x integer
---@param y integer
---@param button integer
---@param isTouch boolean
---@param pressCount integer
---@return boolean handled
function Root:mousereleased(x, y, button, isTouch, pressCount)
	self:mousemoved(x, y, 0, 0, isTouch)
	return self:isContextHandled("mousereleased", x, y, button, isTouch, pressCount)
end

---Call this when the canvas you want to draw to is resized.
---
---You may want to put this inside love.resize(w, h)
---@param newW integer
---@param newH integer
function Root:resize(newW, newH)
	if newW == self._windowW and newH == self._windowH then return end

	self._windowW, self._windowH =
		newW, newH
	self._viewport:fitInto(newW, newH)

	-- Fit all other CanvasLayers into the RootNode's Viewport's new resolution
	local rootW, rootH = self._viewport:getDimensions()

	local layers = self._canvasLayers
	for i = 1, #layers do
		local layer = layers[i]
		if
			layer ~= self -- The RootNode always owns its Viewport
			and
			layer:ownsViewport() -- ...to prevent double fitting
		then
			layer._viewport:fitInto(rootW, rootH)
		end
	end

	-- Refresh all Controls
	for control, _ in pairs(self._controlTopLevelLayers) do
		control:forceRefreshSelf()
	end

	return self:isContextHandled("resize", newW, newH)
end

---The default handler for love.displayrotated
---@param index integer
---@param orientation love.DisplayOrientation
function Root:displayrotated(index, orientation)
	self:resize(love.graphics.getDimensions())
end

Root.ALL_LOVE_CALLBACKS = {
	"update",
	"draw",

	-- WINDOW
	"resize",
	"displayrotated",
	"focus",
	"mousefocus",

	-- INPUT
	"keypressed",
	"keyreleased",
	"textinput",
	"mousemoved",
	"mousepressed",
	"mousereleased",
	"wheelmoved",
	"gamepadaxis",
	"gamepadpressed",
	"gamepadreleased",
	"joystickadded",
	"joystickaxis",
	"joystickhat",
	"joystickpressed",
	"joystickreleased",
	"joystickremoved",
	"touchmoved",
	"touchpressed",
	"touchreleased",
}

-- Most Love callbacks will get sent to Contexts instead
for i = 1, #Root.ALL_LOVE_CALLBACKS do
	local handler = Root.ALL_LOVE_CALLBACKS[i]
	if not rawget(Root, handler) then
		Root[handler] = function(self, ...)
			return self:isContextHandled(handler, ...)
		end
	end
end

---Adds any missing callbacks not implemented already in the `love` global.
---You should call this after defining everything (ex. somewhere inside of `love.load`)
function Root:addMissingCallbacks()
	local defaultCallbacks = self._defaultCallbacks
	for i = 1, #Root.ALL_LOVE_CALLBACKS do
		local handler = Root.ALL_LOVE_CALLBACKS[i]
		if not love[handler] then
			-- This handler wasn't set by the developer
			local callback = defaultCallbacks[handler]
			if callback then
				-- Use the default callback that was set in the RootNode
				love[handler] = function(...)
					callback(self, ...)
				end
			else
				-- Add a default that wraps around the RootNode's method
				-- (ex. `update()` becomes `root:update()`)
				love[handler] = function(...)
					self[handler](self, ...)
				end
			end
		end
	end

	if not love.run then
		-- If `run` is not set yet, we set it if requested
		local rootRun = defaultCallbacks.run
		if rootRun then
			love.run = function()
				rootRun(self)
			end
		end
	end
end

return Root
