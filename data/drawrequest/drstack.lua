---@type AdoreInit
local Adore = require ""
local DrawRequest = Adore.Nodes("DrawRequest")

---@class DrawRequest.DRStack: DrawRequest
---@overload fun(arr: DrawRequest[]): DrawRequest.DRStack
local DRStack = DrawRequest:extend()
DRStack.CLASS_NAME = "DrawRequestStack"

---@param arr DrawRequest[]?
function DRStack:new(arr)
	DRStack.super.new(self)

	self.stack = arr or {}
end

function DRStack:themeUpdate(control)
	local arr = self.stack
	for i = 1, #arr do
		arr[i]:themeUpdate(control)
	end
end

function DRStack:draw(control)
	local arr = self.stack
	for i = 1, #arr do
		arr[i]:draw(control)
	end
end

return DRStack
