---@type AdoreInit
local Adore = require ""
local Physical2d = Adore.Nodes("Physical2d")

---@class StaticBody: Physical2d
---@field super Physical2d
---@overload fun(x: number?, y: number?): StaticBody
local StaticBody = Physical2d:extend()
StaticBody.CLASS_NAME = "StaticBody"
StaticBody.defaultBodyType = "static"

return StaticBody
