---@type AdoreInit
local Adore = require ""
local Nodes = Adore.Nodes
local Node2d = Nodes("Node2d")

---@class ShadowCaster2d: Node2d
---@field super Node2d
---@overload fun(x: number?, y: number?, points: number[]?, fill: boolean?, transform: boolean?): ShadowCaster2d
local Shadow2d = Node2d:extend()
Shadow2d.CLASS_NAME = "ShadowCaster2d"

function Shadow2d:new(x, y, points, fill, transform)
	Shadow2d.super.new(self, x, y)
	if transform == nil then transform = true end

	---@type number[] # The points of the occluder, in local space, going in clockwise order.
	---If your shadows are being rendered weird, check if the points are *clockwise*.
	self.points = points or {}

	---@type boolean # Duplicates the first point automatically, if the shape should be filled
	self.fillOccluder = fill or false
	---@type boolean # If the points should be transformed according to the global transform
	self.transformOccluder = transform or false
	if transform == nil then self.transformOccluder = true end

	self._localContentRect:iSetComponents(0, 0, 0, 0)
	if points then
		self:calculateBounds()
	end
end

---Sets the local shape of the occluder, and then calculates the bounds of them.
---@param points number[]
---@return self
function Shadow2d:setPoints(points)
	if points ~= self.points then
		if points then
			assert(#points % 2 == 0, "ShadowCaster2d's points given in :setPoints() is incomplete (not a set of 2)")
			self.points = points
		else
			self.points = {}
		end
	end
	return self
end

---Manually calculates the local content bounds by looking at the existing points, and then updates the global bounds.
---Call this whenever the points change; called automatically when :setPoints() is called, and in the constructor.
---@return self
function Shadow2d:calculateBounds()
	local points = self.points
	assert(#points % 2 == 0, "ShadowCaster2d's points given in :setPoints() is incomplete (not a set of 2)")

	if #points > 1 then
		if self.transformOccluder then
			local transform = self._globalTransform
			local x, y = transform:transformPoint(points[1], points[2])
			local bounds = self._localContentRect
			bounds:iSetComponents(x, y, 0, 0)
			for i = 3, #points - 1, 2 do
				bounds:iExpandTowards(points[i], points[i + 1])
			end
		else
			local x, y = points[1], points[2]
			local bounds = self._localContentRect
			bounds:iSetComponents(x, y, 0, 0)
			for i = 3, #points - 1, 2 do
				bounds:iExpandTowards(points[i], points[i + 1])
			end
		end
	end
	self:_updateGlobalBounds()

	return self
end

-- Disable drawing
function Shadow2d:_intDraw()
	self:_beforeDraw()
	self:_drawChildren()
	self:_afterDraw()
end
function Shadow2d:draw() end

function Shadow2d:onViewportRemoved(oldViewport)
	oldViewport._shadowShash:remove(self)
end

function Shadow2d:onViewportAdded(newViewport)
	local rect = self._globalContentRect
	newViewport._shadowShash:add(self, rect.x, rect.y, rect.w, rect.h)
end

function Shadow2d:_updateGlobalBounds()
	Shadow2d.super._updateGlobalBounds(self)
	local viewport = self._parentViewport

	if viewport then
		local rect = self._globalContentRect
		viewport._shadowShash:update(self, rect.x, rect.y, rect.w, rect.h)
	end
end

function Shadow2d._addDefinition(entry)
	entry:newTable("points", nil, "setPoints")
	entry:newBoolean("fillOccluder", false)
	entry:newBoolean("transformOccluder", false)
end

return Shadow2d
