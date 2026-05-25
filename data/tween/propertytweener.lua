---@class Tweener.Property: Tweener
local PropertyTweener = {}
local PropertyTweenerMT = {__index = PropertyTweener}
PropertyTweener.CLASS_NAME = "PropertyTweener"

---@param t number
---@return number
function PropertyTweener.ease(t) return t end

---@param object Object
---@param propertyName string
---@param value any
---@param duration number
function PropertyTweener.new(object, propertyName, value, duration)
	---@class Tweener.Property
	local t = {}
	t.delay = 0
	t.elapsed = 0
	t.completed = false

	if not duration or duration <= 0 then
		-- Default duration is 0, which is also the minimum duration
		duration = 0
	end

	t.duration = duration

	local entry = object:getClassDBEntry()
	local property = entry:getProperty(propertyName, true)
	if not property then
		error(("Could not find property '%s' in class '%s'"):format(propertyName, object.CLASS_NAME))
	end

	t.object = object
	t.propertyName = property.propertyName
	t.property = property
	t.relative = false
	t.customStart = false

	-- These values are set by the user
	t.startValue = property:newValue()
	t.endValue = value

	-- These values are changed and used instead (ex. for relative tweening)
	t._startValue = property:newValue()
	t._endValue = property:newValue()
	---@diagnostic disable-next-line: param-type-mismatch
	property:rawSet(t, "_endValue", value)

	return setmetatable(t, PropertyTweenerMT)
end

function PropertyTweener:onEnter()
	self.elapsed = 0
	self.completed = false
	local object, property =
		self.object,
		self.property

	if not self.customStart then
		property:rawSet(self, "_startValue", property:get(object, self.propertyName))
	else
		property:rawSet(self, "_startValue", self.startValue)
	end

	if self.relative then
		-- Relative
		local added = property:add(self._startValue, self.endValue)
		---@diagnostic disable-next-line: param-type-mismatch
		property:rawSet(self, "_endValue", added)
	end
end

function PropertyTweener:update(dt)
	self.elapsed = self.elapsed + dt
	if self.completed then
		-- Done, don't do anything
		return self.duration + self.delay - self.elapsed
	end

	local object, property, propertyName, delay =
		self.object,
		self.property,
		self.propertyName,
		self.delay

	local elapsedInTweener = self.elapsed - delay
	local timeRemaining = self.duration + delay - self.elapsed
	if elapsedInTweener > 0 then
		-- We're past the initial delay
		if timeRemaining > 0 then
			-- Still actively tweening
			local progress = 1
			if self.duration > 0 and elapsedInTweener < self.duration then
				progress = self.ease(elapsedInTweener / self.duration)
			end
			property:set(object, propertyName, property:lerp(self._startValue, self._endValue, progress))
		else
			-- Done tweening, set it to the end point
			self.completed = true
			property:set(object, propertyName, self._endValue)
		end
	end

	-- Return the amount of time remaining
	return timeRemaining
end

function PropertyTweener:onComplete()
	local object, property, propertyName =
		self.object,
		self.property,
		self.propertyName

	property:set(object, propertyName, self._endValue)
end

function PropertyTweener:isComplete()
	return self.completed
end

return PropertyTweener
