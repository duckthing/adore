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
---@overload fun(scene: string? | SceneFactory, root: RootNode?): Toolbox.EditableScene
local EScene = ViewportContainer:extend()
EScene.CLASS_NAME = "EditableScene"
EScene._pauseMode = "never"

do
	-- Mark this class as something that changes a Viewport
	local arr = Node.OVERRIDES_VIEWPORT
	arr[#arr+1] = EScene
end

function EScene:new(scene, root)
	EScene.super.new(self, Viewport({}))
	self:setAnchors(0, 0, 1, 1)

	---@type RootNode[]
	self._lastRoot = {}

	---@type RootNode? # The subroot contained by this scene
	self.subroot = root
	if not root then
		self:createRoot()
	end

	---@type boolean # Whether this can call `:update`
	self._running = false

	self:changeScene(scene)
end

function EScene:_setCanonRect(x, y, w, h)
	self._viewportFits = w > 1 and h > 1
	if self._viewportFits then
		self:resizeViewport(w, h)
		self.subroot:resize(self._subViewport:getDimensions())
		self:putIntoViewport()
	end
	ViewportContainer.super._setCanonRect(self, x, y, w, h)
end

function EScene:createRoot()
	self:pushSubroot()
	self.subroot = RootNode({
		-- pixelScale = 2,
		physicsWorld = love.physics.newWorld(),
		ownsPhysicsWorld = true,
	}, Adore.Resources("DefaultTheme")())
	self:popSubroot()
end

function EScene:changeScene(scene)
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
	assert(#self._lastRoot ~= 0, "Root stack is empty")
	Node._root, self._lastRoot[#self._lastRoot] = self._lastRoot[#self._lastRoot], nil
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
	self:pushSubroot()
	local subroot = self.subroot
	local success, err = pcall(subroot[methodName], subroot, ...)
	self:popSubroot()
	return success, err
end

---Returns `true` if this subroot is getting updated
---@return boolean running
function EScene:isRunning()
	return self._visible and self._running
end

---Updates the Viewport with the drawn contents of the subroot
function EScene:putIntoViewport()
	local sx, sy, sw, sh = love.graphics.getScissor()
	love.graphics.push("all")
	love.graphics.origin()
	love.graphics.setScissor()
	self._subViewport:push()

	self:handleOnSubroot("draw")

	self._subViewport:pop()
	love.graphics.pop()
	love.graphics.setScissor(sx, sy, sw, sh)
end

function EScene:_intDraw()
	if self:isRunning() then
		self:putIntoViewport()
	end

	self._subViewport:drawFittedContents(self._localContentRect.x, self._localContentRect.y)
end

function EScene:update(dt) end

return EScene
