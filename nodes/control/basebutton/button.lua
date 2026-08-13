---@type AdoreInit
local Adore = require ""
local BaseButton = Adore.Nodes("BaseButton")
local max = math.max

local FontLoader = Adore.Loader.getCollection("FontLoader")

---@class Button: BaseButton
---@field super BaseButton
---@overload fun(text: string?, icon: TextureSource?): Button
local Button = BaseButton:extend()
Button.CLASS_NAME = "Button"
---@type love.AlignMode # Where the text lies horizontally
Button._textAlign = "center"
---@type AutoWrap.Mode # The autowrap mode of the text
Button._autowrap = "none"
---@type love.AlignMode # Where the icon lies horizontally. If centered, the text will draw on top of the icon.
Button._iconAlign = "left"
---@type Label.JustifyMode # Where the icon lies vertically
Button._iconJustify = "center"
---@type boolean # Resizes the icon while keeping the aspect ratio
Button._iconExpand = false
---@type string # What is in the Button. Use :setText() instead of setting this.
Button._text = "Button"

local DEFAULT_FONT = FontLoader:get("")

---@type FontSource? # The overridden font
Button._font = DEFAULT_FONT
---@type integer?
Button._fontSize = 0

local created = 1
---@param text string?
---@param icon TextureSource?
function Button:new(text, icon)
	Button.super.new(self)
	text = text or tostring(created)

	---@type string # The text part of the Button
	self._text = text
	---@type love.Text # The drawn part
	self._textBatch = love.graphics.newText((self._font or DEFAULT_FONT)[self._fontSize], self._text)
	---@type TextureSource? # The icon that shows up next to the button
	self._icon = nil

	---@type number # The text offset
	self._textBatchX, self._textBatchY = 0, 0
	---@type integer, integer # [Internal] The texture offset
	self._iconX, self._iconY = 0, 0
	---@type integer, integer # [Internal] The texture scale
	self._iconScale = 1

	created = created + 1

	if icon then
		self:setIcon(icon)
	end
end

function Button:getMinimumSize()
	local minW, minH = Button.super.getMinimumSize(self)
	local textBatch = self._textBatch
	if self._autowrap == "none" then
		-- Minimum width with no wrapping is always the width of the text
		minW = max(minW, textBatch:getWidth())
	end
	local icon = self._icon
	if icon and self._iconExpand then
		local _, _, iconW, iconH = icon.quad:getViewport()
		return max(minW, iconW), max(minH, textBatch:getHeight(), iconH)
	else
		return minW, max(minH, textBatch:getHeight())
	end
end

---Sets the text inside the Label
---@param text string?
---@return self
function Button:setText(text)
	text = text or ""
	if self._text ~= text then
		self._text = text
		self:deferRefreshSelf()
	end
	return self
end

---Sets the FontSource of this Button. Set to `nil` to use the Theme's font.
---@param font FontSource?
---@return self
function Button:setFont(font)
	if self._font ~= font then
		self._font = font
		self:deferRefreshSelf()
	end
	return self
end

---Sets the font size of this Button. Set to `nil` or `0` to use the default.
---@param size number
---@return self
function Button:setFontSize(size)
	if self._fontSize ~= size then
		self._fontSize = size
		self:deferRefreshSelf()
	end
	return self
end

---Sets the icon used inside the Button
---@param icon TextureSource?
---@return self
function Button:setIcon(icon)
	if self._icon ~= icon then
		self._icon = icon
		self:deferRefreshSelf()
	end
	return self
end

---Sets the text alignment, which changes where the text is horizontally
---@param align love.AlignMode
---@return self
function Button:setTextAlign(align)
	if self._textAlign ~= align then
		self._textAlign = align
		self:deferRefreshSelf()
	end
	return self
end

---Sets how the text wraps
---@param autowrap AutoWrap.Mode
---@return self
function Button:setTextAutoWrap(autowrap)
	if self._autowrap ~= autowrap then
		self._autowrap = autowrap
		self:deferRefreshSelf()
	end
	return self
end

---Sets the icon alignment, which changes where the icon is horizontally
---@param align love.AlignMode
---@return self
function Button:setIconAlign(align)
	if self._iconAlign ~= align then
		self._iconAlign = align
		self:deferRefreshSelf()
	end
	return self
end

---Sets the icon justify mode, which changes where the icon is vertically
---@param justify Label.JustifyMode
---@return self
function Button:setIconJustify(justify)
	if self._iconJustify ~= justify then
		self._iconJustify = justify
		self:deferRefreshSelf()
	end
	return self
end

---Sets whether the icon expands to fill the Button
---@param expand boolean
---@return Button
function Button:setIconExpand(expand)
	if self._iconExpand ~= expand then
		self._iconExpand = expand
		self:deferRefreshSelf()
	end
	return self
end

function Button:forceDestroy(recursive)
	Button.super.forceDestroy(self, recursive)
	self._textBatch:release()
end

function Button._addDefinition(entry)
	entry:newString("_text", "", nil, nil, "setText")
	local alignModes = {
		left = true,
		center = true,
		right = true,
	}
	local justifyModes = {
		top = true,
		center = true,
		bottom = true,
	}
	local wrapMap = {
		none = true,
		basic = true,
	}
	entry:newEnum("_textAlign", alignModes, "center", "setTextAlign")
	entry:newEnum("_autowrap", wrapMap, "none", "setTextAutoWrap")
	entry:newAssetPath("_icon", "TextureLoader", nil, "setIcon")
	entry:newEnum("_iconAlign", alignModes, "center", "setIconAlign")
	entry:newEnum("_iconJustify", justifyModes, "center", "setIconJustify")
	entry:newBoolean("_iconExpand", false, "setIconExpand")
	entry:newAssetPath("_font", "FontLoader", "", "setFont")
	entry:newInteger("_fontSize", 0, 0, nil, nil, "setFontSize")
end

return Button
