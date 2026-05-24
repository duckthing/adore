---@type AdoreInit
local Adore = require ""
local DrawRequest = Adore.Resources("DrawRequest")
local StretchModeHandlers = require("data.drawrequest.stretchmodehandlers")

---@class DrawRequest.TextureRect: DrawRequest
---@overload fun(): DrawRequest.Label
local DrawTexture = DrawRequest:extend()
DrawTexture.CLASS_NAME = "DrawTexture"

---@param texRect TextureRect
function DrawTexture:themeUpdate(texRect)
	DrawTexture.super.themeUpdate(self, texRect)
	local texture = texRect._texture
	if texture then
		local stretchMode = texRect._stretchMode
		StretchModeHandlers[stretchMode](texRect, texture)
	end
end

---@param texRect TextureRect
function DrawTexture:draw(texRect)
	local tSource = texRect._texture
	if tSource then
		local lcr = texRect._localContentRect
		love.graphics.draw(
			tSource.texture, tSource.quad,
			lcr.x + texRect._textureX,
			lcr.y + texRect._textureY,
			0,
			texRect._textureScaleX,
			texRect._textureScaleY
		)
	end
end

return DrawTexture
