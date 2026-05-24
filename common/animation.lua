---@type AdoreInit
local Adore = require ""
local SimpleObject = Adore.Libraries("SimpleObject")
---@type PropertyTrack
local PropertyTrack = require "common.animation.propertytrack"
---@type MethodTrack
local MethodTrack = require "common.animation.methodtrack"

---@alias Animation.TrackOptions
---| {type: "property", nodePath: NodePath, propertyName: string, keyframes: PropertyTrack.KeyFrame[]?, valueMode: PropertyTrack.ValueMode}
---| {type: "method", nodePath: NodePath, keyframes: MethodTrack.KeyFrame[]?}

---@class Animation: SimpleObject
---@overload fun(duration: number, loop: boolean, tracks: Animation.TrackOptions[]?): Animation
local Animation = SimpleObject:extend()
Animation.CLASS_NAME = "Animation"

---@alias Animation.TrackType
---| "property"
---| "method"

---@class Animation.Library
---@field name string
---@field animations {[string]: Animation}

---@param duration number
---@param loop boolean
---@param tracks {type: Animation.TrackType, nodePath: NodePath, propertyName: string, keyframes: PropertyTrack.KeyFrame[]?, valueMode: PropertyTrack.ValueMode?}[]?
function Animation:new(duration, loop, tracks)
	Animation.super.new(self)

	---@type AnimationTrack[]
	self.tracks = {}

	if tracks then
		for i = 1, #tracks do
			local trackData = tracks[i]
			local type = trackData.type
			if type == "property" then
				self.tracks[i] = PropertyTrack(self, trackData.nodePath, trackData.propertyName, trackData.keyframes, trackData.valueMode)
			elseif type == "method" then
				self.tracks[i] = MethodTrack(self, trackData.nodePath, trackData.keyframes)
			else
				error(("Undefined track type '%s'"):format(type))
			end
		end
	end

	---@type number # How long this Animation is allowed to run for
	self.duration = duration or 0
	---@type boolean # When reaching the end, will the Animation loop around
	self.loop = loop or false
end

---Sets whether this Animation will loop
---@param loop boolean
---@return self
function Animation:setLoop(loop)
	self.loop = loop
	return self
end

return Animation
