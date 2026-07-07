---@type AdoreInit
local Adore = require ""
local Control = Adore.Nodes("Control")
local bit = Adore.Common("bitlib")

---@class Popup: Control
---@field super Control
---@overload fun(): Popup
local Popup = Control:extend()
Popup.CLASS_NAME = "Popup"
Popup._mouseMode = "sink"

---@type boolean # Should this be drawn on the root Viewport?
Popup._drawOnTop = true
---@type boolean # Should former modals be drawn as well, in the event multiple are pushed?
Popup._drawPreviousModals = false
---@type boolean # Can this Popup be closed through pressing the unfocus key? (default: `Esc`)
Popup._unfocusToClose = true
---@type integer # Allows closing the Popup when the button index matches bitwise.
---The default is `3`, which means left clicks (`1`) and right clicks (`2`) that are outside
---of the Popup will close it. `1 + 2 + 4` will close on middle-click as well.
---See `BaseButton.buttonFilter`.
Popup._offClickToClose = 3

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
		offsetX, offsetY, targetW, targetH = viewport:getSafeArea()
	else
		if self._topLevelNode == self then
			-- Top-level node, resize according to the Viewport this Popup belongs to
			local viewport = self:getViewport()
			assert(viewport, "Cannot popup outside of the tree")
			offsetX, offsetY, targetW, targetH = viewport:getSafeArea()
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

function Popup:mousepressed(mx, my, button, isTouch, pressCount)
	if bit.band(self._offClickToClose, bit.lshift(1, button - 1)) > 0 and not self:doesPointOverlap(mx, my) then
		-- Clicked out of bounds; close the popup
		self:close()
	end
	return true
end

function Popup:mousemoved(mx, my) return true end

---Disabled for Popup
function Popup:_setCanonRect() end

Popup._setModalRect = Popup.super._setCanonRect

function Popup:_intDraw()
	if not self._drawOnTop and self:isModal() then
		-- Only draws on the current Viewport
		Popup.super._intDraw(self)
	end
end

---Draws the modal like normal; you should override :draw like normal
Popup._intModalDraw = Popup.super._intDraw

function Popup:draw() end

function Popup._addDefinition(entry)
	entry:newBoolean("_drawOnTop", true)
	entry:newBoolean("_drawFormerModals", false)
	entry:newBoolean("_unfocusToClose", true)
	entry:newInteger("_offClickToClose", 3, 0)
end

return Popup
