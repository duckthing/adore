---@type AdoreInit
local Adore = require ""
local DrawRequest = Adore.Resources("DrawRequest")
local Color = Adore.Common("Color")
local AutoWrap = Adore.Common("AutoWrap")
local mixRGBA = Color.mixRGBA
local FontLoader = Adore.Loader.getCollection("FontLoader")

---@class DrawRequest.Button: DrawRequest
---@overload fun(backgroundColor: number[]?, angle: number?, iconAlbedo: number[]?, textAlbedo: number[]?): DrawRequest.Button
local DrawButton = DrawRequest:extend()
DrawButton.CLASS_NAME = "DrawButton"

local DEFAULT_FONT = FontLoader:get("")
local DEFAULT_FONT_SIZE = 0

function DrawButton:new(backgroundColor, angle, iconAlbedo, textAlbedo)
	DrawButton.super.new(self)

	---@type number[]
	self.backgroundColor = backgroundColor or {1, 1, 1, 1}
	---@type number[]
	self.iconColor = iconAlbedo or {1, 1, 1, 1}
	---@type number[]
	self.textColor = textAlbedo or {1, 1, 1, 1}

	---@type number
	self.angle = angle or 4
end

---@param button Button
function DrawButton:themeUpdate(button)
	DrawButton.super.themeUpdate(self, button)
	local lcr = button._localContentRect
	local buttonW, buttonH = lcr.w, lcr.h

	local text = button._text
	local textBatch = button._textBatch
	local textAlign = button._textAlign
	local tbOldWidth, tbOldHeight = textBatch:getDimensions()

	textBatch:setFont((button._font or DEFAULT_FONT)[button._fontSize or DEFAULT_FONT_SIZE])

	local wrapMode = button._autowrap
	AutoWrap[wrapMode](textBatch, text, buttonW, textAlign)

	local offsetX, offsetY = 0, 0
	local availableW, availableH = buttonW, buttonH

	local iconSource = button._icon
	if iconSource then
		local iconAlign, iconJustify = button._iconAlign, button._iconJustify
		local iconExpand = button._iconExpand
		local _, _, textureW, textureH = iconSource.quad:getViewport()
		local scale = 1

		---@type number, number # The max dimensions the icon has room for
		local iconSpaceW, iconSpaceH =
			buttonW - textBatch:getWidth(),
			buttonH - textBatch:getHeight()

		if iconExpand then
			if iconAlign ~= "center" then
				-- Constrained by width
				scale = iconSpaceW / textureW
			elseif iconJustify ~= "center" then
				-- Constrained by height
				scale = iconSpaceH / textureH
			else
				-- Constrained by both, but ignore the TextBatch
				scale = math.min(buttonW / textureW, buttonH / textureH)
			end
		end
		button._iconScale = scale

		local iconW, iconH =
			textureW * scale,
			textureH * scale

		if iconAlign == "center" then
			-- Icon in the center, horizontally
			button._iconX = (availableW - iconW) * 0.5
		elseif iconAlign == "left" then
			-- Icon on the left
			button._iconX = 0
			offsetX = iconW
		else
			-- Icon on the right
			button._iconX = availableW - iconW
		end

		if iconJustify == "center" then
			-- Icon in the center, vertically
			button._iconY = (availableH - iconH) * 0.5
		elseif iconJustify == "top" then
			-- Icon on the top
			button._iconY = 0
			offsetY = iconH
		else
			-- Icon on the bottom
			button._iconY = buttonH - iconH
		end

		if iconJustify == "center" and iconAlign == "center" then
			offsetX, offsetY =
				0, 0
			availableW, availableH =
				buttonW, buttonH
		else
			availableW, availableH =
				buttonW - iconW,
				buttonH - iconH
		end
	end

	local tbWidth, tbHeight = textBatch:getDimensions()
	if buttonH < tbHeight then
		button:_setCanonRect(lcr.x, lcr.y, buttonW, tbHeight)
		availableH = tbHeight
	elseif tbHeight < tbOldHeight then
		-- TextBatch is smaller now
		-- Refresh again, as the Button might have refreshed with the wrong minimum height
		button:deferRefreshSelf()
		return
	elseif wrapMode == "none" and tbWidth ~= tbOldWidth then
		-- TextBatch width is different now
		-- Refresh again, as the Button might have refreshed with the wrong minimum width
		-- (Which matters more when wrapping is disabled)
		button:deferRefreshSelf()
		return
	end

	button._textBatchX, button._textBatchY =
		offsetX,
		offsetY + (availableH - tbHeight) * 0.5
end

---@param button Button
function DrawButton:draw(button)
	local lcr = button._localContentRect
	local r, g, b, a = love.graphics.getColor()
	local x, y, w, h = lcr.x, lcr.y, lcr.w, lcr.h

	-- Draw the button's background
	love.graphics.setColor(mixRGBA(r, g, b, a, unpack(self.backgroundColor, 1, 4)))
	love.graphics.rectangle("fill", x, y, w, h, self.angle)

	local icon = button._icon
	if icon then
		-- Draw the icon
		local scale = button._iconScale
		love.graphics.setColor(mixRGBA(r, g, b, a, unpack(self.iconColor, 1, 4)))
		love.graphics.draw(icon.texture, icon.quad, x + button._iconX, y + button._iconY, 0, scale, scale)
	end

	-- Draw the text
	love.graphics.setColor(mixRGBA(r, g, b, a, unpack(self.textColor, 1, 4)))
	love.graphics.draw(button._textBatch, x + button._textBatchX, y + button._textBatchY)
end

return DrawButton
