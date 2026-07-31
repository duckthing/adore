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

---Not a class, to not pollute with useless suggestions
---@class Toolbox.EditableScene: ViewportContainer
---@overload fun(root: RootNode?): Toolbox.EditableScene
local EScene = ViewportContainer:extend()
EScene.CLASS_NAME = "EditableScene"
EScene._pauseMode = "never"

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

	---@type boolean # Whether this can call `:update`
	self._running = false
	---@type string? # The error message from the last method call
	self._errorMessage = nil
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
		-- pixelScale = 2,
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
	local success, err = xpcall(subroot[methodName], debug.traceback, subroot, ...)
	if not success then
		self._errorMessage = err

		print(("Errored while calling '%s' on subroot inside of '%s':"):format(methodName, tostring(self)))
		print(err)
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
	if self:isRunning() then
		self:drawRootIntoViewport()
	elseif self._visible and self._errorMessage then
		self:drawErrorIntoViewport()
	end

	self._subViewport:drawFittedContents(self._localContentRect.x, self._localContentRect.y)
end

function EScene:update(dt) end

return EScene
