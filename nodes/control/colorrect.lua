---@type AdoreInit
local Adore = require ""
local Control = Adore.Nodes("Control")

---Basic white Control, whose color can be changed via albedo.
---@class ColorRect: Control
---@field super Control
---@overload fun(): ColorRect
local ColorRect = Control:extend()
ColorRect.CLASS_NAME = "ColorRect"

return ColorRect
