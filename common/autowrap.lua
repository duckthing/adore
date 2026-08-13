local max = math.max

---@alias AutoWrap.Mode
---| "none" # Does no wrapping
---| "basic" # Wraps with Love2D's formatting

---@class AutoWrap
local AutoWrap = {
	---@param textBatch love.Text
	---@param desiredText string
	---@param width integer
	---@param align love.AlignMode
	none = function(textBatch, desiredText, width, align)
		local font = textBatch:getFont()
		width = max(width, font:getWidth(desiredText))
		textBatch:setf(desiredText, width, align)
	end,
	---@param textBatch love.Text
	---@param desiredText string
	---@param width integer
	---@param align love.AlignMode
	basic = function(textBatch, desiredText, width, align)
		textBatch:setf(desiredText, width, align)
	end,
}

return AutoWrap
