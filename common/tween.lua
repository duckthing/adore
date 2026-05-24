---@type AdoreInit
local Adore = require ""

---@type Tweener.Property
local PropertyTweener = require "common.tween.propertytweener"
---@type Tweener.Interval
local IntervalTweener = require "common.tween.intervaltweener"
---@type Tweener.Callback
local CallbackTweener = require "common.tween.callbacktweener"
---@type Tweener.Method
local MethodTweener = require "common.tween.methodtweener"
---@type Tweener.Argument
local ArgTweener = require "common.tween.argtweener"

local Flux = Adore.Libraries("Flux")

local HUGE = math.huge
local max = math.max

---@class Tween
local Tween = {}
local TweenMT = {__index = Tween}

-- If the Tween loops, and is shorter than the time step (ex. duration of 0), it will start over again.
-- This will happpen a max of X times per update, to prevent infinite loops.
local MAX_LOOPS_PER_UPDATE = 3

---Creates a new Tween. This will be invalid if the RootNode doesn't manage it.
---You should use `Node:createTween` if you're looking for how to tween.
---@return Tween
function Tween.new()
	---@class Tween
	local t = {
		---@type Tweener[][]
		collections = {},
		---@type integer # How many times will this Tween loop?
		loops = 0,
		---@type boolean # Will any added Tweeners run parallel to the previous one by default?
		defaultParallel = false,
		---@type boolean? # Is the next one requested to be something parallel or not parallel?
		nextParallel = nil,
		---@type number # How much the deltatime will be multiplied; negative numbers do not work.
		speed = 1,

		running = false,
		elapsedTotal = 0,
		elapsedSinceEnteringCollection = 0,
		currCollectionIndex = 1,
		currentLoop = 1,

		---@type boolean # Is the Root running this Tween independent of game speed?
		_realTime = false,
		---@type Tweener
		_lastTweener = nil,
		---@type Node? # What Node we're bound to; animation stops when the Node is destroyed
		_boundNode = nil,
		---@type boolean # Is this Tween not running because it's paused?
		_paused = false
	}
	return setmetatable(t, TweenMT)
end

