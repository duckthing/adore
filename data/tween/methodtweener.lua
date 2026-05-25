---@class Tweener.Method: Tweener
local MethodTweener = {}
local PropertyTweenerMT = {__index = MethodTweener}
MethodTweener.CLASS_NAME = "MethodTweener"

function MethodTweener.new(object, method, ...)
	---@class Tweener.Method
	local t = {}
	t.delay = 0
	t.elapsed = 0
	t._called = false
	t.object = object
	t.method = method
	if select("#", ...) > 0 then
		t.args = {...}
	end

	return setmetatable(t, PropertyTweenerMT)
end

function MethodTweener:onEnter()
	self.elapsed = 0
	self._called = false

	if self.delay == 0 then
		self._called = true
		local object = self.object
		if self.args then
			object[self.method](object, unpack(self.args))
		else
			object[self.method](object)
		end
	end
end

function MethodTweener:update(dt)
	self.elapsed = self.elapsed + dt
	local timeRemaining = self.delay - self.elapsed

	if not self._called and timeRemaining <= 0 then
		-- Not called, and it's time to call it
		self._called = true
		local object = self.object
		local args = self.args
		if args then
			object[self.method](object, unpack(args))
		else
			object[self.method](object)
		end
	end

	-- Return the amount of time remaining
	return timeRemaining
end

function MethodTweener:onComplete()
end

function MethodTweener:isComplete()
	return self._called
end

return MethodTweener
