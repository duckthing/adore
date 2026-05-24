---@class Tweener.Callback: Tweener
local CallbackTweener = {}
local PropertyTweenerMT = {__index = CallbackTweener}
CallbackTweener.CLASS_NAME = "CallbackTweener"

function CallbackTweener.new(callback, ...)
	---@class Tweener.Callback
	local t = {}
	t.delay = 0
	t.elapsed = 0
	t._called = false
	t.callback = callback
	if select("#", ...) > 0 then
		t.args = {...}
	end

	return setmetatable(t, PropertyTweenerMT)
end

function CallbackTweener:onEnter()
	self.elapsed = 0
	self._called = false

	if self.delay == 0 then
		self._called = true
		if self.args then
			self.callback(unpack(self.args))
		else
			self.callback()
		end
	end
end

function CallbackTweener:update(dt)
	self.elapsed = self.elapsed + dt
	local timeRemaining = self.delay - self.elapsed

	if not self._called and timeRemaining <= 0 then
		-- Not called, and it's time to call it
		if self.args then
			self.callback(unpack(self.args))
		else
			self.callback()
		end
	end

	-- Return the amount of time remaining
	return timeRemaining
end

function CallbackTweener:onComplete()
end

function CallbackTweener:isComplete()
	return self._called
end

return CallbackTweener
