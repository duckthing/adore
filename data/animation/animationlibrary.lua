---@type AdoreInit
local Adore = require ""
local Object = Adore.Resources("Object")

---@class Animation.Library: Object
---@field name string
---@field animations {[string]: Animation}
local AnimLibrary = Object:extend()
AnimLibrary.CLASS_NAME = "Animation.Library"

---@param name string?
---@param animations {[string]: Animation}?
function AnimLibrary:new(name, animations)
	AnimLibrary.super.new(self)

	self.name = name or "AnimationLibrary"
	self.animations = animations or {}
end

function AnimLibrary._addDefinition(entry)
	entry:newString("name", "AnimationLibrary")
	-- TODO: Make a 'map' property for animations
end

return AnimLibrary
