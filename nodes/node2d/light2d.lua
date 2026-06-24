---@type AdoreInit
local Adore = require ""
local Node2d = Adore.Nodes("Node2d")
local ShaderLoader, _ = Adore.Loader.getCollection("ShaderLoader")

---Base class of other lights
---@class Light2d: Node2d
---@field super Node2d
---@overload fun(x: number?, y: number?): Light2d
local Light2d = Node2d:extend()
Light2d.CLASS_NAME = "Light2d"
Light2d.albedo = {1, 1, 1, 1}
local LIGHT_SHADER = ShaderLoader:get(("%s/shaders/lightshader.glsl"):format(
	(Adore.PATH):gsub("%.", "/")
))
---@type love.BlendMode # "add" is the default, and provides normal light behavior
Light2d._lightBlendMode = "add"

function Light2d:new(x, y)
	Light2d.super.new(self, x, y)

	---@type boolean # Whether this Light2d can cast shadows; does not work with the "screen" light mode
	self._shadows = true
end

function Light2d:_intDraw()
	-- Prevent the :draw() function from being called normally
	self:_beforeDraw()
	self:_drawChildren()
	self:_afterDraw()
end

function Light2d:draw() end

function Light2d:_drawLight()
	-- Don't override; it calls `:draw()` when it's time to draw a light
	love.graphics.push("all")
	love.graphics.applyTransform(self._globalTransform)
	love.graphics.setBlendMode(self._lightBlendMode, "alphamultiply")
	-- Did you get an error about a missing 7th argument?
	-- You need `albedo` to have four components, and you probably missed the alpha component.
	-- Do this: `{1, 1, 1, 1}`
	LIGHT_SHADER:send("LightColor", self.albedo)
	love.graphics.setShader(LIGHT_SHADER)
	self:draw()
	love.graphics.pop()
end

function Light2d:onViewportRemoved(oldViewport)
	oldViewport._lightShash:remove(self)
end

function Light2d:onViewportAdded(newViewport)
	local rect = self._globalContentRect
	newViewport._lightShash:add(self, rect.x, rect.y, rect.w, rect.h)
end

function Light2d:_onGlobalBoundsChanged()
	Light2d.super._onGlobalBoundsChanged(self)
	local viewport = self._parentViewport
	if viewport then
		local rect = self._globalContentRect
		viewport._lightShash:update(self, rect.x, rect.y, rect.w, rect.h)
	end
end

function Light2d._addDefinition(entry)
	entry:newBoolean("_shadows", true)
end

return Light2d