---Returns info for the next Tweener, like which collection it should be put in
---@param self Tween
---@return Tweener[] collection
local function getNextInfo(self)
	-- Get if the next Tweener should be parallel
	local parallel = self.nextParallel
	self.nextParallel = nil
	if parallel == nil then parallel = self.defaultParallel end

	-- Get the collection the Tweener should be put in
	local collection
	if parallel then
		collection = self.collections[#self.collections]
	end
	if not collection then
		collection = {}
		self.collections[#self.collections+1] = collection
	end

	return collection
end

---Tweens a property that belongs to an Object.
---The property and its type should be registered in the ClassDB in order to work.
---@param object Object
---@param propertyName string
---@param value any
---@param duration number
---@return Tween
function Tween:tweenProperty(object, propertyName, value, duration)
	local collection = getNextInfo(self)

	-- Create it
	local pTween = PropertyTweener.new(object, propertyName, value, duration)
	collection[#collection+1] = pTween
	self._lastTweener = pTween

	return self
end

---Adds a timer to this Tween. Can be used to make delays between sets.
---@param duration number
---@return Tween
function Tween:tweenInterval(duration)
	local collection = getNextInfo(self)

	-- Create it
	local iTween = IntervalTweener.new(duration)
	collection[#collection+1] = iTween
	self._lastTweener = iTween

	return self
end

---Calls a function at this step. If you're using an object's method, you should pass `self` manually.
---For example, if you wanted to set the visibility of a Node to `true`:
---`tween:tweenCallback(node.setVisible, node, true)`
---@param callback function
---@param ... unknown
---@return Tween
function Tween:tweenCallback(callback, ...)
	local collection = getNextInfo(self)

	-- Create it
	local cTween = CallbackTweener.new(callback, ...)
	collection[#collection+1] = cTween
	self._lastTweener = cTween

	return self
end

---Calls an object's method at this step. Passes `self` to the object.
---For example, if you wanted to set the visibility of a Node to `true`:
---`tween:tweenMethod(node, "setVisible", true)`
---
---Are you looking for a way to tween the argument over time?
---Look at `Tween:tweenArgument()`
---@param object Object
---@param method string
---@param ... unknown
---@return Tween
function Tween:tweenMethod(object, method, ...)
	local collection = getNextInfo(self)

	-- Create it
	local mTween = MethodTweener.new(object, method, ...)
	collection[#collection+1] = mTween
	self._lastTweener = mTween

	return self
end

---Calls a function with the first argument being tweened over time.
---For example, if you wanted to make a `Node2d` look at a moving point:
---```lua
---local cb = function(value) sprite:lookAt(value.x, value.y) end
---tween:tweenArgument(cb, 1, "Vec2", Vec2(-10, -10), Vec2(10, 10))
-- ```
---@param callback function
---@param duration number
---@param type PropertyType
---@param from any
---@param to any
---@param ... unknown
---@return Tween
function Tween:tweenArgument(callback, duration, type, from, to, ...)
	local collection = getNextInfo(self)

	-- Create it
	local aTween = ArgTweener.new(callback, duration, type, from, to, ...)
	collection[#collection+1] = aTween
	self._lastTweener = aTween

	return self
end

---Makes the next tween request occur with the former at the same time; opposite of :after()
---@return Tween
function Tween:parallel()
	self.nextParallel = true
	return self
end

---Makes the next tween request occur after the former one(s) finish; opposite of :parallel()
---@return Tween
function Tween:after()
	self.nextParallel = false
	return self
end

---Sets the easing function used for the last inserted Tweener.
---If it's a string, it will use a preset.
---If it's a function, it passes a value between [0..1] and expects a value in [0..1] in return.
---@param easing EasingFunction | (fun(t: number): number)
---@return Tween
function Tween:setTrans(easing)
	local tweener = self._lastTweener
	assert(tweener, "No Tweener exists for setting the transition function; tween something first")

	local paramType = type(easing)
	if paramType == "string" then
		-- String, check the easing function list
		local easingFunc = Flux.easing[easing]
		if not easingFunc then
			error(("'%s' is not a valid EasingFunction"):format(easing))
		end
		tweener.ease = easingFunc
	elseif paramType == "function" then
		tweener.ease = easing
	else
		error(("Cannot set the ease/transition function to type '%s'"):format(paramType))
	end

	return self
end

---Sets the delay before running this Tweener
---@param delay number
---@return Tween
function Tween:setDelay(delay)
	local tweener = self._lastTweener
	assert(tweener, "No Tweener exists for setting the transition function; tween something first")
	if tweener.delay then
		tweener.delay = max(0, delay)
	end
	return self
end

---Sets the amount of times this Tween will run until stopping.
---Pass in a negative number to make this run infinitely.
---0 and 1 will run once, 2 will run twice, -1 will run forever.
---@param loops number
---@return Tween
function Tween:setLoops(loops)
	self.loops = loops or 0
	return self
end

---Sets the speed of the Tween. Any value passed to `:update()` will be multiplied by this.
---Negative numbers are not supported.
---@param speed number
---@return Tween
function Tween:setTweenSpeed(speed)
	self.speed = max(speed or 0, 0)
	return self
end

---Makes this Tweener use the final value as relative (ex. `start + end`, instead of `end`)
---@return Tween
function Tween:asRelative()
	local tweener = self._lastTweener
	assert(tweener, "No Tweener exists for setting the transition function; tween something first")
	if tweener.relative ~= nil then
		---@cast tweener Tweener.Property
		tweener.relative = true
	end
	return self
end

---Sets the starting value of this Tweener, instead of using the one at the time of entry
---@param start any
---@return Tween
function Tween:from(start)
	local tweener = self._lastTweener
	assert(tweener, "No Tweener exists for setting the start value; tween something first")
	if tweener.customStart ~= nil then
		---@cast tweener Tweener.Property
		tweener.customStart = true
		local property = tweener.property
		property:rawSet(tweener, "startValue", start)
	end
	return self
end

---Sets the starting value of this Tweener to the current value
---@return Tween
function Tween:fromCurrent()
	local tweener = self._lastTweener
	assert(tweener, "No Tweener exists for setting the start value; tween something first")
	if tweener.customStart ~= nil then
		---@cast tweener Tweener.Property
		tweener.customStart = true
		local property = tweener.property
		property:rawSet(tweener, "startValue", property:get(tweener.object, tweener.propertyName))
	end
	return self
end

---Binds this Tween to a Node. The Tween will stop if the Node is removed.
---This is done automatically if you call `:createTween()` inside a Node.
---@param node Node?
function Tween:bindNode(node)
	if node then
		self._boundNode = node
		if not node._valid and self.running then
			self.running = false
		end
	else
		self._boundNode = nil
	end
end

---Starts the Tween from the beginning, if it wasn't running already.
---If this Tween was created manually, you'll have to call `:update()`.
function Tween:play()
	-- The RootNode overrides `:stop()` and `:play()`
	-- Is the Node removed?
	if self._boundNode and not self._boundNode._valid then return end
	if self.running then return end

	self.elapsedTotal, self.elapsedSinceEnteringCollection = 0, 0
	self.currCollectionIndex = 1
	self.currentLoop = 1
	self._paused = false

	local collection = self.collections[1]
	if not collection then return end

	-- Collection exists (tween is not empty)
	self.running = true
	for i = 1, #collection do
		local tweener = collection[i]
		tweener:onEnter()
	end
end

---Pauses the Tween, and allows it to continue running later
function Tween:pause()
	if self.running then
		self.running = false
		self._paused = true
	end
end

---Resumes the Tween from where it left off (or starts it if it's already finished)
function Tween:resume()
	if self._paused then
		-- Unpause
		self._paused = false
		self.running = true
	else
		-- Fresh start
		self:play()
	end
end

---Stops the Tween, and discards its progress
function Tween:stop()
	-- The RootNode overrides `:stop()` and `:play()`
	self.running = false
	self._paused = false
end

---Starts the Tween from the beginning
function Tween:restart()
	self:stop()
	self:play()
end

---Skips to the end of the Tween, while going through each step
function Tween:skipToEnd()
	self:play()
	local oldLoopCount = self.loops
	self.loops = 0
	while self.running do
		self:update(1000)
	end
	self.loops = oldLoopCount
	self:stop()
end

---Updates the Tween. Returns `true` if this Tween is still running, `false` means you should stop calling `:update()`.
---You don't have to call this if you've created the Tween through the Root or `Node:createTween()`.
---@param originalDelta number
---@return boolean isRunning
function Tween:update(originalDelta)
	if not self.running then return false end

	local dt = originalDelta * self.speed
	local timeToProcess = dt
	local currCollection = self.collections[self.currCollectionIndex]
	if not currCollection then
		self.running = false
		return false
	end

	do
	-- Are we bound to a Node?
	local boundNode = self._boundNode
	if boundNode then
		if not boundNode._valid then
			-- Stop running if the Node was destroyed
			self.running = false
			return false
		elseif not boundNode._inTree then
			-- "Pause" if the Node is not in the tree
			return true
		end
	end
	end

	local loopsThisUpdate = 1
	while timeToProcess > 0 and currCollection do
		if loopsThisUpdate > MAX_LOOPS_PER_UPDATE then
			print(("[Adore.Tween] A Tween looped %d times in one frame; skipping"):format(MAX_LOOPS_PER_UPDATE))
			break
		end

		-- Update all Tweeners, and see how much time is left for them to finish
		-- The :update() method returns the remaining duration
		local remainingTime = -HUGE
		if #currCollection == 0 then remainingTime = 0 end
		for i = 1, #currCollection do
			-- Update each Tweener, and wait for the Tweener taking the longest amount of time
			local tweener = currCollection[i]
			remainingTime = max(remainingTime, tweener:update(timeToProcess))
		end

		-- If they have negative remaining time, we should have already moved on to the next Tweeners
		if remainingTime <= 0 then
			timeToProcess = -remainingTime
			-- Tell the current Tweeners to exit
			for i = 1, #currCollection do
				local tweener = currCollection[i]
				tweener:onComplete()
			end

			-- Check if there's more collections to go through
			if self.currCollectionIndex >= #self.collections then
				-- End of Tween (no more collections); either loop or stop
				if self.currentLoop >= self.loops and self.loops >= 0 then
					-- Max loops, stop
					-- (Can also be that there were never any requested loops in the first place)
					self.running = false
					timeToProcess = 0
					break
				else
					-- More loops to do, keep looping
					-- (If `loops` is negative, loop indefinitely)
					loopsThisUpdate = loopsThisUpdate + 1
					self.currentLoop = self.currentLoop + 1
					self.currCollectionIndex = 1
				end
			else
				-- Continue to the next collection of Tweeners
				self.currCollectionIndex = self.currCollectionIndex + 1
			end

			-- More collections to go through (or we loops to the start)
			currCollection = self.collections[self.currCollectionIndex]
			-- Tell the next Tweeners to enter
			for i = 1, #currCollection do
				local tweener = currCollection[i]
				tweener:onEnter()
			end
		else
			-- Processed up to `remainingTime`, nothing left to do. Exit.
			break
		end
	end

	self.elapsedTotal = self.elapsedTotal + dt
	return self.running
end

---Returns `true` if this Tween will get `:update()` called on it.
---@return boolean running
function Tween:isRunning()
	return self.running
end

---Gets the last inserted Tweener.
---Will error if there has not been any Tweeners added.
---@return Tweener
function Tween:getTweener()
	assert(#self.collections > 0, "Can't get Tweener; no Tweeners have been added")
	local collection = self.collections[#self.collections]
	return collection[#collection]
end

return Tween
