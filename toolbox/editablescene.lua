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
---@overload fun(self, scene: string? | SceneFactory, root: RootNode?): Toolbox.EditableScene
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

	---@type RootNode?
	self._lastRoot = nil

	---@type RootNode? # The subroot contained by this scene
	self.subroot = root
	if not root then
		self:createRoot()
	end

	self:changeScene(scene)
end

function EScene:_setCanonRect(x, y, w, h)
	self._viewportFits = w > 1 and h > 1
	if self._viewportFits then
		self:resizeViewport(w, h)
		self.subroot:resize(self._subViewport:getDimensions())
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

function EScene:pushSubroot()
	self._lastRoot = Node._root
	Node._root = self.subroot
end

function EScene:popSubroot()
	Node._root = self._lastRoot
	self._lastRoot = nil
end

---Calls a method on the subroot
---@param methodName string
---@param ... unknown
---@return true success # Whether this method didn't crash
---@overload fun(self, methodName: string, ...: unknown): false, string
function EScene:handleOnSubroot(methodName, ...)
	-- TODO: Understand why this check prevents stack overflows?
	if not self._lastRoot then
		self:pushSubroot()
		local subroot = self.subroot
		local success, err = pcall(subroot[methodName], subroot, ...)
		self:popSubroot()
		return success, err
	end
	return false, "Pushed while in another root"
end

function EScene:_intDraw()
	local sx, sy, sw, sh = love.graphics.getScissor()
	love.graphics.push("all")
	love.graphics.origin()
	love.graphics.setScissor()
	self._subViewport:push()

	self:handleOnSubroot("draw")

	self._subViewport:pop()
	love.graphics.pop()
	love.graphics.setScissor(sx, sy, sw, sh)

	self._subViewport:drawFittedContents(self._localContentRect.x, self._localContentRect.y)
end

function EScene:update(dt)
	if self._visible then
		self:handleOnSubroot("update", dt)
	end
end

return EScene
