---@type AdoreInit
local Adore = require ""
local BaseButton = Adore.Nodes("BaseButton")
local max = math.max

---@class TextureButton: BaseButton
---@field super BaseButton
---@overload fun(tSource: TextureSource?): TextureButton
local TextureButton = BaseButton:extend()
TextureButton.CLASS_NAME = "TextureButton"
---@type TextureRect.StretchMode # How the texture is resized inside of the TextureButton
TextureButton._stretchMode = "keepCentered"
---@type boolean # Whether this TextureButton can be resized smaller than the texture
TextureButton._allowTextureShrink = true

function TextureButton:new(tSource)
	TextureButton.super.new(self)

	---@type TextureSource? # The TextureSource used for this TextureButton
	self._texture = tSource

	---@type integer, integer # [Internal] The texture offset
	self._textureX, self._textureY = 0, 0
	---@type integer, integer # [Internal] The texture scale
	self._textureScaleX, self._textureScaleY = 1, 1
end

function TextureButton:getMinimumSize()
	local minW, minH = TextureButton.super.getMinimumSize(self)
	local tSource = self._texture
	if tSource and not self._allowTextureShrink then
		local _, _, iconW, iconH = tSource.quad:getViewport()
		return max(minW, iconW), max(minH, iconH)
	else
		return minW, minH
	end
end

---Sets the texture used for the TextureButton
---@param texture TextureSource?
---@return self
function TextureButton:setTexture(texture)
	if self._texture ~= texture then
		self._texture = texture
		self:deferRefreshSelf()
	end
	return self
end

---Sets how the texture stretches
---@param mode TextureRect.StretchMode
---@return self
function TextureButton:setStretchMode(mode)
	if self._stretchMode ~= mode then
		self._stretchMode = mode
		self:deferRefreshSelf()
	end
	return self
end

---Sets whether the TextureButton can be made smaller than the texture itself
---@param shrink boolean
---@return TextureButton
function TextureButton:setTextureShrink(shrink)
	if self._allowTextureShrink ~= shrink then
		self._allowTextureShrink = shrink
		self:deferRefreshSelf()
	end
	return self
end

function TextureButton._addDefinition(entry)
	local stretchModes = {
		scale = true,
		tile = true,
		keep = true,
		keepCentered = true,
		keepAspect = true,
		keepAspectCentered = true,
	}
	entry:newEnum("_stretchMode", stretchModes, "keepCentered", "setStretchMode")
	entry:newBoolean("_allowTextureShrink", true, "setTextureShrink")
end

return TextureButton
