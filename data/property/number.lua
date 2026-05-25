local Property = require "data.property"

---@class Property.Number: Property
local Number = Property:extend()
Number.TYPE = "number"
local HUGE = math.huge

function Number:new(class, property, defaultValue, min, max, step, setter)
	Number.super.new(self, class, property, defaultValue or 0)
	self.min = min or -HUGE
	self.max = max or HUGE
	self.step = step or 0

	if setter then self:withSetter(setter) end
end

function Number:add(a, b)
	return a + b
end

function Number:sanitize(num)
	num = num or self.defaultValue
	local min, max, step =
		self.min, self.max, self.step

	local final = math.max(min, math.min(num, max))
	if min ~= -HUGE and step > 0 then
		final = final - ((final - min) % step)
	elseif max ~= HUGE and step > 0 then
		final = final - ((final - max) % step)
	elseif step > 0 then
		final = num - num % step
	end
	return final
end

function Number:isValid(num)
	return num == self:sanitize(num)
end

function Number:stepTowards(from, to, amount)
	if to > from then
		-- Increasing
		self:sanitize(math.min(from + amount, to))
	else
		-- Decreasing
		self:sanitize(math.max(from - amount, to))
	end
end

function Number:lerp(from, to, percent)
	local diff = to - from
	return self:sanitize(from + diff * percent)
end

return Number
