---@type AdoreInit
local Adore = require ""
local Light2d = Adore.Nodes("Light2d")

---@class CircleLight2d: Light2d
---@overload fun(x: number?, y: number?, radius: number?): CircleLight2d
local CircleLight2d = Light2d:extend()

function CircleLight2d:new(x, y, radius)
	CircleLight2d.super.new(self, x, y)
	radius = radius or 30

	---@type number # The radius of the light
	self.lightRadius = 0
	self:setRadius(radius)
end

---Sets the radius of the light
---@param newRadius number
---@return self
function CircleLight2d:setRadius(newRadius)
	if self.lightRadius ~= newRadius then
		self.lightRadius = newRadius
		self._localContentRect:iSetComponents(-newRadius * 5, -newRadius * 5, newRadius * 10, newRadius * 10)
	end
	return self
end

function CircleLight2d:draw()
	local rect = self._localContentRect
	local mx, my =
		rect.x + rect.w * 0.5,
		rect.y + rect.h * 0.5
	local radius = self.lightRadius

	love.graphics.setColor(1, 1, 1, 0.2)
	love.graphics.scale(5, 5)

	love.graphics.circle("fill", mx, my, radius)

	love.graphics.scale(0.8, 0.8)
	love.graphics.circle("fill", mx, my, radius)

	love.graphics.scale(0.8, 0.8)
	love.graphics.circle("fill", mx, my, radius)

	love.graphics.scale(0.6, 0.6)
	love.graphics.circle("fill", mx, my, radius)
end

return CircleLight2d
