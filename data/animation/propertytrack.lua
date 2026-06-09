---@type AdoreInit
local Adore = require ""
local ClassDB = Adore.Common("ClassDB")
---@type AnimationTrack
local AnimationTrack = require "data.animation.animationtrack"
---@type PropertyTrack.Seeker
local PTrackSeeker = require "data.animation.propertytrackseeker"
local sort = table.sort
local min, max = math.min, math.max

---@class PropertyTrack: AnimationTrack
---@field super AnimationTrack
---@overload fun(animation: Animation, nodePath: NodePath, propertyName: string, baseClass: string?, keyframes: PropertyTrack.KeyFrame[]?, valueMode: PropertyTrack.ValueMode?): PropertyTrack
local PTrack = AnimationTrack:extend()
PTrack.CLASS_NAME = "PropertyTrack"
PTrack.TRACK_TYPE = "property"

---@class PropertyTrack.KeyFrame: AnimationTrack.KeyFrame
---@field value any

---@alias PropertyTrack.ValueMode
---| "continuous"
---| "discrete"

---@param animation Animation
---@param nodePath NodePath
---@param propertyName string
---@param baseClass string?
---@param keyframes PropertyTrack.KeyFrame[]?
---@param mode PropertyTrack.ValueMode?
function PTrack:new(animation, nodePath, propertyName, baseClass, keyframes, mode)
	PTrack.super.new(self, animation, nodePath)

	---@type string
	self.baseClass = baseClass or "Object"
	---@type string
	self.propertyName = propertyName
	---@type PropertyTrack.ValueMode
	self.valueMode = mode or "continuous"

	---@type PropertyTrack.KeyFrame[]
	self.keyframes = keyframes or {}
	if keyframes then self:_sort() end
end

---Adds a new KeyFrame to the AnimationTrack
---@param time number # When this KeyFrame should happen
---@param value any
function PTrack:newKeyframe(time, value)
	self:insertKeyframe({time = time, value = value})
end

---Creates a new PropertyTrack.Seeker, with NodePath resolving relative to `node`
---@param node Node
---@return PropertyTrack.Seeker
function PTrack:newSeeker(node)
	return PTrackSeeker(self, node)
end

function PTrack._addDefinition(entry)
	entry:newString("propertyName")
	entry:newString("valueMode")
	entry:newString("baseClass", "Object")
	entry:newArray(
		"keyframes",
		entry:newStruct("value", {
			time = entry:newNumber("time"):popProperty(),
			value = entry:newDynamic(
				"value",
				function(self, obj, propertyName, value, ...)
					---@type PropertyTrack
					local pTrack = ...

					if pTrack.baseClass then
						local baseClassEntry = ClassDB.getClassDBEntry(pTrack.baseClass)

						if baseClassEntry then
							local resultProperty = baseClassEntry:getProperty(pTrack.propertyName, true)
							return resultProperty
						end
					end
				end
			):popProperty()
		}):popProperty()
	)
end

return PTrack
