---@type AdoreInit
local Adore = require ""
local SimpleObject = Adore.Libraries("SimpleObject")
local Control = Adore.Nodes("Control")
local DrawRequest = Adore.Resources("DrawRequest")

---@class Theme: SimpleObject
---@overload fun(inheritFrom: Theme?): Theme
local Theme = SimpleObject:extend()

---@param inheritsFrom Theme?
function Theme:new(inheritsFrom)
	Theme.super.new(self)

	---@type Theme? # What Theme, if any, do we inherit from
	self._inheritsFrom = inheritsFrom

	---@type Theme[] # Any Themes that inherit from us
	self._inherited = {}

	---@type {[integer]: {[string]: DrawRequest}} # A map of a class ID, to a subclass, to a Drawable. Not calculated.
	self.drawablesForClass = nil

	---@type {[integer]: {[string]: {[string]: string}}} # A map of a class ID, to a variant name, to a subclass map
	self.variantsForClass = nil

	if not inheritsFrom then
		-- Initialize
		self.drawablesForClass = {
			[Control.CLASS_ID] = {
				[""] = DrawRequest()
			}
		}

		self.variantsForClass = {
			[Control.CLASS_ID] = {
				[""] = {
					normal = ""
				}
			}
		}
	else
		-- Inherit through using a metatable
		inheritsFrom._inherited[#inheritsFrom._inherited+1] = self
		self.drawablesForClass = setmetatable(
			{
				_inherit = inheritsFrom.drawablesForClass
			},
			{
				__index = function(t, k)
					return rawget(t, "_inherit")[k]
				end
			}
		)

		self.variantsForClass = setmetatable(
			{
				_inherit = inheritsFrom.variantsForClass
			},
			{
				__index = function(t, k)
					return rawget(t, "_inherit")[k]
				end
			}
		)
	end

	---@type {[integer]: {[string]: DrawRequest}} # The calculated map from class ID to Drawable, which uses the former to set inherited DrawRequests.
	---Basically, it turns it into 1 lookup, versus n super class lookups for the overridden Drawable.
	self._calculatedMap = {}

	---@type {[integer]: {[string]: {[string]: string}}} # The calculated map from class ID to subclass shortcuts.
	self._calculatedSM = {}

	self._newControlEvent = Control.onNewControlInherited:connect(self, "_updateForClass")
	self:_updateMap()
end

---Updates the entire calculated map
function Theme:_updateMap()
	self:_updateForClass(Control)

	local inherited = self._inherited
	for i = 1, #inherited do
		inherited[i]:_updateForClass(Control)
	end
end

---Updated the calculated map for the specified class
---@param class Control
function Theme:_updateForClass(class)
	local calcMap = self._calculatedMap

	-- TODO: Make all inherited subclasses get passed down?
	-- We only inherit the most recent subclasses, not all of them.

	do
		-- Find the class we are inheriting our subclasses from
		local lastChangedClass = class
		local setDrawables = self.drawablesForClass[lastChangedClass.CLASS_ID]
		while not setDrawables do
			---@diagnostic disable-next-line
			lastChangedClass = lastChangedClass.super
			setDrawables = self.drawablesForClass[lastChangedClass.CLASS_ID]
		end

		-- Get the calculated subclass map for this class, or create it if it doesn't exist
		---@type {[string]: DrawRequest}
		local calcSubclassToDrawable = calcMap[class.CLASS_ID]
		if not calcSubclassToDrawable then
			-- Create it if it doesn't exist
			calcSubclassToDrawable = {}
			calcMap[class.CLASS_ID] = calcSubclassToDrawable
		end

		-- Set all the drawables in the calculated map
		for subclass, drawable in pairs(setDrawables) do
			calcSubclassToDrawable[subclass] = drawable
		end
	end

	-- Update all child classes
	for _, childClass in ipairs(class.INHERITED_BY) do
		self:_updateForClass(childClass)
	end
end

---Sets the Drawable
---@param class Control
---@param subclass string? # A variant of the current class, not the inherited class
---@param drawable DrawRequest
function Theme:setDrawable(class, subclass, drawable)
	subclass = subclass or ""

	local subclassToDrawable = self.drawablesForClass[class.CLASS_ID]
	if not subclassToDrawable then
		-- Create it if it doesn't exist
		subclassToDrawable = {}
		self.drawablesForClass[class.CLASS_ID] = subclassToDrawable

		local inheritsFrom = self._inheritsFrom
		if inheritsFrom then
			-- If we're inheriting, also search there
			setmetatable(subclassToDrawable, {__index = inheritsFrom.drawablesForClass[class.CLASS_ID]})
		end
	end

	subclassToDrawable[subclass] = drawable
	self:_updateForClass(class)
end

---Sets a named subclass map for a specific class, which is useful for variations of the same class.
---This allows `Control:setVariant` to receive a string and get this map directly.
---@param class Control
---@param variationName string? # The name of the variation
---@param subclassMap {[string]: string} # The subclass map
function Theme:setVariant(class, variationName, subclassMap)
	variationName = variationName or ""

	local variantNameToMap = self.variantsForClass[class.CLASS_ID]
	if not variantNameToMap then
		-- Create it if it doesn't exist
		variantNameToMap = {}
		self.variantsForClass[class.CLASS_ID] = variantNameToMap

		local inheritsFrom = self._inheritsFrom
		if inheritsFrom then
			-- If we're inheriting, also search there
			setmetatable(variantNameToMap, {__index = inheritsFrom.variantsForClass[class.CLASS_ID]})
		end
	end

	variantNameToMap[variationName] = subclassMap
end

---Gets the DrawRequest that will be used for a control
---@param control Control
---@return DrawRequest
function Theme:getDrawRequest(control)
	local calcMap = self._calculatedMap[control.CLASS_ID]
	return calcMap[control._currentSubclass] or calcMap[""]
end

---TODO: Check if a subclass doesn't exist

function Theme:destroy()
	self._newControlEvent:disconnect()
	self._newControlEvent = nil
end

return Theme
