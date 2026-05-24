---@type AdoreInit
local Adore = require ""
local DrawRequest = Adore.Resources("DrawRequest")
local Loader = Adore.Loader
local fontCollection = Loader.getCollection("love.Font")
local fontAssets = fontCollection.assets

---@class DrawRequest.Label: DrawRequest
---@overload fun(): DrawRequest.Label
local DrawLabel = DrawRequest:extend()
DrawLabel.CLASS_NAME = "DrawLabel"

local defaultFont, _ = fontCollection:get("")
local defaultFontSize = 0

---@param label Label
function DrawLabel:themeUpdate(label)
	DrawLabel.super.themeUpdate(self, label)
	local text = label._text
	local textBatch = label._textBatch
	local tbOldHeight = textBatch:getHeight()

	textBatch:setFont((label._font or defaultFont)[label._fontSize or defaultFontSize])
	textBatch:setf(text, label._localContentRect.w, label._align)

	local lcr = label._localContentRect
	local tbHeight = textBatch:getHeight()
	local labelHeight = lcr.h

	if labelHeight < tbHeight then
		-- If too small, resize the Label
		label:_setCanonRect(lcr.x, lcr.y, lcr.w, tbHeight)
		label._textBatchY = 0
		return
	elseif tbHeight < tbOldHeight then
		-- TextBatch is smaller now
		-- Refresh again, as the Label might have refreshed with the wrong minimum height
		label:deferRefreshSelf()
	end

	local justify = label._justify
	if justify == "top" then
		-- Top
		label._textBatchY = 0
	elseif justify == "center" then
		-- Center
		label._textBatchY = (lcr.h - tbHeight) * 0.5
	else
		-- Bottom
		label._textBatchY = (lcr.h - tbHeight)
	end
end

---@param label Label
function DrawLabel:draw(label)
	local lcr = label._localContentRect
	love.graphics.draw(label._textBatch, lcr.x, lcr.y + label._textBatchY)
end

return DrawLabel
