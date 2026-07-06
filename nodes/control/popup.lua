---@type AdoreInit
local Adore = require ""
local Control = Adore.Nodes("Control")

---@class Popup: Control
---@field super Control
---@overload fun(): Popup
local Popup = Control:extend()
Popup.CLASS_NAME = "Popup"
Popup._mouseMode = "sink"

---@type boolean # Should this be drawn on the root Viewport?
Popup._drawOnTop = true
---@type boolean # Can this Popup be closed through pressing the unfocus key? (default: `Esc`)
Popup._unfocusToClose = true

function Popup:new()
	Popup.super.new(self)
	self:addChild(Adore.Nodes("ColorRect")():setAnchors(0, 0, 1, 1))
	self:hide()
end

---Updates the dimensions of the Popup to be accurate
---@param self Popup
local function updateDimensions(self)
	local offsetX, offsetY = 0, 0
	local targetW, targetH = 0, 0
	if self._drawOnTop then
		-- Draw on the Root
		local viewport = self:getRoot():getViewport()
		assert(viewport, "Cannot popup outside of the tree")
		targetW, targetH = viewport:getDimensions()
	else
		if self._topLevelNode == self then
			-- Top-level node, resize according to the Viewport this Popup belongs to
			local viewport = self:getViewport()
			assert(viewport, "Cannot popup outside of the tree")
			targetW, targetH = viewport:getDimensions()
		else
			-- Not top-level, resize according to the parent Control
			---@type Control
			local parent = self.parent
			assert(parent, "Cannot popup outside of the tree")
			offsetX, offsetY, targetW, targetH = parent._localContentRect:unpack()
		end
	end

	local x, y, w, h = self:_getRectFromParentSize(targetW, targetH)
	self:_setModalRect(x + offsetX, y + offsetY, w, h)
end

function Popup:popup()
	updateDimensions(self)
	self:pushModal()
	self:show()
end

function Popup:close()
	self:popModal()
	self:hide()
end

function Popup:onRefreshed()
	Popup.super.onRefreshed(self)
end

---Disabled for Popup
function Popup:_setCanonRect() end

Popup._setModalRect = Popup.super._setCanonRect

function Popup:_intDraw()
	if not self._drawOnTop and self:isModal() then
		-- Only draws on the current Viewport
		Popup.super._intDraw(self)
	end
end

function Popup:mousepressed(mx, my, button, isTouch, pressCount)
	if button == 1 and not self:doesPointOverlap(mx, my) then
		-- Clicked out of bounds; close the popup
		self:close()
	end
	return true
end

function Popup:mousemoved(mx, my) return true end

---Draws the modal like normal; you should override :draw like normal
Popup._intModalDraw = Popup.super._intDraw

function Popup:draw()
end

function Popup._addDefinition(entry)
	entry:newBoolean("_drawOnTop", true)
	entry:newBoolean("_unfocusToClose", true)
end

return Popup
