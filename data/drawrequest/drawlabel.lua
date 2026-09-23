---@type AdoreInit
local Adore = require ""
local DrawRequest = Adore.Resources("DrawRequest")
local FontLoader = Adore.Loader.getCollection("FontLoader")
local AutoWrap = Adore.Common("AutoWrap")

---@class DrawRequest.Label: DrawRequest
---@overload fun(): DrawRequest.Label
local DrawLabel = DrawRequest:extend()
DrawLabel.CLASS_NAME = "DrawLabel"

local DEFAULT_FONT = FontLoader:get("")
local DEFAULT_FONT_SIZE = 0

---@param label Label
function DrawLabel:themeUpdate(label)
	DrawLabel.super.themeUpdate(self, label)
	local lcr = label._localContentRect
	local text = label._text
	local textBatch = label._textBatch
	local wrapMode= label._autowrap
	local tbOldWidth, tbOldHeight = textBatch:getDimensions()
	local labelWidth, labelHeight = lcr.w, lcr.h

	textBatch:setFont((label._font or DEFAULT_FONT)[label._fontSize or DEFAULT_FONT_SIZE])
	AutoWrap[wrapMode](textBatch, text, labelWidth, label._align)

	local tbWidth, tbHeight = textBatch:getDimensions()

	if not label._clipText then
		-- If we're not clipping, we might have to resize the Label
		if labelHeight < tbHeight then
			-- If too small, resize the Label
			label:_setCanonRect(lcr.x, lcr.y, labelWidth, tbHeight)
			label._textBatchY = 0
			return
		elseif tbHeight < tbOldHeight then
			-- TextBatch height is smaller now
			-- Refresh again, as the Label might have refreshed with the wrong minimum height
			label:deferRefreshSelf()
			return
		elseif wrapMode == "none" and tbWidth ~= tbOldWidth then
			-- TextBatch width is different now
			-- Refresh again, as the Label might have refreshed with the wrong minimum width
			-- (Which matters more when wrapping is disabled)
			label:deferRefreshSelf()
			return
		end
	end

	local justify = label._justify
	if justify == "top" then
		-- Top
		label._textBatchY = 0
	elseif justify == "center" then
		-- Center
		label._textBatchY = (labelHeight - tbHeight) * 0.5
	else
		-- Bottom
		label._textBatchY = (labelHeight - tbHeight)
	end
end

---@param label Label
function DrawLabel:draw(label)
	if label._clipText then
		local gcr = label._globalContentRect
		love.graphics.intersectScissor(gcr.x, gcr.y, gcr.w, gcr.h)
	end
	local lcr = label._localContentRect
	love.graphics.draw(label._textBatch, lcr.x, lcr.y + label._textBatchY)
end

return DrawLabel
