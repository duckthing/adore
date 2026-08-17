---@type AdoreInit
local Adore = require ""
local Node2d = Adore.Nodes("Node2d")

---@class DebugRectangle: Node2d
---@field super Node2d
---@overload fun(x: number?, y: number?): DebugRectangle
local DRect = Node2d:extend()
DRect.CLASS_NAME = "DebugRectangle"

function DRect:new(x, y)
	x, y =
		x or love.math.random(-20, 20),
		y or love.math.random(-20, 20)
	DRect.super.new(self, x, y)

	---@type number # How fast we should spin each update
	self.spinSpeed = 0
	self.width = 20
	self.height = 35

	self.albedo = {love.math.colorFromBytes(
		love.math.random(40, 210),
		love.math.random(40, 210),
		love.math.random(40, 210)
	)}

	local bounds = self._localContentRect
	bounds:iSetComponents(-10, -17.5, 20, 35)
end

function DRect:_onDimensionsSet()
	local width, height = self.width, self.height
	self._localContentRect:iSetComponents(width * -0.5, height * -0.5, width, height)
	self:_updateGlobalBounds()
end

function DRect:draw()
	local lcr = self._localContentRect
	love.graphics.rectangle("fill", lcr:unpack())
end

function DRect:update(dt)
	if self.spinSpeed ~= 0 then
		self:rotate(self.spinSpeed * dt)
	end
end

function DRect._addDefinition(entry)
	entry:newNumber("spinSpeed", 0)
	entry:newNumber("width", 20, 0, nil, nil, "%_onDimensionsSet")
	entry:newNumber("height", 35, 0, nil, nil, "%_onDimensionsSet")
end

return DRect
