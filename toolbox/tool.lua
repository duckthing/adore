local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes

local Node2d = Nodes("Node2d")
local Control = Nodes("Control")

local Vec2 = Adore.Common("Vec2")
local Rect2 = Adore.Common("Rect2")

local min, max = math.min, math.max

---@class Toolbox.Tool: SimpleObject
---@field super Toolbox.Tool
---@field mousemoved fun(self, mx: integer, my: integer, globalDx: integer, globalDy: integer, isTouch: boolean): boolean? handled
---@field mousepressed fun(self, mx: integer, my: integer, button: integer, isTouch: boolean, pressCount: integer): boolean? handled
---@field mousereleased fun(self, mx: integer, my: integer, button: integer): boolean? handled
---@field wheelmoved fun(self, wx: integer, wy: integer): boolean? handled
---@overload fun(): Toolbox.Tool
local Tool = Adore.Libraries("SimpleObject"):extend()

---@type Toolbox.EditableScene
Tool.srContainer = nil
---@type Toolbox.MainWindow
Tool.mainWindow = nil
---@type boolean # If this Tool is busy and should not be switched away from
Tool._busy = false

function Tool:new()
	Tool.super.new(self)
	self.panning = false
end

---Returns `true` if this Tool is busy and should not be switched away from
---@return boolean
function Tool:isBusy()
	return Tool._busy or self.panning
end

function Tool:mousepressed(mx, my, button, isTouch, pressCount)
	if button == 3 or (button == 1 and love.keyboard.isDown("space")) then
		-- Start panning
		self.panning = true
		return true
	end
	return false
end

function Tool:mousemoved(mx, my, dx, dy, isTouch)
	if self.panning then
		-- Pan with the mouse
		local camera = Tool.srContainer.camera
		local speed = -camera._zoom.x
		camera:translate(dx * speed, dy * speed)
		return true
	end
	return false
end

function Tool:mousereleased(mx, my, button)
	if self.panning then
		-- Stop panning
		self.panning = false
		return true
	end
	return false
end

function Tool:wheelmoved(wx, wy)
	-- Do zooming
	if wx == 0 then
		local camera = self.srContainer.camera
		local zoom = camera._zoom
		local newZoomValue = zoom.x
		if wy > 0 then
			newZoomValue = newZoomValue * 0.8
		elseif wy < 0 then
			newZoomValue = newZoomValue * 1.2
		end
		newZoomValue = max(0.02, min(newZoomValue, 1000))
		camera:setZoom(newZoomValue, newZoomValue)
		return true
	end
	return false
end

local tempVec2 = Vec2()
local tempRect2 = Rect2()

---Draws a bounding box around a Node2d
---@param selected Node2d
---@param baseThickness number
function Tool:drawNode2dBoundingBox(selected, baseThickness)
	local gcr = selected._globalContentRect
	local transform = selected._globalTransform

	-- Draw local bounding box
	do
		local ox, oy, oRight, oBottom = selected._localContentRect:getBounds()
		love.graphics.setLineWidth(1 * baseThickness)
		love.graphics.setColor(0.5, 0.5, 0.8)
		-- Top left
		local ax, ay = transform:transformPoint(ox, oy)
		-- Top right
		local bx, by = transform:transformPoint(oRight, oy)
		-- Bottom left
		local cx, cy = transform:transformPoint(ox, oBottom)
		-- Bottom right
		local dx, dy = transform:transformPoint(oRight, oBottom)

		love.graphics.line(
			ax, ay,
			bx, by,
			dx, dy,
			cx, cy,
			ax, ay
		)
	end

	-- Draw global bounding box
	love.graphics.setLineWidth(2 * baseThickness)
	love.graphics.setColor(0.8, 0.5, 0.5)
	love.graphics.rectangle("line", gcr:unpack())

	-- Draw axes
	local globalX, globalY = selected:getPosition(true)
	local axisLength = 25 * baseThickness
	-- +X
	love.graphics.setColor(1, 0, 0, 0.8)
	love.graphics.line(
		globalX, globalY,
		tempVec2:iSetComponents(1, 0)
			:iRotate(selected:getRotation(true)):iMult(axisLength)
			:iAddComponents(globalX, globalY):unpack()
	)
	-- +Y
	love.graphics.setColor(0, 1, 0, 0.8)
	love.graphics.line(
		globalX, globalY,
		tempVec2:iSetComponents(0, 1)
			:iRotate(selected:getRotation(true)):iMult(axisLength)
			:iAddComponents(globalX, globalY):unpack()
	)
end

---Draws a bounding box around a Control
---@param selected Control
---@param baseThickness number
function Tool:drawControlBoundingBox(selected, baseThickness)
	local lcr = selected._localContentRect
	local transform = selected._globalTransform
	tempRect2:iCopyRect(lcr):iTransformBox(transform)

	-- Draw local bounding box
	do
		local ox, oy, oRight, oBottom = selected._localContentRect:getBounds()
		love.graphics.setLineWidth(1 * baseThickness)
		love.graphics.setColor(0.5, 0.5, 0.8)
		-- Top left
		local ax, ay = transform:transformPoint(ox, oy)
		-- Top right
		local bx, by = transform:transformPoint(oRight, oy)
		-- Bottom left
		local cx, cy = transform:transformPoint(ox, oBottom)
		-- Bottom right
		local dx, dy = transform:transformPoint(oRight, oBottom)

		love.graphics.line(
			ax, ay,
			bx, by,
			dx, dy,
			cx, cy,
			ax, ay
		)
	end

	-- Draw global bounding box
	love.graphics.setLineWidth(3 * baseThickness)
	love.graphics.setColor(0.8, 0.5, 0.5)
	love.graphics.rectangle("line", selected._globalContentRect:unpack())
end

---Draws anything editor related
---@param eScene Toolbox.EditableScene
function Tool:drawForeground(eScene)
	local mainWindow = Tool.mainWindow
	local selected = mainWindow.sceneTree:getSelectedNode()
	if selected then
		local zoom = eScene.camera._zoom.x
		local pixelScale = selected:getViewport()._pixelScale
		local scaleFactor = 1 / pixelScale
		local baseThickness = zoom * scaleFactor

		love.graphics.push("transform")
		love.graphics.scale(pixelScale)

		if selected:is(Node2d) then
			---@cast selected Node2d
			self:drawNode2dBoundingBox(selected, baseThickness)
		elseif selected:is(Control) then
			---@cast selected Control
			self:drawControlBoundingBox(selected, baseThickness)
		end

		love.graphics.pop()
	end
end

return Tool
