---@type AdoreInit
local Adore = require ""
local Node2d = Adore.Nodes("Node2d")

---@class YSort: Node2d
---@overload fun(): YSort
local YSort = Node2d:extend()
YSort.CLASS_NAME = "YSort"

function YSort:new()
	YSort.super.new(self)
end

---@param a Node2d
---@param b Node2d
function YSort.sortCondition(a, b)
	if not (a:is(Node2d) and b:is(Node2d)) then
		-- Invalid comparison, accept current position
		return true
	end

	local _, ay = a:getPosition(true)
	local _, by = b:getPosition(true)
	return ay < by
end


function YSort:_beforeDraw()
	YSort.super._beforeDraw(self)
	table.sort(self.children, self.sortCondition)
end

return YSort
