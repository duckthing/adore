---@type AdoreInit
local Adore = require ""
local Control = Adore.Nodes("Control")

---@alias TextureRect.StretchMode
---| "scale"
---| "tile"
---| "keep"
---| "keepCentered"
---| "keepAspect"
---| "keepAspectCentered"

---@class TextureRect: Control
---@field super Control
---@overload fun(): TextureRect
local TextureRect = Control:extend()
TextureRect.CLASS_NAME = "TextureRect"
---@type TextureRect.StretchMode # How the texture is resized inside of the TextureRect
TextureRect._stretchMode = "keepCentered"

function TextureRect:new()
	TextureRect.super.new(self)

	---@type TextureSource? # The TextureSource used to draw this TextureRect
	self._texture = nil

	---@type integer, integer # The texture offset
	self._textureX, self._textureY = 0, 0
	---@type integer, integer # The texture scale
	self._textureScaleX, self._textureScaleY = 1, 1
end

---Sets the texture inside the Label
---@param texture TextureSource?
---@return self
function TextureRect:setTexture(texture)
	if self._texture ~= texture then
		self._texture = texture
		self:deferRefreshSelf()
	end
	return self
end

---Sets how the texture stretches
---@param mode TextureRect.StretchMode
---@return self
function TextureRect:setStretchMode(mode)
	if self._stretchMode ~= mode then
		self._stretchMode = mode
		self:deferRefreshSelf()
	end
	return self
end

function TextureRect:forceDestroy(recursive)
	TextureRect.super.forceDestroy(self, recursive)
end

return TextureRect
