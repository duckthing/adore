---@class Tweener
---@field delay number?
local Tweener = {}

---@param t number
---@return number
function Tweener.ease(t) return t end
function Tweener:onEnter() end
function Tweener:onComplete() end
function Tweener:update(dt) end

return Tweener
