---@type AdoreInit
local Adore = require ""
local DrawRequest = Adore.Resources("DrawRequest")
local Color = Adore.Common("Color")
local mixRGBA = Color.mixRGBA

local FontLoader = Adore.Loader.getCollection("FontLoader")
local DEFAULT_FONT = FontLoader:get("")
local DEFAULT_FONT_SIZE = 0

---@class DrawRequest.LineEdit: DrawRequest
---@overload fun(backgroundColor: number[]?, angle: number?, textColor: number[]?, placeholderColor: number[]?): DrawRequest.Button
local DrawLineEdit = DrawRequest:extend()
DrawLineEdit.CLASS_NAME = "DrawLineEdit"

function DrawLineEdit:new(backgroundColor, angle, textAlbedo, placeholderAlbedo)
	DrawLineEdit.super.new(self)

	---@type number[]
	self.backgroundColor = backgroundColor or {1, 1, 1, 1}
	---@type number[]
	self.textColor = textAlbedo or {1, 1, 1, 1}
	---@type number[]
	self.placeholderColor = placeholderAlbedo or {0.9, 0.9, 0.9, 0.7}

	---@type number
	self.angle = angle or 4
end

---@param edit LineEdit
function DrawLineEdit:themeUpdate(edit)
	DrawLineEdit.super.themeUpdate(self, edit)

	local inputField = edit._inputField
	local usedFont = (edit._font or DEFAULT_FONT)[edit._fontSize or DEFAULT_FONT_SIZE]

	inputField:setFont(usedFont)
	edit._textBatch:setFont(usedFont)
	edit._placeholderTextBatch:setFont(usedFont)

	-- Calculate the new local position and dimensions of the field
	local lcr = edit._localContentRect
	local editW, editH = lcr.w, lcr.h
	local offset = edit._lineOffset
	local margin = edit._fieldMargin
	local offsetX, offsetY = offset.x, offset.y
	local availableW, availableH = editW - margin.x * 2, editH - margin.y * 2
	local fieldH = inputField:getTextHeight()
	local fieldPosition = edit._fieldPosition
	fieldPosition.x, fieldPosition.y =
		margin.x, margin.y

	-- The Y offset
	if edit._justify == "center" then
		fieldPosition.y = fieldPosition.y + (availableH - fieldH) * 0.5
	elseif edit._justify == "bottom" then
		fieldPosition.y = fieldPosition.y + availableH - fieldH
	end

	inputField:setDimensions(availableW - offsetX, availableH - offsetY)

	edit._placeholderTextBatch:setf(edit._placeholderText, availableW - offsetX, edit._align)

	local batch = edit._textBatch
	local field = edit._inputField
	batch:clear()
	for _, text, x, y in field:eachVisibleLine() do
		batch:add(text, x + field:getScrollX(), y)
	end

	local tbHeight = batch:getHeight()
	if lcr.h < tbHeight then
		edit:_setCanonRect(lcr.x, lcr.y, editW, tbHeight)
	end
end

---@param edit LineEdit
function DrawLineEdit:draw(edit)
	local lcr = edit._localContentRect
	local r, g, b, a = love.graphics.getColor()
	local x, y, w, h = lcr.x, lcr.y, lcr.w, lcr.h

	love.graphics.intersectScissor(edit._globalContentRect:unpack())

	-- Draw the button's background
	love.graphics.setColor(mixRGBA(r, g, b, a, unpack(self.backgroundColor, 1, 4)))
	love.graphics.rectangle("fill", x, y, w, h, self.angle)

	local focused = edit:hasFocus()
	local hasText = #edit._text > 0
	local field = edit._inputField
	local fieldX, fieldY =
		x + edit._fieldPosition.x,
		y + edit._fieldPosition.y

	-- Draw the selections
	if focused then
		love.graphics.setColor(0.4, 0.4, 0.9, 0.8)
		for _, x, y, w, h in field:eachSelection() do
			love.graphics.rectangle("fill", fieldX+x, fieldY+y, w, h)
		end
	end

	if hasText then
		-- Draw the text contents
		love.graphics.setColor(mixRGBA(r, g, b, a, unpack(self.textColor, 1, 4)))
		love.graphics.draw(edit._textBatch, fieldX - field:getScrollX(), fieldY)
	else
		-- No text content, draw the placeholder
		love.graphics.setColor(mixRGBA(r, g, b, a, unpack(self.placeholderColor, 1, 4)))
		love.graphics.draw(edit._placeholderTextBatch, fieldX, fieldY)
	end

	if focused then
		love.graphics.setColor(r, g, b, a)
		local x, y, h = field:getCursorLayout()
		love.graphics.rectangle("fill", fieldX+x, fieldY+y, 1, h)
	end
end

return DrawLineEdit
