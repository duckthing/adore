---@class Color
local Color = {}

---Mixes two RGB colors
---@param ar integer
---@param ag integer
---@param ab integer
---@param br integer
---@param bg integer
---@param bb integer
---@return integer r
---@return integer g
---@return integer b
function Color.mixRGB(ar, ag, ab, br, bg, bb)
	return
		ar * br,
		ag * bg,
		ab * bb
end

---Mixes two RGBA colors
---@param ar integer
---@param ag integer
---@param ab integer
---@param aa integer
---@param br integer
---@param bg integer
---@param bb integer
---@param ba integer
---@return integer r
---@return integer g
---@return integer b
---@return integer a
function Color.mixRGBA(ar, ag, ab, aa, br, bg, bb, ba)
	return
		ar * br,
		ag * bg,
		ab * bb,
		aa * (ba or 1)
end

return Color
