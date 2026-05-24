---@type AdoreInit
local Adore = require ""
local Light2d = Adore.Nodes("Light2d")

---@class PointLight2d: Light2d
---@overload fun(x: number?, y: number?, tSource: TextureSource?): PointLight2d
local PointLight2d = Light2d:extend()

function PointLight2d:new(x, y, tSource)
	PointLight2d.super.new(self, x, y)

	---@type TextureSource?
	self._lightTexture = nil

	---@type boolean
	self._centered = false

	---@type number, number # The offset of the texture
	self._offsetX, self._offsetY =
		0, 0

	self:setTexture(tSource)
end

function PointLight2d:_updateOffset()
	local tSource = self._lightTexture
	if not tSource then
		self._localContentRect:iSetComponents(0, 0, 0, 0)
		return
	end

	local _, _, tw, th = tSource.quad:getViewport()
	local offsetX, offsetY = 0, 0
	if self._centered then
		offsetX, offsetY =
			-tw * 0.5, th * -0.5
	end
	self._offsetX, self._offsetY = offsetX, offsetY

	self._localContentRect:iSetComponents(offsetX, offsetY, tw, th)
end

---Sets the TextureSource used for the PointLight2d
---@param tSource TextureSource?
---@return self
function PointLight2d:setTexture(tSource)
	if self._lightTexture ~= tSource then
		self._lightTexture = tSource
		self:_updateOffset()
	end
	return self
end

---Sets whether the TextureSource is centered
---@param centered boolean
---@return self
function PointLight2d:setCentered(centered)
	if self._centered ~= centered then
		self._centered = centered
		self:_updateOffset()
	end
	return self
end

function PointLight2d:draw()
	local tSource = self._lightTexture
	if not tSource then return end

	local px, py = self._offsetX, self._offsetY

	love.graphics.draw(tSource.texture, tSource.quad, px, py)
end

return PointLight2d
