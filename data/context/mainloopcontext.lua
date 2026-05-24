---@type AdoreInit
local Adore = require ""
local Context = Adore.Resources("Context")
local tclear = Adore.Common("Structures").tableClear

---@class MainLoopContext: Context
---@field super Context
---@overload fun(root: RootNode): MainLoopContext
local MainLoop = Context:extend()
MainLoop.HANDLERS = {
	update = true,
	postUpdate = true,
}
---@type RootNode
MainLoop.Root = nil
MainLoop.CLASS_NAME = "MainLoopContext"

---@param root RootNode
function MainLoop:new(root)
	MainLoop.super.new(self)
	self.root = root
	self._priority = -1000

	self._updating = false
end

---@type Node[]
local tlParents = {}
---@type integer
local tlChildIndex = {}

---Calls `:update()` on the top-level node, and on any descendents that inherit its pause mode
---@param start Node
---@param dt number
local function updateTopLevel(start, dt)
	-- If it's not the RootNode, call `:update()` on it
	if not start:is(MainLoop.Root) then
		start:update(dt)
	end

	tlParents[1] = start
	tlChildIndex[1] = 1

	while #tlParents > 0 do
		local i = #tlParents
		local parent = tlParents[i]
		local childIndex = tlChildIndex[i]
		local child = parent.children[childIndex]

		if not child then
			-- Child doesn't exist, go up one level
			tlParents[i] = nil
			tlChildIndex[i] = nil
		else
			-- Child exists
			if child._pauseMode == "inherit" then
				-- Can process it, since it inherits from us
				local method = child.update
				if method and method(child, dt) then
					-- Method exists and returned true, exit
					break
				end

				if #child.children > 0 then
					-- Add this child to the array
					tlParents[i + 1] = child
					tlChildIndex[i + 1] = 1
				end
			end

			tlChildIndex[i] = childIndex + 1
		end
	end

	-- Clear the arrays
	tclear(tlParents)
	tclear(tlChildIndex)
end

---Runs the top-level processors
---@param arr Node[]
---@param dt number
---@param paused boolean
local function runTopLevelProcessors(arr, dt, paused)
	---@type Node.PauseMode # If paused, don't run "pausable". If running, don't run "whenPaused".
	local disallowedMode = (paused and "pausable") or "whenPaused"

	for i = 1, #arr do
		local node = arr[i]
		local mode = node._pauseMode
		if not (mode == "disabled" or mode == disallowedMode) then
			updateTopLevel(node, dt)
		end
	end
end

---@param a any
---@param b any
---@return boolean
local function timerQueueSortCheck(a, b)
	return a[1] < b[1]
end

local function runTimerMethods(queue, dt)
	local currQueueLength = #queue
	for i = currQueueLength, 1, -1 do
		local request = queue[i]
		-- 1: Remaining time
		-- 2: Node
		-- 3: Method
		-- 4...: Parameters
		local remainingTime = request[1] - dt
		request[1] = remainingTime

		if remainingTime < 0 then
			local node = request[2]
			if node._valid then
				request[3](node, unpack(request, 4))
			end
		end
	end

	-- Remove the ones that timed out
	for i = currQueueLength, 1, -1 do
		if queue[i][1] < 0 then
			table.remove(queue, i)
		end
	end

	-- Sort afterwards
	table.sort(queue, timerQueueSortCheck)
end

---@param list Tween[]
---@param dt number
local function runTweens(list, dt)
	for i = #list, 1, -1 do
		local tween = list[i]
		if not tween:update(dt) then
			table.remove(list, i)
		end
	end
end

function MainLoop:update(originalDelta)
	local root = self.root

	-- Updates all Nodes if the game isn't paused
	local dt = originalDelta * root.gameSpeed
	if not root._paused then
		-- Update the Tweens
		runTweens(root.gameTweens, dt)

		-- Update the physics world
		root._viewport:update(dt)

		-- Update the game speed-dependent timers
		runTimerMethods(root.gameTimerMethods, dt)
	end

	-- Update all nodes with :update()
	runTopLevelProcessors(root._topLevelProcessors, dt, root._paused)

	-- Update the game speed independent methods
	runTweens(root.realTweens, originalDelta)
	runTimerMethods(root.realTimerMethods, originalDelta)

	-- Goes through both queues (up to N*2 times, in case of an infinite loop)
	do
		---Will run `maxInterations * 2`; one for the first queue, and the other for the second queue.
		---The second queue is used when the first queue defers a method.
		---@type integer
		local maxIterations = 5
		local shouldBreak = false

		for _ = 1, maxIterations do
			for queueI = 1, 2 do
				root._firstQueueActive = queueI == 2
				local queue = (queueI == 1 and root.methodQueue1) or root.methodQueue2
				local n = #queue

				if n == 0 then
					-- No more deferred methods
					shouldBreak = true
					break
				end

				for i = n, 1, -1 do
					local request = queue[i]
					queue[i] = nil
					-- 1: Node
					-- 2: Method
					-- 3...: Parameters
					local node = request[1]
					if node._valid then
						request[2](node, unpack(request, 3))
					end
				end
			end

			if shouldBreak then break end
		end

		if not shouldBreak then
			-- If we reached here, it means we looped `iterations * 2` times
			-- There might be a queued call that queues another call, that queues the former call again
			print(
				("[Adore.MainLoopContext:update] Deferred queues ran %d times in one update; delaying to next frame")
				:format(maxIterations * 2)
			)
		end

		root._firstQueueActive = true
	end

	-- Sets the listening position, if there isn't an existing one
	if not (root._defaultRelativeAudio and root._activeAudioListener) then
		local canvasXform = root:getViewport():getCanvasTransform()
		local canvasW, canvasH = root._viewport._mainCanvas:getDimensions()

		local x, y = canvasXform:inverseTransformPoint(canvasW * 0.5, canvasH * 0.5)
		love.audio.setPosition(x, y, root._defaultRelativeAudioZ)
		love.audio.setOrientation(
			0, 0, 1,
			0, -1, 0
		)
	end
end

function MainLoop:postUpdate()
	local root = self.root

	-- Update the last mouse positions
	root.lastMouseX, root.lastMouseY =
		root.mouseX, root.mouseY

	if root._mouseMode == "centered" and root.firstRoot then
		local screenW, screenH = love.graphics.getDimensions()
		love.mouse.setPosition(screenW * 0.5, screenH * 0.5)
	end
end

return MainLoop
