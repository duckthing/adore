---@type AdoreInit
local Adore = require ""
local Node2d = Adore.Nodes("Node2d")
local Vec2 = Adore.Common("Vec2")

---@class Camera: Node2d
---@field super Node2d
---@overload fun(x: number?, y: number?): Camera
local Camera = Node2d:extend()
Camera.CLASS_NAME = "Camera"

function Camera:new(x, y)
	Camera.super.new(self, x, y)

	---@type boolean # Whether we should base this off the center of the screen
	self._center = true
	---@type Vec2 # How zoomed out we are. Farther from 0 shows more.
	self._zoom = Vec2(1, 1)
	---@type boolean # Whether we should use the rotation included within the transform or not.
	self._inheritRotation = true

	---@private boolean # If we should update self._canvasTransform
	self._shouldUpdateTransform = true
	---@private love.Transform # Cached transform, use Camera:getCanvasTransform() instead of this
	self._canvasTransform = love.math.newTransform()
end

-- A temporary transform used to prevent 1 object creation
local cTrans = love.math.newTransform()

---Updates the cached canvas transform.
---@param w integer
---@param h integer
function Camera:_updateCanvasTransform(w, h)
	if self._inheritRotation then
		-- Use the transform
		cTrans:setMatrix(self._globalTransform:getMatrix())
	else
		-- Cancel out the rotation in the transform
		cTrans:setTransformation(self._globalTransform:transformPoint(0, 0)):rotate(self._rotation)
	end

	local zoomX, zoomY = self._zoom.x, self._zoom.y
	if self._center then
		local nhalfW, nhalfH = w * -0.5, h * -0.5
		self._canvasTransform = cTrans:scale(zoomX, zoomY):translate(nhalfW, nhalfH):inverse()
		self._localContentRect:iSetComponents(nhalfW * zoomX, nhalfH * zoomY, w * zoomX, h * zoomY)
	else
		self._canvasTransform = cTrans:scale(zoomX, zoomY):inverse()
		self._localContentRect:iSetComponents(0, 0, w * zoomX, h * zoomY)
	end
	self:_onGlobalBoundsChanged()
end

---(Recalculates and) returns the canvas transform
---@return love.Transform
function Camera:getCanvasTransform()
	if self._shouldUpdateTransform then
		local viewport = self:getViewport()
		if viewport then
			self._shouldUpdateTransform = false
			self:_updateCanvasTransform(viewport:getDimensions())
		end
	end
	return self._canvasTransform
end

function Camera:_onGlobalTransformChanged()
	Camera.super._onGlobalTransformChanged(self)
	self._shouldUpdateTransform = true
end

function Camera:_onGlobalBoundsChanged()
	local notIncludingRotation = not self._inheritRotation
	if notIncludingRotation then
		local old = self._globalTransform
		local x, y = old:transformPoint(0, 0)
		cTrans:setTransformation(x, y, self._rotation)
		self._globalTransform = cTrans
		Camera.super._onGlobalBoundsChanged(self)
		self._globalTransform = old
	else
		Camera.super._onGlobalBoundsChanged(self)
	end
end

---Makes this Camera the active one in the Viewport
function Camera:setCurrent()
	self:getViewport()._activeCamera = self
end

---Sets the zoom of the Camera. A higher zoom shows more of the world.
---@param zoomX number
---@param zoomY number
function Camera:setZoom(zoomX, zoomY)
	self._zoom.x, self._zoom.y = zoomX, zoomY
	self._shouldUpdateTransform = true
	self:getCanvasTransform()
end

---Sets the zoom of the Camera. A higher zoom shows more of the world.
---@param zoom Vec2
function Camera:setZoomVector(zoom)
	self._zoom:iCopyVector(zoom)
	self._shouldUpdateTransform = true
	self:getCanvasTransform()
end

---Sets whether this Camera is centered. Set to false to make the camera render from the top-left corner.
---@param centered boolean
function Camera:setCentered(centered)
	self._center = centered
	self._shouldUpdateTransform = true
	self:getCanvasTransform()
end

---Sets whether this Camera uses its inherited rotation when rendering. Make false to not inherit rotations.
---It will still keep the inherited rotation internally; anything below will still get rotated as normal.
---@param inheritRotation boolean
function Camera:setInheritRotation(inheritRotation)
	self._inheritRotation = inheritRotation
	self._shouldUpdateTransform = true
	self:getCanvasTransform()
end

function Camera:onViewportAdded(newViewport)
	-- No Camera exists yet
	if not newViewport._activeCamera then
		self:setCurrent()
	end
	self:_updateCanvasTransform(newViewport:getDimensions())

	Camera.super.onViewportAdded(self, newViewport)
end

function Camera:onViewportRemoved(oldViewport)
	if oldViewport._activeCamera == self then
		oldViewport._activeCamera = nil
	end
	Camera.super.onViewportRemoved(self, oldViewport)
end

function Camera._addDefinition(entry)
	entry:newVec2("_zoom", nil, "setZoomVector")
	entry:newBoolean("_center", true, "setCentered")
	entry:newBoolean("_inheritRotation", true, "setInheritRotation")
end

return Camera
