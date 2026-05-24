---@type AdoreInit
local Adore = require ""
local Control = Adore.Nodes("Control")

---@class ViewportContainer: Control
---@field super Control
---@overload fun(viewport: Viewport?): ViewportContainer
local ViewportContainer = Control:extend()

function ViewportContainer:new(viewport)
	ViewportContainer.super.new(self)

	---@type Viewport? # The Viewport contained by this Node
	self._subViewport = viewport
	---@type boolean # Sets whether the Viewport will get resized automatically
	self.autoResize = true
	---@type boolean # Whether the Viewport should not receive updates
	self.paused = false
end

---Sets the contained Viewport
---@param newViewport Viewport?
---@return ViewportContainer
function ViewportContainer:setViewport(newViewport)
	local oldViewport = self._subViewport
	if oldViewport ~= newViewport then
		self._subViewport = newViewport
		local lcr = self._localContentRect
		self:resizeViewport(lcr.w, lcr.h)
	end
	return self
end

function ViewportContainer:_setCanonRect(x, y, w, h)
	self:resizeViewport(w, h)
	ViewportContainer.super._setCanonRect(self, x, y, w, h)
end

function ViewportContainer:resizeViewport(w, h)
	local viewport = self._subViewport
	if viewport and self.autoResize then
		viewport:fitInto(w, h)
	end
end

function ViewportContainer:draw()
	local viewport = self._subViewport
	if viewport then
		local lcr = self._localContentRect
		viewport:drawFittedContents(lcr.x, lcr.y)
	end
end

function ViewportContainer:update(dt)
	if not self.paused then
		self._subViewport:update(dt)
	end
end

return ViewportContainer
