---@type AdoreInit
local Adore = require ""
local DrawRequest = Adore.Resources("DrawRequest")

---@class DrawRequest.TabContainer: DrawRequest
---@overload fun(): DrawRequest.TabContainer
local DrawTabContainer = DrawRequest:extend()
DrawTabContainer.CLASS_NAME = "DrawTabContainer"

function DrawTabContainer:new()
end

---@param tabContainer TabContainer
function DrawTabContainer:themeUpdate(tabContainer)
	DrawTabContainer.super.themeUpdate(self, tabContainer)
end

---@param tabContainer TabContainer
function DrawTabContainer:draw(tabContainer)
end

return DrawTabContainer
