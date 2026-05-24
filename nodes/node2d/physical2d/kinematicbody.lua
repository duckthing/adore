---@type AdoreInit
local Adore = require ""
local Physical2d = Adore.Nodes("Physical2d")

-- Before using a KinematicBody, check the Box2d documentation. It's not used in the way you think:
-- + DON'T USE IT FOR CHARACTERS!
-- + It's like a movable StaticBody
-- + Good for moving platforms
-- + Only moves according to its velocity

---@class KinematicBody: Physical2d
---@field super Physical2d
---@overload fun(x: number?, y: number?): KinematicBody
local KinematicBody = Physical2d:extend()
KinematicBody.CLASS_NAME = "KinematicBody"
KinematicBody.defaultBodyType = "kinematic"

---@param x number?
---@param y number?
function KinematicBody:new(x, y)
	KinematicBody.super.new(self, x, y)
	self._transformRelativeToParent = false
end

return KinematicBody
