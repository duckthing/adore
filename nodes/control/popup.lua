---@type AdoreInit
local Adore = require ""
local Control = Adore.Nodes("Control")
local bit = Adore.Common("bitlib")
local min, max = math.min, math.max

---@class Popup: Control
---@field super Control
---@overload fun(): Popup
local Popup = Control:extend()
Popup.CLASS_NAME = "Popup"
Popup._modalDrawOnTop = true
Popup._modalDrawPreviousModals = false

---@type boolean # Should this Popup be resized according to a parent Control (if below one)?
Popup._resizeWithParent = true
---@type boolean # Can this Popup be closed through pressing the unfocus key? (default: `Esc`)
Popup._unfocusToClose = true
---@type boolean # Should this Popup get destroyed when closed?
Popup._destroyOnClose = false
---@type boolean # Keeps this Popup within the safe area of the Viewport
Popup._clampToSafeArea = true
---@type integer # Allows closing the Popup when the button index matches bitwise.
---The default is `3`, which means left clicks (`1`) and right clicks (`2`) that are outside
---of the Popup will close it. `1 + 2 + 4` will close on middle-click as well.
---See `BaseButton.buttonFilter`.
Popup._offClickToClose = 3

function Popup:new()
	Popup.super.new(self)
	self:hide()
end

---Gets the target Viewport according to the set properties
---@param self Popup
---@return Viewport
local function getTargetViewport(self)
	local viewport
	if self._modalDrawOnTop then
		viewport = self:getRoot():getViewport()
	else
		viewport = self:getViewport()
	end
	return assert(viewport, "Cannot popup outside of the tree")
end

---Updates the dimensions of the Popup to be accurate
---@param self Popup
local function updateDimensions(self)
	-- Get the safe area where this Popup can exist in
	local offsetX, offsetY = 0, 0
	local targetW, targetH = 0, 0
	if self._resizeWithParent and self._topLevelNode ~= self then
		-- Resize according to the parent
		---@type Control
		local parent = assert(self.parent, "Cannot popup outside of the tree")
		offsetX, offsetY, targetW, targetH = parent._localContentRect:unpack()
	else
		-- Resize according to the Viewport safe area
		local viewport = getTargetViewport(self)
		offsetX, offsetY, targetW, targetH = viewport:getSafeArea()
	end

	-- Clamping happens in :onRefreshed
	local x, y, w, h = self:_getRectFromParentSize(targetW, targetH)

	self:_setModalRect(x + offsetX, y + offsetY, w, h)
end

---Calculates the position and size of the Popup, and shows it
function Popup:popup()
	updateDimensions(self)
	self:pushModal()
	self:show()
end

---Closes the Popup
function Popup:close()
	if self:canClose() then
		self:popModal()
		self:hide()
		if self._destroyOnClose then
			self:queueDestroy(true)
		end
	end
end

---Returns `true` if this Popup can be closed right now
---@return boolean canClose
function Popup:canClose()
	return true
end

function Popup:onRefreshed()
	Popup.super.onRefreshed(self)
	if self._clampToSafeArea then
		-- Clamp to the safe area
		local viewport = getTargetViewport(self)
		local safeX, safeY, safeW, safeH = viewport:getSafeArea()
		local x, y, w, h = self._localContentRect:unpack()
		x, y =
			max(safeX, min(x, safeW - w)),
			max(safeY, min(y, safeH - h))
		self:_setModalRect(x, y, w, h)
	end
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
	if not self._modalDrawOnTop and self:isModal() then
		-- Only draws on the current Viewport
		Popup.super._intDraw(self)
	end
end

---Draws the modal like normal; you should override :draw like normal
Popup._intModalDraw = Popup.super._intDraw

function Popup._addDefinition(entry)
	entry:newBoolean("_resizeWithParent", true)
	entry:newBoolean("_unfocusToClose", true)
	entry:newBoolean("_destroyOnClose", false)
	entry:newBoolean("_clampToSafeArea", true)
	entry:newInteger("_offClickToClose", 3, 0)
end

return Popup
