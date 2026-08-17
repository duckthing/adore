local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local Resources = Adore.Resources
local min, max = math.min, math.max

local Node = Nodes("Node")
local Node2d = Nodes("Node2d")
local Control = Nodes("Control")
local ViewportContainer = Nodes("ViewportContainer")
local RootNode = Nodes("RootNode")
local Viewport = Resources("Viewport")
local Camera = Nodes("Camera")
local Rect2 = Adore.Common("Rect2")

---@type Toolbox.Tool
local Tool = require(ADORE_PATH..".toolbox.tool")
---@type Toolbox.Tool.Select
local SelectTool = require(ADORE_PATH..".toolbox.tool.select")

local lgReplaceTransform = love.graphics.replaceTransform

---Not a class, to not pollute with useless suggestions
---@class Toolbox.EditableScene: ViewportContainer
---@overload fun(root: RootNode?): Toolbox.EditableScene
local EScene = ViewportContainer:extend()
EScene.CLASS_NAME = "EditableScene"

do
	-- Mark this class as something that changes a Viewport
	local arr = Node.OVERRIDES_VIEWPORT
	arr[#arr+1] = EScene
end

local tools = {
	Select = SelectTool(),
}

---@type {label: string?, icon: TextureSource?}[]
local availableTools = {
	{label = "Select"},
	{label = "Move"},
	{label = "Rotate"},
	{label = "Scale"},
}

function EScene:new(root)
	EScene.super.new(self, Viewport({}))
	self:setAnchors(0, 0, 1, 1)

	---@type RootNode[]
	self._lastRoot = {}

	---@type RootNode? # The subroot contained by this scene
	self.subroot = root

	---@type boolean # Should the subroot's size be fixed?
	self.overrideSize = true
	---@type integer, integer # The overridden size of the Viewport
	self.overrideW, self.overrideH = 600, 400

	---@type boolean # If we are using the camera
	self.cameraActive = true
	---@type boolean # If we are not drawing with the subroot's Viewports
	self.directDraw = true
	---@type Camera # The camera used for the editor
	self.camera = Camera()

	---@type boolean # [Internal] If we're actively panning
	self.panning = false

	---@type Toolbox.Tool
	self.tool = tools.Select

	---@type boolean # Whether this can call `:update`
	self._running = false
	---@type string? # The error message from the last method call
	self._errorMessage = nil
	---@type string? # The last file path this EditableScene interacted with
	self._lastFilepath = nil
	---@type ObjectSaver.Format? # The last format this was saved in
	self._lastFormat = nil
end

---Returns an array of tool descriptions; used for populating the topbar
---@return {label: string?, icon: TextureSource?}[]
function EScene:getTools()
	return availableTools
end

---@param button Button
function EScene:_onSelectToolPressed(button)
	self:selectTool(button._text)
end

---Selects a Toolbox.Tool by string name
function EScene:selectTool(name)
	local oldTool = self.tool
	if oldTool and oldTool:isBusy() then return end
	local newTool = tools[name]
	if newTool ~= self.tool then
		self.tool = newTool
	end
end

---Gets the scene root
function EScene:getSceneRoot()
	return self.subroot.children[1]
end

---Handles resizing on the subroot
function EScene:resizeSubroot(w, h)
	self:handleOnSubroot("resize", w, h)
end

function EScene:_setCanonRect(x, y, w, h)
	self._viewportFits = w > 1 and h > 1
	if self._viewportFits then
		self:resizeViewport(w, h)
		self:resizeSubroot(self._subViewport:getDimensions())
		self:drawGameRootIntoViewport()
	end
	ViewportContainer.super._setCanonRect(self, x, y, w, h)
end

---Sets the subroot from an existing subroot
---@param root RootNode
function EScene:setSubroot(root)
	self.subroot = root
end

---Creates a subroot
function EScene:createSubroot()
	local rootViewport = assert(self._subViewport)
	self:pushSubroot()
	local subroot = RootNode({
		hideSceneWarning = true,
		drawControlDebug = true,
		physicsWorld = love.physics.newWorld(),
		ownsPhysicsWorld = true,
	}, Adore.Resources("DefaultTheme")())
	local subrootViewport = subroot._viewport
	subrootViewport._adorePersist = false
	subrootViewport._adoreSelectable = false
	subrootViewport.getSafeArea = function()
		-- Use the overridden dimensions when using free-cam
		if self.cameraActive then
			return 0, 0, self.overrideW, self.overrideH
		else
			return rootViewport:getSafeArea()
		end
	end
	self.subroot = subroot
	self:popSubroot()
end

---Changes the contained scene
---@param scene string | SceneFactory
function EScene:changeSceneTo(scene)
	self:pushSubroot()
	local sceneType = type(scene)
	if sceneType == "string" then
		self._lastFilepath = scene:gsub("%.", "/")..".lua"
		self.subroot:changeSceneTo(require(scene))
	elseif sceneType == "table" then
		self.subroot:changeSceneTo(scene)
	end
	self:popSubroot()
end

---Pushes the subroot so that it can operate
function EScene:pushSubroot()
	self._lastRoot[#self._lastRoot+1] = Node._root
	Node._root = self.subroot
end

---Pops the subroot and replaces the active root with the previous one
function EScene:popSubroot()
	local count = #self._lastRoot
	assert(count ~= 0, "Root stack is empty")
	Node._root, self._lastRoot[count] = self._lastRoot[count], nil
end

---Returns `true` if the subroot is active
---@return boolean subrootActive
function EScene:isPushed()
	return Node._root == self.subroot
end

---@type string? # The last caught error
local lastError
local function handleSubrootError(error)
	local traceback = debug.traceback("", 3)
	lastError = ("Game Error [Press ` to open Toolbox]\n\n%s\n%s"):format(error, traceback)
	return ("%s%s"):format(error, traceback)
end

local function handleDirectDrawError(error)
	local traceback = debug.traceback("")
	lastError = ("%s\n%s"):format(error, traceback)
	return ("%s%s"):format(error, traceback)
end


---Calls a method on the subroot, pushing and popping as necessary
---@param methodName string
---@param ... unknown
---@return true success # Whether this method didn't crash
---@overload fun(self, methodName: string, ...: unknown): false, string
function EScene:handleOnSubroot(methodName, ...)
	if self._errorMessage then return false, self._errorMessage end

	local shouldPush = not self:isPushed()
	if shouldPush then
		self:pushSubroot()
	end

	local subroot = self.subroot
	local success, err = xpcall(subroot[methodName], handleSubrootError, subroot, ...)
	if not success then
		print(("Errored while calling '%s' on subroot inside of '%s':"):format(methodName, tostring(self)))
		print(err)

		self._errorMessage, lastError = lastError
	end

	if shouldPush then
		self:popSubroot()
	end
	return success, err
end

---Returns `true` if this subroot can continue running
---@return boolean running
function EScene:isRunning()
	return self._visible and self._running and not self._errorMessage
end

---Updates the Viewport with the drawn contents of the subroot
function EScene:drawGameRootIntoViewport()
	local sx, sy, sw, sh = love.graphics.getScissor()
	love.graphics.push("all")
	love.graphics.origin()
	love.graphics.setScissor()
	self._subViewport:push()

	local success = self:handleOnSubroot("draw")

	self._subViewport:pop()
	love.graphics.pop()
	love.graphics.setScissor(sx, sy, sw, sh)
	if not success then
		self:drawErrorIntoViewport()
	end
end

local drawDirectSubroot
do
---@param self Toolbox.EditableScene
local function drawBackgroundGizmos(self)
	local thickness = 3 * self.camera._zoom.x
	local bounds = self._subViewport._boundingBox
	local left, top, bw, bh = bounds:unpack()
	local right, bottom = left + bw, top + bh
	local originX = max(left, min(0, right))
	local originY = max(top, min(0, bottom))

	love.graphics.push("all")

	-- Draw the X/Y axis
	love.graphics.setLineWidth(thickness)
	love.graphics.setColor(0, 1, 0, originX == 0 and 0.8 or 0.6)
	love.graphics.line(originX, top, originX, bottom)
	love.graphics.setColor(1, 0, 0, originY == 0 and 0.8 or 0.6)
	love.graphics.line(left, originY, right, originY)

	-- Draw the Viewport bounds
	love.graphics.setColor(0.3, 0.3, 0.7, 0.8)
	love.graphics.rectangle("line", self.subroot._viewport:getSafeArea())
	love.graphics.pop()
end

local tempRect2 = Rect2()

---@param self Toolbox.EditableScene
local function drawForegroundGizmos(self)
	local mainWindow = Tool.mainWindow
	local selected = mainWindow.sceneTree:getSelectedNode()

	if selected then
		local zoom = self.camera._zoom.x
		local pixelScale = selected:getViewport()._pixelScale
		local scaleFactor = 1 / pixelScale
		local baseThickness = zoom * scaleFactor

		love.graphics.push("transform")
		love.graphics.scale(pixelScale)

		if selected:is(Node2d) then
			---@cast selected Node2d
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
			love.graphics.setLineWidth(3 * baseThickness)
			love.graphics.setColor(0.8, 0.5, 0.5)
			love.graphics.rectangle("line", gcr:unpack())

			-- Draw axes
			local globalX, globalY = selected:getPosition(true)
			love.graphics.setColor(1, 0, 0, 0.8)
			love.graphics.line(globalX, globalY, selected:toGlobal(zoom * 10, 0))
			love.graphics.setColor(0, 1, 0, 0.8)
			love.graphics.line(globalX, globalY, selected:toGlobal(0, zoom * 10))

		elseif selected:is(Control) then
			---@cast selected Control
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
			love.graphics.rectangle("line", tempRect2:unpack())
		end

		love.graphics.pop()
	end
end


local tempTransform = love.math.newTransform()
local alwaysApplyTransform = nil
local replaceTransformOverride = function(newTransform)
	lgReplaceTransform(alwaysApplyTransform)
	if newTransform ~= alwaysApplyTransform then
		love.graphics.applyTransform(newTransform)
	end
end

---@param self Toolbox.EditableScene
---@param subroot RootNode
function drawDirectSubroot(self, subroot)
	drawBackgroundGizmos(self)

	local layers = subroot._canvasLayers
	local ownViewport = assert(self._subViewport)
	---@type love.Transform # The Transform to reset back to
	local ownTransform = ownViewport._viewportTransform
	---@type love.Transform # The Transform used while drawing, which may be modified slightly from `ownTransform`
	local usedTransform = tempTransform:setMatrix(ownTransform:getMatrix())

	local camera = self.camera
	local oldX, oldY = camera._position:unpack()

	-- Change the origin for replaceTransform (for Controls)
	love.graphics.replaceTransform = replaceTransformOverride

	love.graphics.push("all")
	love.graphics.origin()
	for i = 1, #layers do
		local layer = layers[i]
		---@cast layer CanvasLayer
		if layer:isVisibleInTree() then
			---@class Viewport
			local viewport = layer._viewport
			local oldTransform = viewport._viewportTransform

			-- Alt-transform is used for converting Toolbox-space to Viewport world-space
			local altTransform = viewport._toolboxTransform
			if not altTransform then
				altTransform = love.math.newTransform()
				---@type love.Transform # Toolbox-exclusive transform; converts from the Toolbox window to Viewport world-space
				viewport._toolboxTransform = altTransform
			end

			viewport._viewportTransform = altTransform
			local scaleFactor = 1 / viewport._pixelScale

			camera:setPosition(oldX * scaleFactor, oldY * scaleFactor)
			camera:_updateCanvasTransform(viewport:getDimensions())
			altTransform:setMatrix(camera:getCanvasTransform():getMatrix())
			alwaysApplyTransform = altTransform

			-- TODO: Scale `usedTransform` by `scaleFactor`?
			-- A pixel in this Viewport is not equal to a pixel in the root Viewport.
			-- However, leaving it unscaled makes it easy to gauge how the UI looks on top of the game world.
			-- Unscaled also makes 100% zoom always pixel perfect.

			love.graphics.push("all")
			layer:drawLayer()
			love.graphics.pop()

			viewport._viewportTransform = oldTransform
		end
	end

	-- Reset back to normal
	camera:setPosition(oldX, oldY)
	love.graphics.replaceTransform = lgReplaceTransform
	love.graphics.pop()

	drawForegroundGizmos(self)
end
end

---Updates the Viewport with the drawn contents of the subroot, but skips its own layers
function EScene:drawEditableRootIntoViewport()
	local sx, sy, sw, sh = love.graphics.getScissor()
	love.graphics.push("all")
	love.graphics.origin()
	love.graphics.setScissor()
	local subviewport = assert(self._subViewport)
	subviewport:push()
	---@type integer # The stack depth after pushing
	local formerDepth = love.graphics.getStackDepth()

	local subroot = assert(self.subroot)
	local oldRoot = Node._root
	Node._root = subroot

	local success, err = xpcall(drawDirectSubroot, handleDirectDrawError, self, subroot)
	if not success then
		print("Errored while drawing subroot directly:")
		print(err)

		self._errorMessage, lastError = lastError
		love.graphics.replaceTransform = lgReplaceTransform

		-- Pop the stack until we're back at the original state
		for i = love.graphics.getStackDepth(), formerDepth + 1, -1 do
			love.graphics.pop()
		end
	end

	Node._root = oldRoot

	subviewport:pop()
	love.graphics.pop()
	love.graphics.setScissor(sx, sy, sw, sh)
	if not success then
		self:drawErrorIntoViewport()
	end
end

---Draws the error message into the Viewport
function EScene:drawErrorIntoViewport()
	local sx, sy, sw, sh = love.graphics.getScissor()
	love.graphics.push("all")
	love.graphics.origin()
	love.graphics.setScissor()
	self._subViewport:push()

	love.graphics.setColor(0.3, 0.3, 0.6)
	love.graphics.rectangle("fill", 0, 0, self._subViewport:getDimensions())
	love.graphics.setColor(1, 1, 1)
	love.graphics.print(self._errorMessage, 50, 50)

	self._subViewport:pop()
	love.graphics.pop()
	love.graphics.setScissor(sx, sy, sw, sh)
end

function EScene:_intDraw()
	if not self._errorMessage then
		if self.directDraw then
			self:drawEditableRootIntoViewport()
		else
			self:drawGameRootIntoViewport()
		end
	else
		self:drawErrorIntoViewport()
	end

	self._subViewport:drawFittedContents(self._localContentRect.x, self._localContentRect.y)
end

function EScene:update(_)
	if not self._visible then return end
	Tool.srContainer = self

	local camera = self.camera
	local layers = self.subroot._canvasLayers
	for i = 1, #layers do
		local layer = layers[i]
		if layer:ownsViewport() then
			layer._viewport:performRefreshesUntilDone()
		end
	end

	local subviewport = assert(self._subViewport)
	if self.cameraActive and not self._errorMessage then
		-- subviewport._activeCamera = camera
		camera:_updateCanvasTransform(self._subViewport:getDimensions())
		subviewport._viewportTransform:setMatrix(camera:getCanvasTransform():getMatrix())
	else
		-- subviewport._activeCamera = nil
		subviewport._viewportTransform:reset()
	end
end

function EScene:mousemoved(...)
	-- Don't handle anything without free-cam
	if not self.cameraActive then return false end

	self.tool:mousemoved(...)
end

function EScene:mousepressed(mx, my, button, isTouch, pressCount)
	-- Don't handle anything without free-cam
	if not self.cameraActive then return false end

	if self.tool:mousepressed(mx, my, button, isTouch, pressCount) then
		self:pushModal()
		return true
	elseif button == 1 and self._errorMessage then
		-- Clear the error message
		self._errorMessage = nil
		return true
	end
end

function EScene:mousereleased(...)
	-- Don't handle anything without free-cam
	if not self.cameraActive then return false end

	self.tool:mousereleased(...)
	if not self.tool:isBusy() then
		self:popModal()
	end
end

function EScene:wheelmoved(...)
	-- Don't handle anything without free-cam
	if not self.cameraActive then return false end

	self.tool:wheelmoved(...)
end

return EScene
