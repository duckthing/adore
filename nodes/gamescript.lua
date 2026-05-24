---@type AdoreInit
local Adore = require ""

---A `GameScript` is a simple node that can have its `:update` and `:draw` methods overridden in a Lua scene.
---Good for temporary code and prototypes.
---@class GameScript: Node
---@overload fun(update: (fun(self: GameScript): nil)?, draw: (fun(self: GameScript): nil)?): GameScript
local GameScript = Adore.Nodes("Node"):extend()

---@param update function?
---@param draw function?
function GameScript:new(update, draw)
	GameScript.super.new(self)
	self.update, self.draw = update, draw
end

return GameScript
