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
---@class EditableScene: ViewportContainer
local EScene = ViewportContainer:extend()
EScene.CLASS_NAME = "EditableScene"

do
	-- Mark this class as something that changes a Viewport
	local arr = Node.OVERRIDES_VIEWPORT
	arr[#arr+1] = EScene
end

function EScene:new(scene)
	EScene.super.new(self, Viewport({}))
	self:setAnchors(0, 0, 1, 1)

	---@type RootNode?
	self._lastRoot = nil

	self:pushSubroot()
	self.pseudoRoot = RootNode({
		-- pixelScale = 2,
		physicsWorld = love.physics.newWorld(),
		ownsPhysicsWorld = true,
	}, Adore.Resources("DefaultTheme")())
	self:popSubroot()

	self:pushSubroot()
	local sceneType = type(scene)
	if sceneType == "string" then
		self.pseudoRoot:changeSceneTo(require(scene))
	elseif sceneType == "table" then
		self.pseudoRoot:changeSceneTo(scene)
	end
	self:popSubroot()
end

function EScene:_setCanonRect(x, y, w, h)
	self._viewportFits = w > 1 and h > 1
	if self._viewportFits then
		self:resizeViewport(w, h)
		self.pseudoRoot:resize(w, h)
	end
	ViewportContainer.super._setCanonRect(self, x, y, w, h)
end

function EScene:pushSubroot()
	self._lastRoot = Node._root
	Node._root = self.pseudoRoot
end

function EScene:popSubroot()
	Node._root = self._lastRoot
	self._lastRoot = nil
end

function EScene:_intDraw()
	local sx, sy, sw, sh = love.graphics.getScissor()
	love.graphics.push("all")
	love.graphics.reset()
	love.graphics.setScissor()
	self._subViewport:push()

	self:pushSubroot()
	self.pseudoRoot:draw()
	self:popSubroot()

	self._subViewport:pop()
	love.graphics.pop()
	love.graphics.setScissor(sx, sy, sw, sh)

	self._subViewport:drawFittedContents(self._localContentRect.x, self._localContentRect.y)
end

function EScene:update(dt)
	if not self._lastRoot then
		if self._visible then
			self:pushSubroot()
			-- self.pseudoRoot:update(dt)
			self:popSubroot()
		end
	end
end

return EScene
