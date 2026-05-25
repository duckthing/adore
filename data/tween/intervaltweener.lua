---@class Tweener.Interval: Tweener
local IntervalTweener = {}
local IntervalTweenerMT = {__index = IntervalTweener}
IntervalTweener.CLASS_NAME = "IntervalTweener"

---@param duration number
function IntervalTweener.new(duration)
	---@class Tweener.Interval
	local t = {}

	if not duration or duration <= 0 then
		-- Default duration is 0, which is also the minimum duration
		duration = 0
	end

	t.elapsed = 0
	t.duration = duration

	return setmetatable(t, IntervalTweenerMT)
end

function IntervalTweener:onEnter()
	self.elapsed = 0
end

function IntervalTweener:update(dt)
	self.elapsed = self.elapsed + dt
	-- Return the amount of time remaining
	return self.duration - self.elapsed
end

function IntervalTweener:onComplete() end

function IntervalTweener:isComplete()
	return self.elapsed >= self.duration
end

return IntervalTweener
