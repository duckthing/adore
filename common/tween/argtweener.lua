local Properties = require "properties"

---@class Tweener.Argument: Tweener
local ArgTweener = {}
local PropertyTweenerMT = {__index = ArgTweener}
ArgTweener.CLASS_NAME = "ArgumentTweener"

---@param t number
---@return number
function ArgTweener.ease(t) return t end

function ArgTweener.new(callback, duration, type, from, to, ...)
	---@class Tweener.Argument
	local t = {}
	t.delay = 0
	t.elapsed = 0
	t.completed = false

	if not duration or duration <= 0 then
		-- Default duration is 0, which is also the minimum duration
		duration = 0
	end
	t.duration = duration

	t.callback = callback
	---@type Property
	t.property = Properties[type]
	t.from = from
	t.to = to
	if select("#", ...) > 0 then
		t.args = {...}
	end

	return setmetatable(t, PropertyTweenerMT)
end

function ArgTweener:onEnter()
	self.elapsed = 0
	self.completed = false
end

function ArgTweener:update(dt)
	self.elapsed = self.elapsed + dt
	if self.completed then
		-- Done, don't do anything
		return self.duration + self.delay - self.elapsed
	end

	local property, delay =
		self.property,
		self.delay

	local elapsedInTweener = self.elapsed - delay
	local timeRemaining = (self.duration + delay) - self.elapsed

	local progress = 1
	if self.duration > 0 and elapsedInTweener < self.duration then
		progress = self.ease(elapsedInTweener / self.duration)
	end
	local value = property:lerp(self.from, self.to, progress)

	if elapsedInTweener > 0 then
		-- Still actively tweening, check if we're done later
		local args = self.args
		if args then
			self.callback(value, unpack(args))
		else
			self.callback(value)
		end

		if timeRemaining <= 0 then
			-- Just finished tweening
			self.completed = true
		end
	end

	-- Return the amount of time remaining
	return timeRemaining
end

function ArgTweener:onComplete()
end

function ArgTweener:isComplete()
	return self.completed
end

return ArgTweener
