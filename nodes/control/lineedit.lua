---@type AdoreInit
local Adore = require ""
local Control = Adore.Nodes("Control")
local InputField = Adore.Libraries("InputField")
local Vec2 = Adore.Common("Vec2")
local max = math.max

local Loader = Adore.Loader
local fontCollection = Loader.getCollection("love.Font")
---@type love.Font[]
local fontAssets = fontCollection.assets

---@class LineEdit: Control
---@field super Control
---@overload fun(text: string?): LineEdit
local LineEdit = Control:extend()
LineEdit.CLASS_NAME = "LineEdit"
LineEdit._mouseMode = "sink"
LineEdit.inputMode = "sink"
LineEdit.focusMode = "all"
local defaultFont, _ = fontCollection:get("")
---@type FontSource? # The overridden font
LineEdit._font = defaultFont
---@type integer?
LineEdit._fontSize = 0

function LineEdit:new(text)
	LineEdit.super.new(self)
	text = text or ""

	---@type InputField # The internal InputField
	self._inputField = InputField(text)
	---@type Vec2 # The offset of the InputField
	self._lineOffset = Vec2(4, 0)
	---@type Vec2 # The local position of the InputField inside of the LineEdit
	self._fieldPosition = Vec2(0, 0)
	---@type Vec2 # The margin around the field. A larger X margin will show more letters around the caret.
	self._fieldMargin = Vec2(10, 4)

	---@type string # The contents of the LineEdit currently
	self._text = self._inputField:getText()
	---@type string # The contents of the LineEdit that was not cancelled; if actively typing, press Escape to return to this
	self._submittedText = self._text
	---@type string # What will be displayed when the LineEdit is empty
	self._placeholderText = "Type here..."

	---@type love.AlignMode # The horizontal placement of the field
	self._align = "left"
	---@type Label.JustifyMode # The vertical placement of the field
	self._justify = "center"

	---@type boolean # When submitting an empty field, should we use the placeholder value?
	self._usePlaceholderOnEmptySubmit = false
	---@type "default" | "left" | "right" # Where the cursor is placed when the LineEdit is focused
	self._moveWhenFocused = "default"
	---@type boolean # When focusing via keyboard, should we select all the text?
	self._selectAllOnKeyboardFocus = true
	---@type boolean # When focusing via mouse, should we select all the text?
	self._selectAllOnMouseFocus = false
	---@type boolean # Should we unfocus when submitting/cancelling text input?
	self._unfocusOnCompletion = false

	---@type FontSource? # The overridden font
	self._font = nil
	---@type love.Text # The drawn text batch
	self._textBatch = love.graphics.newText(self._font[self._fontSize], self._text)
	---@type love.Text # The drawn placeholder text batch
	self._placeholderTextBatch = love.graphics.newText(self._font[self._fontSize], self._placeholderText)

	self.textSubmitted = self:newSignal()
	self.textChanged = self:newSignal()
	self.textCancelled = self:newSignal()
end

function LineEdit:getMinimumSize()
	local minW, minH = LineEdit.super.getMinimumSize(self)
	return minW, max(minH, self._textBatch:getFont():getHeight())
end

function LineEdit:submit()
	local usedText = self._text
	if #usedText == 0 and self._usePlaceholderOnEmptySubmit then
		-- If the entered text is empty, and we want to use to placeholder, swap it.
		usedText = self._placeholderText
	end
	self._submittedText = usedText
	self._inputField:releaseMouse()
	self.textSubmitted:fire(usedText)
	self:deferRefreshSelf()
end

function LineEdit:cancel()
	local oldText = self._submittedText
	self._text = oldText
	self._inputField:setText(oldText)
	self.textCancelled:fire(oldText)
	self.textChanged:fire(oldText)
	self:deferRefreshSelf()
end

---Returns `true` if the current text input is different from the former text input
function LineEdit:isTextDifferent()
	return self._submittedText ~= self._text
end

---Sets the text of the LineEdit. Will also clear the history of the text.
---@param text string?
---@return self
function LineEdit:setText(text)
	text = text or ""
	if self._text ~= text then
		self._text = text
		self._submittedText = text
		self._inputField:setText(text)
		self._inputField:clearHistory()
		self.textChanged:fire(text)
		self._textBatch:set(text)
		self:deferRefreshSelf()
	end

	return self
end

---Sets the FontSource of this LineEdit
---@param font FontSource?
---@return LineEdit
function LineEdit:setFont(font)
	if self._font ~= font then
		self._font = font
		self:deferRefreshSelf()
	end
	return self
