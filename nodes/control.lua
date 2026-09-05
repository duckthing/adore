---@type AdoreInit
local Adore = require ""
local Nodes = Adore.Nodes
local Common = Adore.Common
local Node = Nodes("Node")
local CanvasLayer = Nodes("CanvasLayer")
local Rect2 = Common("Rect2")
local Vec2 = Common("Vec2")

local min, max, huge = math.min, math.max, math.huge

local PI2 = math.pi * 2
local BLANK_TRANSFORM = love.math.newTransform()
local TEMP_TRANSFORM = love.math.newTransform()

---@alias Control.InputFilter
---| "pass" # [Default] We can receive input, but children take priority
---| "sink" # Receive it, and don't give it to any children
---| "ignore" # We don't do anything to this input

---@alias Control.FocusMode
---| "all" # Keyboard and mouse inputs can focus this Control
---| "click" # Only mouse inputs can focus this Control
---| "none" # This Control can't be focused with user input

---@class Control: Node
---@field super Control
---@field mousemoved fun(self, mx: integer, my: integer, globalDx: integer, globalDy: integer, isTouch: boolean): boolean? handled
---@field mousepressed fun(self, mx: integer, my: integer, button: integer, isTouch: boolean, pressCount: integer): boolean? handled
---@field mousereleased fun(self, mx: integer, my: integer, button: integer): boolean? handled
---@field wheelmoved fun(self, wx: integer, wy: integer): boolean? handled
---@field keypressed fun(self, key: love.KeyConstant, scancode: love.Scancode, isRepeat: boolean): boolean? handled
---@field keyreleased fun(self, key: love.KeyConstant, scancode: love.Scancode): boolean? handled
---@field textinput fun(self, text: string): boolean? handled
---@overload fun(): Control
local Control = Node:extend()
Control.CLASS_NAME = "Control"

---@type integer[] # The color this Control should be. DrawRequests may mix with this.
Control.albedo = {1, 1, 1, 1}
---@type boolean # Whether this Control should prevent children from being drawn out of bounds
Control.clipChildren = false
---In a range of [0..1], where 0 is the left/top and 1 is the right/bottom, how should this Control grow?
---When below the minimum size and a grow factor of 0, the Control expands towards the right/bottom.
---@type number, number
Control._growHorizontal, Control._growVertical = 0, 0

-- The default variant can also be found underneath Theme[Control.CLASS_ID][""]
local DEFAULT_SUBCLASS_MAP = {
	normal = "",
}
---@type string # The subclass, as originally chosen by the Control's logic, set in :setSubclass()
Control._currentOriginalSubclass = "normal"
---@type string # The subclass, mapped from the original one in :setSubclass(), to a new one according to self.subclassMap
Control._currentSubclass = ""
---@type string # The name of this variant, which is where the subclass map came from. Set through :setVariant().
Control._variantName = ""
---@type {[string]: string} # When using :setSubclass(), this will map the original subclass into something else. Can be used for different styles with the same logic.
Control.subclassMap = DEFAULT_SUBCLASS_MAP

---@type Control.FocusMode # What input can focus on the Control?
Control.focusMode = "none"
---@type Control?, Control?, Control?, Control?, Control?, Control? # Used for navigation with keyboard/gamepad
Control.neighborLeft, Control.neighborTop, Control.neighborRight, Control.neighborBottom,
---@type Control, Control? # Used for navigation with keyboard/gamepad
Control.neighborNext, Control.neighborPrevious
	= nil, nil, nil, nil, nil, nil
---@type boolean # Is this Control focused right now?
Control._focused = false
---@type boolean # Is the mouse hovering over this Control?
Control._hovered = false

---@type Control[] # An array of every Control object; used for themes
Control.INHERITS_CONTROL = {Control}
---@type Control[] # An array of whatever's been inherited from the current class (not just Control)
Control.INHERITED_BY = {}
---@type Signal # Triggered whenever there's a new Control class created
Control.onNewControlInherited = Control:newSignal()

---@type Control.InputFilter # Can this Control and its children receive any input?
Control._inputMode = "pass"
---@type Control.InputFilter # Can this Control and its children receive mouse inputs? (If `inputMode` allows it, as well)
Control._mouseInputMode = "pass"
---@type boolean # Whether this Control is in the modal stack; use `:isModal()` instead
Control._pushedAsModal = false
---@type boolean # [As a modal] Should this be drawn on the root Viewport?
Control._modalDrawOnTop = false
---@type boolean # [As a modal] Should former modals be drawn as well, in the event multiple are pushed?
Control._modalDrawPreviousModals = true

