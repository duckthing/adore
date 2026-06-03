---@type AdoreInit
local Adore = require ""
local Nodes = Adore.Nodes
local Node2d = Nodes("Node2d")
local Raycast2d = Nodes("Raycast2d")
local max = math.max

---@class SpringArm2d: Raycast2d
---@field super Raycast2d
---@overload fun(x: number?, y: number?, rotation: number?, distance: number?, margin: number?): SpringArm2d
local SpringArm2d = Raycast2d:extend()
SpringArm2d.CLASS_NAME = "SpringArm2d"

---@param x number?
---@param y number?
---@param rotation number?
---@param distance number?
---@param margin number?
function SpringArm2d:new(x, y, rotation, distance, margin)
	SpringArm2d.super.new(self, x, y, rotation, distance)

	---@type number # How far to move inwards from the end point, with and without collision
	self.margin = margin or 20
end

function SpringArm2d:update(dt)
	SpringArm2d.super.update(self, dt)

	local fraction = self._fraction
	local targetX = 0

	if fraction == -1 then
		-- Nothing hit
		targetX = max(0, self._distance - self.margin)
	else
		-- Hit something
		targetX = max(0, self._distance * fraction - self.margin)
	end

	for i = 1, #self.children do
		local child = self.children[i]
		if child:is(Node2d) then
			---@cast child Node2d
			child:setPosition(targetX, 0)
		end
	end
end

function SpringArm2d._addDefinition(entry)
	entry:newNumber("margin", 0, nil)
end

return SpringArm2d