end

---Sets the placeholder text of the LineEdit. This appears when there is no text entered.
---@param text string
---@return self
function LineEdit:setPlaceholderText(text)
	if self._placeholderText ~= text then
		self._placeholderText = text
		self._placeholderTextBatch:setf(text, self._localContentRect.w, self._align)
		self:deferRefreshSelf()
	end

	return self
end

---Sets the vertical placement of the field
---@param justify Label.JustifyMode
function LineEdit:setJustify(justify)
	if self._justify ~= justify then
		self._justify = justify
		self:deferRefreshSelf()
	end
	return self
end

---Sets the horizontal placement of the field
---@param align love.AlignMode
function LineEdit:setAlign(align)
	if self._align ~= align then
		self._align= align
		self._inputField:setAlignment(align)
		self:deferRefreshSelf()
	end
	return self
end

function LineEdit:mousepressed(mx, my, button, pressCount)
	-- Currently focused
	local pos = self._fieldPosition
	local lcr = self._localContentRect
	self._inputField:mousepressed(mx - lcr.x - pos.x, my - lcr.y - pos.y, button, pressCount)

	if not self:hasFocus() then
		if button == 1 then
			self:grabFocus(true)
		end
	end
	return true
end

function LineEdit:mousemoved(mx, my)
	if self:hasFocus() then
		local pos = self._fieldPosition
		local lcr = self._localContentRect
		self._inputField:mousemoved(mx - lcr.x - pos.x, my - lcr.y - pos.y)
		return self._inputField:isBusy()
	end
end

function LineEdit:mousereleased(mx, my, button)
	local pos = self._fieldPosition
	local lcr = self._localContentRect
	self._inputField:mousereleased(mx - lcr.x - pos.x, my - lcr.y - pos.y, button)
end

function LineEdit:keypressed(key, scancode, isRepeat)
	if key == "escape" then
		if self:isTextDifferent() then
			-- Text is different; undo input and select it
			self:cancel()
			self._inputField:selectAll()
			if self._unfocusOnCompletion then self:releaseFocus() end
			return true
		else
			-- Text is the same; unfocus if the root allows it
			if self:getRoot().allowUnfocus then
				self:releaseFocus()
			end
			return false
		end
	elseif key == "return" then
		self:submit()
		self._inputField:selectAll()
		if self._unfocusOnCompletion then self:releaseFocus() end
		return true
	elseif key ~= "tab" then
		-- Everything else, other than "tab"
		local handled, wasEdited = self._inputField:keypressed(key, isRepeat)
		if wasEdited then
			-- Only special keys and keybinds (like backspace) cause edits
			-- The rest are in :textinput
			local newText = self._inputField:getText()
			self._text = newText
			self:deferRefreshSelf()
		end
		return handled
	end
	return false
end

function LineEdit:textinput(text)
	local handled, wasEdited = self._inputField:textinput(text)
	if wasEdited then
		local newText = self._inputField:getText()
		self._text = newText
		self:deferRefreshSelf()
		self.textChanged:fire(newText)
	end
	return handled
end

function LineEdit:uiFocused(isMouse)
	LineEdit.super.uiFocused(self, isMouse)
	local placement = self._moveWhenFocused
	local inputField = self._inputField

	if (not isMouse and self._selectAllOnKeyboardFocus) or (isMouse and self._selectAllOnMouseFocus) then
		-- Selecting all of the text
		if placement == "left" then
			inputField:setSelection(0, #inputField:getText(), "left")
		else
			inputField:selectAll()
		end
		if isMouse then inputField:releaseMouse() end
	else
		-- Not selecting all of the text
		if placement == "left" then
			inputField:setCursor(0)
		elseif placement == "right" then
			inputField:setCursor(#inputField:getText())
		end
	end
end

function LineEdit:uiFocusLost()
	LineEdit.super.uiFocusLost(self)
	self._inputField:setCursor(0)
	self._inputField:releaseMouse()
	self:submit()
end

-- Only update the cursor if we're on a computer
if love.mouse.isCursorSupported() then
	local ibeamCursor = love.mouse.getSystemCursor("ibeam")

	function LineEdit:uiEntered(x, y)
		love.mouse.setCursor(ibeamCursor)
	end

	function LineEdit:uiExited()
		love.mouse.setCursor()
	end
end

function LineEdit._addDefinition(entry)
	entry:newString("_text", "", nil, nil, "setText")
	entry:newString("_placeholderText", "", nil, nil, "setPlaceholderText")
end

return LineEdit
