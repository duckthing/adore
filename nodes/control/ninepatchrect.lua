---@type AdoreInit
local Adore = require ""
local Control = Adore.Nodes("Control")
local NinePatch = Adore.Resources("NinePatch")

---@class NinePatchRect: Control
---@field super Control
---@overload fun(np: NinePatch?, scale: number?): NinePatchRect
local NinePatchRect = Control:extend()
NinePatchRect.CLASS_NAME = "NinePatchRect"

function NinePatchRect:new(np, scale)
	NinePatchRect.super.new(self)

	---@type NinePatch
	self.ninepatch = np
	---@type number?
	self.ninepatchScale = scale
end

---Creates a new NinePatch and returns self
---@param tSource TextureSource
---@param leftSize integer # The size of the left split
---@param rightSize integer # The size of the right split
---@param topSize integer # The size of the top split
---@param bottomSize integer # The size of the bottom split
---@return self
function NinePatchRect:newNinePatch(tSource, leftSize, rightSize, topSize, bottomSize)
	self.ninepatch = NinePatch.new(tSource, leftSize, rightSize, topSize, bottomSize)
	return self
end

return NinePatchRect
