---@type AdoreInit
local Adore = require ""
local Node = Adore.Nodes("Node")

-- Overengineered timer

---@class TimerNode: Node
---@overload fun(duration: number?, autoStart: boolean?, oneShot: boolean?): TimerNode
local Timer = Node:extend()
Timer.CLASS_NAME = "Timer"

function Timer:new(duration, autoStart, oneShot)
	Timer.super.new(self)

	---@type number # How long to wait
	self.duration = duration or 1
	---@type number # How much time passed
	self.elapsed = 0
	---@type boolean
	self.paused = not autoStart
	---@type boolean # If we should stop after the timer ends
	self.oneShot = oneShot or false

	---@type Signal # Called when the Timer completes one lap; passes itself
	self.completed = self:newSignal()
end

function Timer:update(dt)
	if self.paused then return end

	self.elapsed = self.elapsed + dt
	if self.elapsed >= self.duration then
		if self.oneShot then
			-- Pause the timer
			self.elapsed = 0
			self.paused = true
		else
			-- Loop the timer
			self.elapsed = self.elapsed - self.duration
		end
		self.completed:fire(self)
	end
end

---Starts the Timer if the Timer wasn't already started
function Timer:start()
	if self.paused then
		self.elapsed = 0
		self.paused = false
	end
end

---Starts the Timer at the elapsed time it was last at
function Timer:resume()
	self.paused = false
end

---Starts the Timer at 0
function Timer:restart()
	self.elapsed = 0
	self.paused = false
end

---Stops the Timer and saves the last elapsed time
function Timer:pause()
	self.paused = true
end

---Stops the Timer and resets the elapsed time
function Timer:stop()
	self.elapsed = 0
	self.paused = true
end

function Timer:forceDestroy(...)
	Timer.super.forceDestroy(self, ...)
	self.completed:release()
	self.completed = nil
end

return Timer
