---@type AdoreInit
local Adore = require ""
local Control = Adore.Nodes("Control")

---@type Adore.Loader
local Loader = require "loader"
local fontCollection = Loader.getCollection("FontLoader")
---@type love.Font[]
local fontAssets = fontCollection.assets
local max = math.max

---@alias Label.JustifyMode
---| "top"
---| "center"
---| "bottom"

---@class Label: Control
---@field super Control
---@overload fun(text: string?): Label
local Label = Control:extend()
Label.CLASS_NAME = "Label"
local defaultFont, defaultFontId = fontCollection:get("")
---@type FontSource? # The overridden font
Label._font = defaultFont
---@type integer?
Label._fontSize = 0
---@type love.AlignMode # The horizontal placement of the text
Label._align = "left"
---@type Label.JustifyMode # The vertical placement of the text
Label._justify = "top"

function Label:new(text)
	Label.super.new(self)

	self.albedo = {1, 1, 1, 1}
	---@type string # The contents of the Label
	self._text = text or ""
	---@type love.Text # The drawn part
	self._textBatch = love.graphics.newText(self._font[self._fontSize], self._text)

	---@type number # Y offset where the text batch is drawn
	self._textBatchY = 0
end

function Label:getMinimumSize()
	local minW, minH = Label.super.getMinimumSize(self)
	return minW, max(minH, self._textBatch:getHeight())
end

---Sets the text inside the Label
---@param text string?
---@return self
function Label:setText(text)
	text = text or ""
	if self._text ~= text then
		self._text = text
		self:deferRefreshSelf()
	end
	return self
end

---Sets the FontSource of this Label. Set to `nil` to use the Theme's font.
---@param font FontSource
---@return self
function Label:setFont(font)
	if self._font ~= font then
		self._font = font
		self:deferRefreshSelf()
	end
	return self
end

---Sets the font size of this Label. Set to `nil` or `0` to use the default.
---@param size number
---@return self
function Label:setFontSize(size)
	if self._fontSize ~= size then
		self._fontSize = size
		self:deferRefreshSelf()
	end
	return self
end

---Sets how the text aligns horizontally
---@param align love.AlignMode
---@return self
function Label:setAlign(align)
	if self._align ~= align then
		self._align = align
		self:deferRefreshSelf()
	end
	return self
end

---Sets how the text aligns vertically
---@param justify Label.JustifyMode
---@return self
function Label:setJustify(justify)
	if self._justify ~= justify then
		self._justify = justify
		self:deferRefreshSelf()
	end
	return self
end

function Label:forceDestroy(recursive)
	Label.super.forceDestroy(self, recursive)
	self._textBatch:release()
end

function Label._addDefinition(entry)
	entry:newString("_text", "", nil, nil, "setText")
	entry:newInteger("_fontSize", 0, nil, nil, nil, "setFontSize")
end

return Label
