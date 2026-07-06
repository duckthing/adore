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
end

function Popup:popup(x, y, w, h)
	self:_setModalRect(x, y, w, h)
	self:pushModal()
end

function Popup:popupCentered(w, h)
	w, h = w or 160, h or 120
	local viewport = self:getViewport()
	assert(viewport, "Cannot popup centered outside of a tree")
	local vw, vh = viewport:getDimensions()
	self:popup((vw - w) * 0.5, (vh - h) * 0.5, w, h)
end

function Popup:close()
	self:popModal()
end

---Disabled for Popup
function Popup:_setCanonRect() end

Popup._setModalRect = Popup.super._setCanonRect

function Popup:_intDraw()
	if not self._drawOnTop then
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

return Popup
