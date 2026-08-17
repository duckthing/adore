local Property = require "data.property"
---@type Property.Number
local NumberProperty = require "data.property.number"

-- Color is values used for Love2D graphics (ex. .setColor())
-- It is in a range of 0..1 with 3/4 components

---@class Property.Color: Property
local Color = Property:extend()
Color.TYPE = "Color"
Color.subproperties = {
	r = NumberProperty(Color, "r", 0),
	g = NumberProperty(Color, "g", 0),
	b = NumberProperty(Color, "b", 0),
	a = NumberProperty(Color, "a", 0)
}

local tempColor1 = {1, 1, 1, 1}
local tempColor2 = {1, 1, 1, 1}

-- TODO: Add ways to lerp a color in different color spaces
function Color:new(class, property, defaultValue, colorSpace, setter)
	Color.super.new(self, class, property, defaultValue or class[property] or {1, 1, 1, 1})
	-- Color space is unused right now
	if setter then self:withSetter(setter) end
end

function Color:newValue()
	return {1, 1, 1, 1}
end

function Color:set(obj, property, value)
	local color = rawget(obj, property)
	if not color then
		color = self:newValue()
		obj[property] = color
	end
	color[1], color[2], color[3], color[4] =
		value[1], value[2], value[3], value[4]
end
Color.rawSet = Color.set

function Color:add(a, b)
	tempColor1[1], tempColor1[2], tempColor1[3], tempColor1[4] =
		a[1] + b[1],
		a[2] + b[2],
		a[3] + b[3],
		(a[4] or 1) + (b[4] or 0)
	return tempColor1
end

function Color:sanitize(color)
	if type(color) == "table" then
		tempColor1[1], tempColor1[2], tempColor1[3], tempColor1[4] =
			color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
	else
		tempColor1[1], tempColor1[2], tempColor1[3], tempColor1[4] =
			1, 1, 1, 1
	end
	return tempColor1
end

function Color:isValid(color)
	return type(color) == "table" and #color >= 3
end

function Color:stepTowards(from, to, amount)
	-- tempColor1 is the difference between these colors
	tempColor1[1], tempColor1[2], tempColor1[3] =
		to[1] - from[1],
		to[2] - from[2],
		to[3] - from[3]

	if to[4] then
		tempColor1[4] =
			to[4] - (from[4] or 1)
	else
		tempColor1[4] = 1
	end

	if to > from then
		-- Increasing
		-- TODO: Implement :stepTowards() for Color
	else
		-- Decreasing
	end
end

function Color:lerp(from, to, percent)
	-- tempColor1 is the difference
	-- tempColor2 is the result
	tempColor1[1], tempColor1[2], tempColor1[3] =
		to[1] - from[1],
		to[2] - from[2],
		to[3] - from[3]

	if to[4] then
		tempColor1[4] =
			to[4] - (from[4] or 1)
	else
		tempColor1[4] = 1
	end

	tempColor2[1], tempColor2[2], tempColor2[3], tempColor2[4] =
		from[1] + tempColor1[1] * percent,
		from[2] + tempColor1[2] * percent,
		from[3] + tempColor1[3] * percent,
		(from[4] or 1) + tempColor1[4] * percent

	return tempColor2
end

function Color:isDefault(v)
	return self:areEqual(self.defaultValue, v)
end

function Color:areEqual(a, b)
	return
		a[1] == b[1] and
		a[2] == b[2] and
		a[3] == b[3] and
		(a[4] or 1) == (b[4] or 1)
end

return Color
