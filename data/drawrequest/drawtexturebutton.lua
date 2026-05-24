---@type AdoreInit
local Adore = require ""
local DrawRequest = Adore.Resources("DrawRequest")
local StretchModeHandlers = require "data.drawrequest.stretchmodehandlers"
local Color = Adore.Common("Color")
local mixRGBA = Color.mixRGBA

---@class DrawRequest.TextureButton: DrawRequest
---@overload fun(backgroundColor: integer[]?, angle: number?, textureAlbedo: integer[]?): DrawRequest.TextureButton
local DrawTextureButton = DrawRequest:extend()
DrawTextureButton.CLASS_NAME = "DrawTexture"

function DrawTextureButton:new(backgroundColor, angle, textureAlbedo)
	DrawTextureButton.super.new(self)

	---@type number
	self.angle = angle or 8
	---@type integer[] # The background color, will be mixed with the Control's albedo
	self.backgroundColor = backgroundColor or {1, 1, 1}
	---@type integer[]
	self.textureAlbedo = textureAlbedo or {1, 1, 1, 1}
end

---@param texRect TextureButton
function DrawTextureButton:themeUpdate(texRect)
	DrawTextureButton.super.themeUpdate(self, texRect)
	local texture = texRect._texture
	if texture then
		local stretchMode = texRect._stretchMode
		StretchModeHandlers[stretchMode](texRect, texture)
	end
end

---@param texButton TextureButton
function DrawTextureButton:draw(texButton)
	local lcr = texButton._localContentRect
	local x, y, w, h = lcr.x, lcr.y, lcr.w, lcr.h
	local r, g, b, a = love.graphics.getColor()

	love.graphics.intersectScissor(x, y, w, h)

	-- Draw the button's background
	love.graphics.setColor(mixRGBA(r, g, b, a, unpack(self.backgroundColor, 1, 4)))
	love.graphics.rectangle("fill", x, y, w, h, self.angle)

	local tSource = texButton._texture
	if tSource then
		-- Draw the texture
		love.graphics.setColor(mixRGBA(r, g, b, a, unpack(self.textureAlbedo, 1, 4)))
		love.graphics.draw(
			tSource.texture, tSource.quad,
			x + texButton._textureX,
			y + texButton._textureY,
			0,
			texButton._textureScaleX,
			texButton._textureScaleY
		)
	end
end

return DrawTextureButton