function Control:new()
	Control.super.new(self)

	---@type number, number, number, number # The percentage of the parent's spacing this Control should take
	self._anchorLeft, self._anchorTop, self._anchorRight, self._anchorBottom
		= 0, 0, 0, 0
	---@type number, number, number, number # The percentage of the parent's spacing this Control should take
	self._offsetLeft, self._offsetTop, self._offsetRight, self._offsetBottom
		= 0, 0, 0, 0
	---@type Vec2 # Where the pivot is relatively located, in pixels
	self._pivot = Vec2(0, 0)
	---@type number # The rotation of this Control around the pivot
	self._rotation = 0
	---@type Vec2 # The scale of the Control around the pivot
	self._scale = Vec2(1, 1)
	---@type love.Transform # The `love.Transform` of this Control, which contains the resulting pivot+rotation results
	self._globalTransform = love.math.newTransform()

	---@type Vec2? # The minimum size of the Control; get more customization by overridding `:getMinimumSize()`
	self._minimumSize = nil
	---@type Vec2? # The maximum size of the Control; get more customization by overridding `:getMaximumSize()`
	self._maximumSize = nil

	---@type integer # How deep this Control is; 0 is outside the tree, 1 is the top-level, and greater is a child
	self._depth = 0
	---@type Control? # The top-level Control to this Control; used for determining the highest Control among layers
	self._topLevelNode = nil
	---@type boolean # Whether we're in the Shash
	self._inShash = false
	---@type Control? # The previously focused Control when this Control was pushed as a modal; will get reverted to this when popping this modal
	self._previousFocused = nil

	---@type Theme? # The Theme that will be used on this Control and any children.
	---This value can be `nil`; if you want to know what Theme will be applied right here, use `:getAppliedTheme()`.
	self._theme = nil
	---@type Theme # The applied Theme on this Control; in order of priority, it's `self._theme`, or `parent._inheritedTheme`, or `Root:getDefaultTheme()`
	self._inheritedTheme = self:getRoot():getDefaultTheme()
	---@type {[string]: DrawRequest} # The subclass name to DrawRequest map for **this class specifically**
	self._inheritedDRMap = nil
	---@type string # What subclass will be used (from the theme)
	self._currentSubclass = self.subclassMap.normal

	---@type Rect2 # The local Rect2 of this Control, which contains the untransformed Control in local space
	self._localContentRect = Rect2(0, 0, 0, 0)
	---@type Rect2 # The global Rect2 of this Control, which contains the transformed Control in global space
	self._globalContentRect = Rect2(0, 0, 0, 0)
end

