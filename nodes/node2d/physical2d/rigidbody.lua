---@type AdoreInit
local Adore = require ""
local Physical2d = Adore.Nodes("Physical2d")

---@class RigidBody: Physical2d
---@field super Physical2d
---@overload fun(x: number?, y: number?): RigidBody
local RigidBody = Physical2d:extend()
RigidBody.CLASS_NAME = "RigidBody"
RigidBody.defaultBodyType = "dynamic"

---@param x number?
---@param y number?
function RigidBody:new(x, y)
	RigidBody.super.new(self, x, y)
	self._transformRelativeToParent = false
end

return RigidBody
