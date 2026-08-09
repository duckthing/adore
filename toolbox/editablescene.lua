local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local Resources = Adore.Resources

local Node = Nodes("Node")
local ViewportContainer = Nodes("ViewportContainer")
local RootNode = Nodes("RootNode")
local Viewport = Resources("Viewport")
local Camera = Nodes("Camera")

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

function EScene:new(root)
	EScene.super.new(self, Viewport({}))
	self:setAnchors(0, 0, 1, 1)

	---@type RootNode[]
	self._lastRoot = {}

	---@type RootNode? # The subroot contained by this scene
	self.subroot = root

	---@type boolean # If we are using the camera
	self.cameraActive = true
	---@type boolean # If we are not drawing with the subroot's Viewports
	self.directDraw = true
	---@type Camera # The camera used for the editor
	self.camera = Camera()

	---@type boolean # Whether this can call `:update`
	self._running = false
	---@type string? # The error message from the last method call
	self._errorMessage = nil
	---@type string? # The last file path this EditableScene interacted with
	self._lastFilepath = nil
	---@type ObjectSaver.Format? # The last format this was saved in
	self._lastFormat = nil
end

function EScene:_setCanonRect(x, y, w, h)
	self._viewportFits = w > 1 and h > 1
	if self._viewportFits then
		self:resizeViewport(w, h)
		self.subroot:resize(self._subViewport:getDimensions())
		self:drawRootIntoViewport()
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
	self:pushSubroot()
	self.subroot = RootNode({
		hideSceneWarning = true,
		drawControlDebug = true,
		physicsWorld = love.physics.newWorld(),
		ownsPhysicsWorld = true,
	}, Adore.Resources("DefaultTheme")())
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
function EScene:drawRootIntoViewport()
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

local oldReplaceTransform = love.graphics.replaceTransform
local oldOrigin = love.graphics.origin
local alwaysApplyTransform = nil
local originOverride = function()
	oldReplaceTransform(alwaysApplyTransform)
end
local replaceTransformOverride = function(...)
	oldReplaceTransform(alwaysApplyTransform)
	love.graphics.applyTransform(...)
end

---@param self Toolbox.EditableScene
local function drawBackgroundGizmos(self)
	local thickness = 3 * self.camera._zoom.x
	local bounds = self._subViewport._boundingBox

	love.graphics.push("all")
	love.graphics.setLineWidth(thickness)
	love.graphics.setColor(0, 1, 0, 0.8)
	love.graphics.line(0, bounds.y, 0, bounds.y + bounds.h)
	love.graphics.setColor(1, 0, 0, 0.8)
	love.graphics.line(bounds.x, 0, bounds.x + bounds.w, 0)

	love.graphics.setColor(0.3, 0.3, 0.7, 0.8)
	love.graphics.rectangle("line", 0, 0, self._subViewport:getDimensions())
	love.graphics.pop()
end

---@param self Toolbox.EditableScene
---@param subroot RootNode
local function drawDirectSubroot(self, subroot)
	local layers = subroot._canvasLayers

	-- Change the origin + graphics functions that set it
	alwaysApplyTransform = self._subViewport._viewportTransform
	love.graphics.replaceTransform = replaceTransformOverride
	love.graphics.origin = originOverride

	drawBackgroundGizmos(self)
	for i = 1, #layers do
		local layer = layers[i]
		if layer:isVisibleInTree() then
			---@cast layer CanvasLayer
			love.graphics.push("all")
			layer:_drawChildren()
			love.graphics.pop()
		end
	end

	-- Make the origin normal
	love.graphics.replaceTransform = oldReplaceTransform
	love.graphics.origin = oldOrigin
end

---Updates the Viewport with the drawn contents of the subroot, but skips its own layers
function EScene:drawDirectRootIntoViewport()
	local sx, sy, sw, sh = love.graphics.getScissor()
	love.graphics.push("all")
	love.graphics.origin()
	love.graphics.setScissor()
	self._subViewport:push()

	local subroot = assert(self.subroot)
	local oldRoot = Node._root
	Node._root = subroot

	local success, err = xpcall(drawDirectSubroot, handleSubrootError, self, subroot)
	if not success then
		print(("Errored while drawing subroot directly:"):format(tostring(self)))
		print(err)

		self._errorMessage, lastError = lastError
	end

	Node._root = oldRoot

	self._subViewport:pop()
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
			self:drawDirectRootIntoViewport()
		else
			self:drawRootIntoViewport()
		end
	else
		self:drawErrorIntoViewport()
	end

	self._subViewport:drawFittedContents(self._localContentRect.x, self._localContentRect.y)
end

local isDown = love.keyboard.isDown
local SPEED_PER_SECOND = 500
function EScene:update(dt)
	if not self._visible then return end
	local camera = self.camera
	local speed = SPEED_PER_SECOND * dt * camera._zoom.x
	local x, y = 0, 0
	if isDown("a") then x = x - speed end
	if isDown("d") then x = x + speed end
	if isDown("w") then y = y - speed end
	if isDown("s") then y = y + speed end
	if isDown("-") then camera._zoom:iMult(1 + (dt * 5)) end
	if isDown("=") then camera._zoom:iMult(1 - (dt * 5)) end

	local subviewport = assert(self._subViewport)
	if x ~= 0 or y ~= 0 then
		camera:translate(x, y)
	end

	local layers = self.subroot._canvasLayers
	for i = 1, #layers do
		local layer = layers[i]
		if layer:ownsViewport() then
			layer._viewport:performRefreshesUntilDone()
		end
	end

	if self.cameraActive and not self._errorMessage then
		-- subviewport._activeCamera = camera
		camera:_updateCanvasTransform(self._subViewport:getDimensions())
		subviewport._viewportTransform:setMatrix(camera:getCanvasTransform():getMatrix())
	else
		-- subviewport._activeCamera = nil
		subviewport._viewportTransform:reset()
	end
end

return EScene
