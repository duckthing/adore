---@type AnimationTrack
local AnimationTrack = require "common.animation.animationtrack"
---@type PropertyTrack.Seeker
local PTrackSeeker = require "common.animation.propertytrackseeker"
local sort = table.sort
local min, max = math.min, math.max

---@class PropertyTrack: AnimationTrack
---@field super AnimationTrack
---@overload fun(animation: Animation, nodePath: NodePath, propertyName: string, keyframes: PropertyTrack.KeyFrame[]?, valueMode: PropertyTrack.ValueMode?): PropertyTrack
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
---@param keyframes PropertyTrack.KeyFrame[]?
---@param mode PropertyTrack.ValueMode?
function PTrack:new(animation, nodePath, propertyName, keyframes, mode)
	PTrack.super.new(self, animation, nodePath)

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

return PTrack
