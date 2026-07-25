local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local Resources = Adore.Resources

local Node = Nodes("Node")
local ViewportContainer = Nodes("ViewportContainer")
local Viewport = Resources("Viewport")

---Not a class, to not pollute with useless suggestions
---@type ViewportContainer
local EditableScene = ViewportContainer:extend()
EditableScene.CLASS_NAME = "EditableScene"
EditableScene._pauseMode = "disabled"

do
	-- Mark this class as something that changes a Viewport
	local arr = Node.OVERRIDES_VIEWPORT
	arr[#arr+1] = EditableScene
end

function EditableScene:new()
	EditableScene.super.new(self, Viewport({
		pixelScale = 4,
		physicsWorld = love.physics.newWorld(),
		ownsPhysicsWorld = true,
	}))
	self:setAnchors(0, 0, 1, 1)

	self:addChild(Nodes("ColorRect")():setAnchors(0, 0, 0.5, 0.5))
end

return EditableScene