---An override of :extend(), which registers this Control as an extension
function Control:extend()
	local template = Control.super.extend(self)
	Control.INHERITS_CONTROL[#Control.INHERITS_CONTROL+1] = template
	Control.onNewControlInherited:fire(template)
	return template
end

---Sets all the anchors in bulk
---@generic T: Control
---@param self T | Control
---@param left number
---@param top number
---@param right number
---@param bottom number
---@return T
function Control:setAnchors(left, top, right, bottom)
	self._anchorLeft, self._anchorTop, self._anchorRight, self._anchorBottom
		= left, top, right, bottom
	self:deferRefreshSelf()
	return self
end

---Sets all the offsets in bulk
---@generic T: Control
---@param self T | Control
---@param left number
---@param top number
---@param right number
---@param bottom number
---@return T
function Control:setOffsets(left, top, right, bottom)
	self._offsetLeft, self._offsetTop, self._offsetRight, self._offsetBottom
		= left, top, right, bottom
	self:deferRefreshSelf()
	return self
end

---Sets all the anchors and offsets in bulk
---@generic T: Control
---@param self T | Control
---@param aleft number
---@param atop number
---@param aright number
---@param abottom number
---@param oleft number
---@param otop number
---@param oright number
---@param obottom number
---@return T
function Control:setAnchorsAndOffsets(
	aleft, atop, aright, abottom,
	oleft, otop, oright, obottom
)
	self._anchorLeft, self._anchorTop, self._anchorRight, self._anchorBottom
		= aleft, atop, aright, abottom
	self._offsetLeft, self._offsetTop, self._offsetRight, self._offsetBottom
		= oleft, otop, oright, obottom
	self:deferRefreshSelf()
	return self
end

---@alias Control.RectSetter
---| fun(self, value: number): self

---@type Control.RectSetter
function Control:setAnchorLeft(value) self._anchorLeft = value; self:deferRefreshSelf(); return self end
---@type Control.RectSetter
function Control:setAnchorRight(value) self._anchorRight = value; self:deferRefreshSelf(); return self end
---@type Control.RectSetter
function Control:setAnchorTop(value) self._anchorTop = value; self:deferRefreshSelf(); return self end
---@type Control.RectSetter
function Control:setAnchorBottom(value) self._anchorBottom = value; self:deferRefreshSelf(); return self end
---@type Control.RectSetter
function Control:setOffsetLeft(value) self._offsetLeft = value; self:deferRefreshSelf(); return self end
---@type Control.RectSetter
function Control:setOffsetRight(value) self._offsetRight = value; self:deferRefreshSelf(); return self end
---@type Control.RectSetter
function Control:setOffsetTop(value) self._offsetTop = value; self:deferRefreshSelf(); return self end
---@type Control.RectSetter
function Control:setOffsetBottom(value) self._offsetBottom = value; self:deferRefreshSelf(); return self end

---Sets the pivot of this Control
---@param x number
---@param y number
---@return Control
function Control:setPivot(x, y)
	local pivot = self._pivot
	if pivot.x ~= x or pivot.y ~= y then
		pivot.x, pivot.y = x, y
		self:deferRefreshSelf()
	end
	return self
end

---Sets the pivot of this Control with a Vec2
---@param vec Vec2
---@return Control
function Control:setPivotVec(vec)
	self:setPivot(vec.x, vec.y)
	return self
end

---Sets the pivot X offset of this Control
---@param x number
---@return Control
function Control:setPivotX(x)
	local pivot = self._pivot
	if pivot.x ~= x then
		pivot.x = x
		self:deferRefreshSelf()
	end
	return self
end

---Sets the pivot Y offset of this Control
---@param y number
---@return Control
function Control:setPivotY(y)
	local pivot = self._pivot
	if pivot.y ~= y then
		pivot.y = y
		self:deferRefreshSelf()
	end
	return self
end

---Sets the rotation of this Control
---@param rotation number
---@return Control
function Control:setRotation(rotation)
	rotation = (rotation and rotation % PI2) or 0
	if self._rotation ~= rotation then
		self._rotation = rotation
		self:deferRefreshSelf()
	end
	return self
end

---Sets the scale of this Control
---@param x number
---@param y number
---@return Control
function Control:setScale(x, y)
	local scale = self._scale
	if scale.x ~= x or scale.y ~= y then
		scale.x, scale.y = x, y
		self:deferRefreshSelf()
	end
	return self
end

---Sets the scale of this Control with a Vec2
---@param vec Vec2
---@return Control
function Control:setScaleVec(vec)
	self:setScale(vec.x, vec.y)
	return self
end

---Sets the scale X offset of this Control
---@param x number
---@return Control
function Control:setScaleX(x)
	local scale = self._scale
	if scale.x ~= x then
		scale.x = x
		self:deferRefreshSelf()
	end
	return self
end

---Sets the scale Y offset of this Control
---@param y number
---@return Control
function Control:setScaleY(y)
	local scale = self._scale
	if scale.y ~= y then
		scale.y = y
		self:deferRefreshSelf()
	end
	return self
end

---@alias Control.AnchorPreset
---| "full"
---| "center"
---| "topLeft"
---| "topRight"
---| "bottomLeft"
---| "bottomRight"

---@type {[Control.AnchorPreset]: number[]}
local presets = {
	full = {0, 0, 1, 1},
	center = {0.5, 0.5, 0.5, 0.5},

	topLeft = {0, 0, 0, 0},
	topRight = {1, 0, 1, 0},
	bottomLeft = {0, 1, 0, 1},
	bottomRight = {1, 1, 1, 1},
}

---Bulk sets the anchor values to a preset, or to all zeros if 'preset' is nil.
---@generic T: Control
---@param self T | Control
---@param preset Control.AnchorPreset?
---@return T
function Control:setAnchorPreset(preset)
	local p = (preset ~= nil and presets[preset]) or presets.topLeft
	if not p then
		error(("'%s' is not a valid anchor preset"):format(preset))
	end

	self:setAnchors(p[1], p[2], p[3], p[4])
	return self
end

---Sets the Theme used for this Control, and whatever is beneath it
---@param theme Theme
---@return self
function Control:setTheme(theme)
	self._theme = theme
	self:_eOnThemeChanged()
	return self
end

---Sets the subclass, and maps it according to the subclass map
---@param subclass string
---@return self
function Control:setSubclass(subclass)
	self._currentOriginalSubclass = subclass
	local newSubclass = self.subclassMap[subclass]
	if self._currentSubclass ~= newSubclass then
		self._currentSubclass = newSubclass
		self:deferRefreshSelf()
	end
	return self
end

---Sets the subclass map. This table is responsible for mapping one subclass to another value.
---Subclass maps are used to provide variations of the same Control.
---It's recommended to create your variation inside of a Theme and call `:setVariant` instead.
---@param subclassMap {[string]: string} # The map
---@return self
function Control:setSubclassMap(subclassMap)
	if self.subclassMap ~= subclassMap then
		self.subclassMap = subclassMap
		self:setSubclass(self._currentOriginalSubclass)
	end
	return self
end

---Sets the variant without checking if it's a duplicate; called on Theme change
---@param self Control
---@param name string
local function forceSetVariant(self, name)
	self._variantName = name

	-- Get the class
	local CurrClass = (rawget(self, "__index") and self) or getmetatable(self)

	local theme = self._inheritedTheme
	local classIdToMap = theme.variantsForClass

	-- While we're looking at a Control...
	local newSubclassMap
	while CurrClass:is(Control) or CurrClass == Control do
		-- Check for any variations
		local variantMap = classIdToMap[CurrClass.CLASS_ID]
		if variantMap then
			-- This class has variations
			local classVariants = variantMap[name]
			if classVariants then
				-- The variations include the requested one
				newSubclassMap = classVariants
				break
			end
		end

		-- Go to the parent class
		CurrClass = getmetatable(CurrClass)
	end

	if not newSubclassMap then
		-- Couldn't find it
		print(("[Control:setVariant] Variant '%s' is not found in this Theme"):format(name))
		self:setSubclassMap(classIdToMap[Control.CLASS_ID][""] or DEFAULT_SUBCLASS_MAP)
	else
		-- Set the subclass map
		self:setSubclassMap(newSubclassMap)
	end
end

---Sets the variant/subclass map of this Control through the name.
---When the applied Theme changes, the variant name will be used to get the variation specific to that Theme.
---@generic T: Control
---@param self T | Control
---@param name string
---@return T
function Control:setVariant(name)
	if self._variantName == name then return self end
	forceSetVariant(self, name)
	return self
end

---Sets whether children will be clipped by this Control's bounding box
---@generic T: Control
---@param self T | Control
---@param clip boolean
---@return T
function Control:setClipChildren(clip)
	if self.clipChildren ~= clip then
		self.clipChildren = clip
	end
	return self
end

---Sets the input filter for this Control
---@param mode Control.InputFilter
---@return self
function Control:setInputMode(mode)
	if self._inputMode ~= mode then
		self._inputMode = mode
		self:_updateShash()
	end
	return self
end

---Sets the mouse input filter for this Control.
---Make sure the normal input filter is set to receive inputs.
---@generic T: Control
---@param self T | Control
---@param mode Control.InputFilter
---@return T
function Control:setMouseInputMode(mode)
	if self._mouseInputMode ~= mode then
		self._mouseInputMode = mode
		-- Updating shash here isn't necessary
	end
	return self
end

---Sets the grow direction of this Control.
---If a parameter is `nil`, it won't be modified.
---@generic T: Control
---@param self T | Control
---@param vertical number?
---@param horizontal number?
---@return T
function Control:setGrowDirection(vertical, horizontal)
	if vertical then self._growVertical = vertical end
	if horizontal then self._growHorizontal = horizontal end
	return self
end

---Sets the minimum size of the Control, and defers a self refresh if needed
---@generic T: Control
---@param self T | Control
---@param minSizeX number
---@param minSizeY number
---@return T
function Control:setMinimumSize(minSizeX, minSizeY)
	local oldMin = self._minimumSize
	if not oldMin or not oldMin:isEqual(minSizeX, minSizeY) then
		local wasMinimumSize = true

		if not oldMin then
			-- Create a new Vec2 if it doesn't exist
			oldMin = Vec2(minSizeX, minSizeY)
			self._minimumSize = oldMin
		else
			-- Min size Vec2 exists
			-- If the Control seems like it is limited to the minimum size, refresh it
			local lcr = self._localContentRect
			if not (lcr.w == oldMin.x or lcr.h == oldMin.y) then
				wasMinimumSize = false
			end

			-- Copy the values
			oldMin:iSetComponents(minSizeX, minSizeY)
		end

		if wasMinimumSize then
			-- Refresh if the current size looks like it was limited to the minimum size
			self:deferRefreshSelf()
		end
	end
	return self
end

---Sets the minimum size of the Control with a Vec2, and defers a self refresh if needed
---@generic T: Control
---@param self T | Control
---@param minSize Vec2
---@return T
function Control:setMinimumSizeVec(minSize)
	self:setMinimumSize(minSize.x, minSize.y)
	return self
end

---Returns the minimum size of the Control
---@return number minW
---@return number minH
function Control:getMinimumSize()
	local minSize = self._minimumSize
	if minSize then
		return minSize.x, minSize.y
	end
	return 0, 0
end

---Sets the maximum size of the Control, and defers a self refresh if needed
---@generic T: Control
---@param self T | Control
---@param maxSizeX number
---@param maxSizeY number
---@return T
function Control:setMaximumSize(maxSizeX, maxSizeY)
	local oldMax = self._maximumSize
	if not oldMax or not oldMax:isEqual(maxSizeX, maxSizeY) then
		local wasMaximumSize = true

		if not oldMax then
			-- Create a new Vec2 if it doesn't exist
			oldMax = Vec2(maxSizeX, maxSizeY)
			self._maximumSize = oldMax
		else
			-- Max size Vec2 exists
			-- If the Control seems like it is limited to the maximum size, refresh it
			local lcr = self._localContentRect
			if not (lcr.w == oldMax.x or lcr.h == oldMax.y) then
				wasMaximumSize = false
			end

			-- Copy the values
			oldMax:iSetComponents(maxSizeX, maxSizeY)
		end

		if wasMaximumSize then
			-- Refresh if the current size looks like it was limited to the maximum size
			self:deferRefreshSelf()
		end
	end
	return self
end

---Sets the maximum size of the Control with a Vec2, and defers a self refresh if needed
---@generic T: Control
---@param self T | Control
---@param maxSize Vec2
---@return T
function Control:setMaximumSizeVec(maxSize)
	self:setMaximumSize(maxSize.x, maxSize.y)
	return self
end

---Returns the maximum size of the Control
---@return number maxW
---@return number maxH
function Control:getMaximumSize()
	local maxSize = self._maximumSize
	if maxSize then
		return maxSize.x, maxSize.y
	end
	return huge, huge
end

---Returns all the anchor values
---@return number left
---@return number top
---@return number right
---@return number bottom
function Control:getAnchors()
	return self._anchorLeft, self._anchorTop, self._anchorRight, self._anchorBottom
end

---Returns all the anchor values
---@return number left
---@return number top
---@return number right
---@return number bottom
function Control:getOffsets()
	return self._offsetLeft, self._offsetTop, self._offsetRight, self._offsetBottom
end

---Sets the position of this Control, relative to the top-left corner
---@param gx integer
---@param gy integer
function Control:setPosition(gx, gy)
	local currX, currY = self._offsetLeft, self._offsetBottom
	local diffX, diffY =
		gx - currX,
		gy - currY

	-- Anchors don't work well here
	self._anchorLeft, self._anchorTop, self._anchorRight, self._anchorBottom = 0, 0, 0, 0
	self._offsetLeft, self._offsetTop, self._offsetRight, self._offsetBottom =
		currX + diffX,
		currY + diffY,
		self._offsetRight + diffX,
		self._offsetBottom + diffY
	self:deferRefreshSelf()
end

---Translates the offsets by the given amount
---@param x integer
---@param y integer
function Control:translate(x, y)
	self._offsetLeft, self._offsetRight, self._offsetTop, self._offsetBottom =
		self._offsetLeft + x,
		self._offsetRight + x,
		self._offsetTop + y,
		self._offsetBottom + y
	self:deferRefreshSelf()
end

---Sets the calculated position and size from the parent, and defers a self refresh
---@param x integer
---@param y integer
---@param w integer
---@param h integer
function Control:_setCanonRect(x, y, w, h)
	local lcr = self._localContentRect
	if lcr.x ~= x or lcr.y ~= y or lcr.w ~= w or lcr.h ~= h then
		lcr.x, lcr.y, lcr.w, lcr.h =
			x, y, w, h
		self:_updateGlobalBounds()
		self:deferRefreshSelf()
	end
end

---Calculates the rect of this Control relative if the parent was a certain size.
---Takes into account the min/max size allowed by growing right/down.
---@param w integer
---@param h integer
---@return integer x
---@return integer y
---@return integer w
---@return integer h
function Control:_getRectFromParentSize(w, h)
	local aLeft, aTop, aRight, aBottom =
		self._anchorLeft, self._anchorTop, self._anchorRight, self._anchorBottom
	local oLeft, oTop, oRight, oBottom =
		self._offsetLeft, self._offsetTop, self._offsetRight, self._offsetBottom

	local canonLeft, canonTop =
		w * aLeft + oLeft,
		h * aTop + oTop

	local canonRight, canonBottom =
		w * aRight + oRight,
		h * aBottom + oBottom

	if canonRight < canonLeft then
		canonRight = canonLeft
	end

	if canonBottom < canonTop then
		canonBottom = canonTop
	end

	local canonW, canonH =
		canonRight - canonLeft,
		canonBottom - canonTop

	-- Shrink to be under the maximum size
	local maxW, maxH = self:getMaximumSize()
	if canonW > maxW then
		local difference = canonW - maxW
		canonLeft = canonLeft + difference * self._growHorizontal
		canonW = maxW
	end
	if canonH > maxH then
		local difference = canonH - maxH
		canonRight = canonRight + difference * self._growVertical
		canonH = maxH
	end

	-- Grow to be above the minimum size
	do
		local ow, oh = self:getAppliedDrawable():getContentMargin()

		local minW, minH = self:getMinimumSize()
		minW, minH =
			minW + ow,
			minH + oh

		if canonW < minW then
			local difference = minW - canonW
			canonLeft = canonLeft - difference * self._growHorizontal
			canonW = minW
		end
		if canonH < minH then
			local difference = minH - canonH
			canonRight = canonRight - difference * self._growVertical
			canonH = minH
		end
	end

	return canonLeft, canonTop, canonW, canonH
end

---Returns a (read-only) `love.Transform` that contains the parent's offset/rotation/scale
function Control:_getParentTransform()
	if self._topLevelNode == self or not self._inTree then
		-- This Control does not rely on what is above it; it can calculate its dimensions itself
		return BLANK_TRANSFORM
	else
		-- This Control relies on the parent to calculate the new position
		return self.parent._globalTransform
	end
end

---Returns the size of this Control with the offset alone
---@return number w
---@return number h
function Control:_getOffsetSize()
	local oLeft, oTop, oRight, oBottom =
		self._offsetLeft, self._offsetTop, self._offsetRight, self._offsetBottom
	return math.abs(oRight - oLeft), math.abs(oBottom - oTop)
end

---Called when a child or descendant is focused. Controls that sort children should implement this.
---@param child Control
function Control:_focusOnChild(child)
	self:shallowBubble("_focusOnChild", self)
end

---A simple function for standard child resizing relative to the dimensions
---@param child Control
---@param w integer
---@param h integer
function Control:_simpleRefresh(child, w, h)
	local childX, childY, childW, childH = child:_getRectFromParentSize(w, h)
	child:_setCanonRect(childX + self._localContentRect.x, childY + self._localContentRect.y, childW, childH)
	child:onRefreshed()
end

---Called whenever the global axis-aligned bounds of the content inside this Control *should* change.
---Can occur when:
---* Local bounds change
---* This Control moves in global space
function Control:_updateGlobalBounds()
	self._globalContentRect:iCopyRect(self._localContentRect):iTransformBox(self._globalTransform)
end

---When a drag is requested on this Control, returns the data to pass.
---The second return value is the drag preview. It is destroyed immediately after dragging.
---@return any dragData
---@return Control? preview # The drag preview
function Control:_getDragData()
end

---Returns `true` if the given data can be dropped here
---@param posX number
---@param posY number
---@param data any
---@return boolean canDrop
function Control:_canDropData(posX, posY, data)
	return false
end

---Receives the dropped data
---@param posX number
---@param posY number
---@param data any
function Control:_dropData(posX, posY, data)
end

---Updates the positions of the children below.
---If you'd like to refresh *this Control*, use `:forceRefreshSelf()`.
function Control:forceRefresh()
	local lcr = self._localContentRect
	local w, h = lcr.w, lcr.h
	for i = 1, #self.children do
		local child = self.children[i]
		if child:is(Control) and child._visible then
			---@cast child Control
			-- TODO: This one is required due to logic flow
			self:_simpleRefresh(child, w, h)
		end
	end
end

---Tries to refresh this Control's position through the most relevant method
function Control:forceRefreshSelf()
	if not self._inTree then return end
	if self._topLevelNode == self then
		-- This Control does not rely on what is above it; it can calculate its dimensions itself
		local x, y, w, h = self:getViewport():getSafeArea()
		local childX, childY, childW, childH = self:_getRectFromParentSize(w, h)
		self:_setCanonRect(childX + x, childY + y, childW, childH)
		self:onRefreshed()
	else
		-- This Control relies on the parent to calculate the new position
		self:shallowBubble("forceRefresh")
	end
end

---Queues this Control's refreshing of its children to when the RootNode is free to do so.
---It's good practice to use this, as it'll find the lowest common denominator required to refresh.
function Control:deferRefresh()
	if not self._inTree then return end
	self:getViewport():insertDeferRefresh(self)
end

---Like `Control:deferRefresh`, but for itself
function Control:deferRefreshSelf()
	if not self._inTree then return end
	if self._topLevelNode == self then
		-- This Control does not rely on what is above it; it can calculate its dimensions itself
		-- (The parent may not be a Control, but do this anyways)
		self:getViewport():insertDeferRefresh(self, true)
	else
		-- This Control relies on the parent to calculate the new position
		self:shallowBubble("deferRefresh")
	end
end

---Gets the Theme that will be applied to this Control by looking at itself and any parents
---@return Theme
function Control:getAppliedTheme()
	return self._inheritedTheme
end

---Returns the DrawRequest that is used for this Control
---@return DrawRequest
function Control:getAppliedDrawable()
	local classMap = self._inheritedDRMap
	return classMap[self._currentSubclass] or classMap[""]
end

function Control:draw()
	local activeTheme = self._inheritedTheme
	local classMap = activeTheme._calculatedMap[self.CLASS_ID]
	local drawable = classMap[self._currentSubclass] or classMap[""]
	drawable:draw(self)
end

function Control:_beforeDraw()
	love.graphics.push("all")
	love.graphics.setColor(self.albedo)
	love.graphics.replaceTransform(self._globalTransform)
	if self._topLevelNode == self then
		-- love.graphics.origin()
		love.graphics.setScissor()
	end

	if self.clipChildren then
		local gcr = self._globalContentRect
		love.graphics.intersectScissor(gcr.x, gcr.y, gcr.w, gcr.h)
	end
end

function Control:_afterDraw()
	love.graphics.pop()
end

Control._drawChildren = Node._drawChildren

function Control:onViewportAdded(_)
	-- If we're not added to a Control, refresh relative to the Canvas
	local parent = self.parent
	---@cast parent Node
	self:_eOnThemeChanged()
	if not parent:is(Control) then
		-- This Control is on the top-level
		self:getRoot()._controlTopLevelLayers[self] = self:getCanvasLayerUsed()
		self:_updateDepth(1, self)
		self:deferRefreshSelf()
	else
		---@cast parent Control
		self:_updateDepth(parent._depth + 1, parent._topLevelNode)
		self:_updateShash()
	end
end

function Control:onViewportRemoved(oldViewport)
	oldViewport._deferredRefresh[self] = nil
	self:_removeShash()
end

function Control:_updateDepth(newDepth, newTopLevel)
	self._depth, self._topLevelNode = newDepth, newTopLevel
	self:shallowEmit("_updateDepth", newDepth + 1, newTopLevel)
end

function Control:update(dt) end

---Returns the Shash used for this Control
---@return table
function Control:getShash()
	-- TODO: Emitting runs refresh functions before children get the parent viewport; this is a temporary fix
	if not self._parentViewport then
		self._parentViewport = self.parent._parentViewport
	end
	return self:getViewport()._controlShash
end

function Control:forceDestroy(recursive)
	Control.super.forceDestroy(self, recursive)
	if self._inShash then
		self:getShash():remove(self)
	end

	if self._topLevelNode == self then
		self:getRoot()._controlTopLevelLayers[self] = nil
	end

	if self._pushedAsModal then
		self:popModal()
	end

	self.neighborLeft, self.neighborTop, self.neighborRight, self.neighborBottom,
	self.neighborNext, self.neighborPrevious
		= nil, nil, nil, nil, nil, nil
end

---Adds, updates, or removes this Control from the Shash, depending on its status
function Control:_updateShash()
	local inTree, inShash =
		self._inTree, self._inShash
	local shash = self:getShash()

	if not inTree or self._inputMode == "ignore" then
		-- Not in the tree or can't receive input
		if inShash then
			-- Was in the Shash, remove ourselves
			shash:remove(self)
			self._inShash = false
		end
	else
		-- Currently in the tree and can receive input
		local lcr = self._localContentRect
		local gx, gy, gw, gh = lcr:transformBox(self._globalTransform)
		if not inShash then
			-- Add to the shash
			shash:add(self, gx, gy, gw, gh)
			self._inShash = true
		else
			-- Update the shash
			shash:update(self, gx, gy, gw, gh)
		end
	end
end

---Removes this Control from the Shash
function Control:_removeShash()
	if self._inShash then
		self:getShash():remove(self)
		self._inShash = false
	end
end

---Returns whether this Control can get focused
---@param isMouse boolean # If the input is from the mouse
---@return boolean canFocus
function Control:canFocus(isMouse)
	local mode = self.focusMode
	return mode == "all" or (mode == "click" and isMouse)
end

---Checks if we can receive this input, with a global screen position used if it is mouse input.
---Does not check if the given point overlaps; you'll have to use `:doesPointOverlap`.
---@overload fun(self, isMouse: false): boolean
---@overload fun(self, isMouse: true, gx: integer, gy: integer): boolean
function Control:canReceiveInput(isMouse, gx, gy)
	if self._inputMode == "ignore" then return false end
	if isMouse and self._mouseInputMode == "ignore" then return false end

	---@type boolean # If we're not blocked by a modal, by either being directly under or not having one active
	local allowedByModal = true
	---@type Control?
	local modal
	do
		local modalStack = self:getRoot()._modalStack
		modal = modalStack[#modalStack]
		if modal then
			-- Blocked, until we find this modal
			allowedByModal = modal == self
			if allowedByModal then
				-- Ancestors can't block mouse input when this Control is a modal
				isMouse = false
			end
		end
	end

	-- Check the top-level node if it's being drawn (it's commonly hidden entirely)
	local topLevelNode = self._topLevelNode
	if not topLevelNode or not topLevelNode._visible then return false end

	-- Go through all parent Controls and see if this point is inside them + visible
	local currNode = self.parent
	while currNode and currNode:is(Control) do
		---@cast currNode Control
		if -- This Control cannot receive input if...
			not currNode._visible -- ...its not visible,
			or currNode._inputMode == "sink" -- ...or sinking inputs for later children,
			or (
				isMouse -- ...or if its mouse input, and...
				and (
					-- ...either...
					currNode._mouseInputMode == "sink" -- Sinking MOUSE inputs for later children
					or
					--...or clipping the input
					(
						currNode.clipChildren
						and not currNode:doesPointOverlap(gx, gy)
					)
				)
			)
		then
			return false
		end

		if currNode == topLevelNode then
			-- Current node is the top-level, and we've already checked their visibility
			break
		end

		if currNode == modal then
			-- Found the modal
			-- Also disable blocking mouse input beyond this point
			isMouse = false
			allowedByModal = allowedByModal or currNode == modal
		end
		currNode = currNode.parent
	end

	-- Go through the rest, and check if the rest of the parents are visible
	while currNode do
		if not currNode._visible then
			return false
		end

		allowedByModal = allowedByModal or currNode == modal
		currNode = currNode.parent
	end

	-- Check if this Control is running with the current process mode
	-- TODO: Do this while iterating through each parent
	return allowedByModal and self:getRoot():isRunning(self)
end

---Grabs the focus, if possible
---@param isMouse boolean
function Control:grabFocus(isMouse)
	if self:canFocus(isMouse or false) and not self:hasFocus() then
		self:getRoot():focusOnControl(self, isMouse)
	end
end

---Releases the focus from this Control, if it has it
function Control:releaseFocus()
	if self:hasFocus() then
		self:getRoot():focusOnControl(nil, false)
	end
end

---Called whenever this Control or ancestor changes their Theme
function Control:_eOnThemeChanged()
	local ownTheme = self._theme
	local inheritedTheme = self._inheritedTheme
	if ownTheme == nil or (ownTheme and ownTheme ~= inheritedTheme) then
		-- Inherit the theme from the parent
		local parent = self.parent
		local chosenTheme = (parent and parent._inheritedTheme) or self:getRoot():getDefaultTheme()
		self._inheritedTheme = chosenTheme
		self._inheritedDRMap = chosenTheme._calculatedMap[self.CLASS_ID]

		-- Get the new subclass variant
		forceSetVariant(self, self._variantName)

		if self._inheritedTheme ~= inheritedTheme then
			-- The inherited theme changed
			self:shallowEmit("_eOnThemeChanged")
		end
	end
end

---Returns the CanvasLayer, or RootNode, used for layering
---@return CanvasLayer | RootNode | nil
function Control:getCanvasLayerUsed()
	---@type Node?
	local currNode = self
	local root = self:getRoot()

	while currNode do
		if currNode:is(CanvasLayer) or currNode == root then
			---@cast currNode RootNode
			return currNode
		end

		currNode = currNode.parent
	end

	-- Not found
	return nil
end

---Called when the parent force refreshes this Control.
---This usually occurs at the end of the frame.
function Control:onRefreshed()
	local pivot, scale, rotation =
		self._pivot, self._scale, self._rotation
	local lcr = self._localContentRect
	local lcrX, lcrY = lcr.x, lcr.y
	local scaleX, scaleY = scale.x, scale.y
	local pivotX, pivotY = pivot.x, pivot.y

	local parentTransform = self:_getParentTransform()
	local ownTransform = self._globalTransform

	TEMP_TRANSFORM:setTransformation(lcrX + pivotX, lcrY + pivotY, rotation, scaleX, scaleY)
	ownTransform
		:setMatrix("row", parentTransform:getMatrix())
		:apply(TEMP_TRANSFORM)
		:translate(-lcrX - pivotX, -lcrY - pivotY)

	self:_updateGlobalBounds()
	self:_updateShash()
	self:getAppliedDrawable():themeUpdate(self)
	self:forceRefresh()
end

---Converts a Viewport point into a local one
---@param gx number
---@param gy number
---@return number lx
---@return number ly
function Control:toLocal(gx, gy)
	local lx, ly = self._globalTransform:inverseTransformPoint(gx, gy)
	local lcr = self._localContentRect
	return lx - lcr.x, ly - lcr.y
end

---Converts a local point into a Viewport one
---@param lx number
---@param ly number
---@return number gx
---@return number gy
function Control:toGlobal(lx, ly)
	local lcr = self._localContentRect
	local gx, gy = self._globalTransform:transformPoint(lx + lcr.x, ly + lcr.y)
	return gx, gy
end

---Checks if a point overlaps with this Control, but NOT if the point is clipped by an ancestor
---@param gx integer
---@param gy integer
---@return boolean overlapping
function Control:doesPointOverlap(gx, gy)
	local lx, ly = self._globalTransform:inverseTransformPoint(gx, gy)
	return self._localContentRect:containsPoint(lx, ly)
end

---Checks if a point overlaps with this Control and if unclipped by an ancestor
---@param gx integer
---@param gy integer
---@return boolean overlapping
function Control:doesPointOverlapClipped(gx, gy)
	if not self:doesPointOverlap(gx, gy) then return false end

	-- Go through all parent Controls and see if this point is inside them + visible
	local currNode = self.parent
	local topLevelNode = self._topLevelNode
	while currNode and currNode:is(Control) do
		---@cast currNode Control
		if -- This Control cannot receive input if...
			--...it is clipping the input
			(
				currNode.clipChildren
				-- TODO: Use :doesPointOverlap?
				-- clipChildren uses the global content rect,
				-- while :canReceiveInput uses :doesPointOverlap.
				-- This means we're correct visually here
				and not currNode._globalContentRect:containsPoint(gx, gy)
			)
		then
			return false
		end

		if currNode == topLevelNode or currNode._pushedAsModal then
			-- Reached the top (or a modal, which ignores what is above)
			break
		end
		currNode = currNode.parent
	end
	return true
end

---Pushes self onto the modal stack. This Control will receive all input events first.
function Control:pushModal()
	self:getRoot():pushControlModal(self)
end

---Pops self off the modal stack. This Control will receive input events in the default order.
function Control:popModal()
	self:getRoot():popControlModal(self)
end

---Returns `true` if this Control has been pushed as a modal
---@return boolean isModal
function Control:isModal()
	return self._pushedAsModal
end

---Returns `true` if this Control currently has the focus
---@return boolean hasFocus
function Control:hasFocus()
	return self:getRoot()._focusedControl == self
end

---Called when the mouse enters this Control
---@param x integer
---@param y integer
function Control:uiMouseEntered(x, y)
	self._hovered = true
end

---Called when the mouse leaves this Control
function Control:uiMouseExited()
	self._hovered = false
end

---Called when this Control gains focus, such as through keyboard navigation
---@param isMouse boolean
function Control:uiFocused(isMouse)
	self._focused = true
	self:shallowBubble("_focusOnChild", self)
end

---Called when this Control loses focus, such as the keyboard navigating elsewhere or clicking somewhere else
function Control:uiFocusLost()
	self._focused = false
end

---Called when the UI is activated through a button press, such as the spacebar or A button on a gamepad
function Control:uiActivate()
end

---Called when the UI is deactivated from a button press
function Control:uiDeactivate()
end

---When requested to select the 'next' Control, what are we selecting?
---@return boolean handled
---@return Control? newNode # Can be `self`
function Control:uiSelectNext()
	local existing = self.neighborNext
	if existing and existing:canFocus(true) then
		return true, existing
	end
	return false, nil
end

---When requested to select the 'previous' Control, what are we selecting?
---@return boolean handled
---@return Control? newNode # Can be `self`
function Control:uiSelectPrevious()
	local existing = self.neighborPrevious
	if existing and existing:canFocus(true) then
		return true, existing
	end
	return false, nil
end

---When requested to select the 'above' Control, what are we selecting?
---@return boolean handled
---@return Control? newNode # Can be `self`
function Control:uiSelectUp()
	local existing = self.neighborTop
	if existing and existing:canFocus(true) then
		return true, existing
	end
	return false, nil
end

---When requested to select the 'below' Control, what are we selecting?
---@return boolean handled
---@return Control? newNode # Can be `self`
function Control:uiSelectDown()
	local existing = self.neighborBottom
	if existing and existing:canFocus(true) then
		return true, existing
	end
	return false, nil
end

---When requested to select the 'left' Control, what are we selecting?
---@return boolean handled
---@return Control? newNode # Can be `self`
function Control:uiSelectLeft()
	local existing = self.neighborLeft
	if existing and existing:canFocus(true) then
		return true, existing
	end
	return false, nil
end

---When requested to select the 'right' Control, what are we selecting?
---@return boolean handled
---@return Control? newNode # Can be `self`
function Control:uiSelectRight()
	local existing = self.neighborRight
	if existing and existing:canFocus(true) then
		return true, existing
	end
	return false, nil
end

function Control:addChild(child)
	Control.super.addChild(self, child)
	self:deferRefresh()
	return self
end

function Control:removeChildAtIndex(index, shouldDestroy)
	Control.super.removeChildAtIndex(self, index, shouldDestroy)
	self:deferRefresh()
end

function Control:clearChildren(shouldDestroy)
	Control.super.clearChildren(self, shouldDestroy)
	self:deferRefresh()
end

---@generic T: Control
---@param self T | Control
---@return T
function Control:setVisible(visible)
	if self._visible ~= visible then
		self:deferRefreshSelf()
		return Control.super.setVisible(self, visible)
	end
	return self
end

function Control._addDefinition(entry)
	entry:newNumber("_anchorLeft", 0, nil, nil, nil, "setAnchorLeft")
	entry:newNumber("_anchorRight", 0, nil, nil, nil, "setAnchorRight")
	entry:newNumber("_anchorTop", 0, nil, nil, nil, "setAnchorTop")
	entry:newNumber("_anchorBottom", 0, nil, nil, nil, "setAnchorBottom")
	entry:newInteger("_offsetLeft", 0, nil, nil, nil, "setOffsetLeft")
	entry:newInteger("_offsetRight", 0, nil, nil, nil, "setOffsetRight")
	entry:newInteger("_offsetTop", 0, nil, nil, nil, "setOffsetTop")
	entry:newInteger("_offsetBottom", 0, nil, nil, nil, "setOffsetBottom")
	entry:newVec2("_pivot", Vec2(0, 0), "setPivotVec")
	entry:newNumber("_rotation", 0, nil, nil, nil, "setRotation")
	entry:newVec2("_scale", Vec2(1, 1), "setScaleVec")
	entry:newVec2("_minimumSize", nil, "setMinimumSizeVec")
	entry:newVec2("_maximumSize", nil, "setMaximumSizeVec")
	entry:newNumber("_growVertical", 0, 0, 1, nil, "%deferRefreshSelf")
	entry:newNumber("_growHorizontal", 0, 0, 1, nil, "%deferRefreshSelf")

	local inputModes = {
		pass = true,
		sink = true,
		ignore = true,
	}
	entry:newEnum("_inputMode", inputModes, "pass", "setInputMode")
	entry:newEnum("_mouseInputMode", inputModes, "pass", "setMouseInputMode")

	local focusModes = {
		all = true,
		click = true,
		none = true,
	}
	entry:newEnum("focusMode", focusModes, "none")

	entry:newString("_currentOriginalSubclass", "normal", nil, nil, "setSubclass")
	entry:newString("_variantName", "", nil, nil, "setVariant")
	entry:newColor("albedo")
	entry:newBoolean("clipChildren", false, "setClipChildren")
	entry:newBoolean("_modalDrawOnTop", false)
	entry:newBoolean("_modalDrawPreviousModals", true)
end

return Control
