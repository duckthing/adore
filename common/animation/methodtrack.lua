---@type AnimationTrack
local AnimationTrack = require "common.animation.animationtrack"
---@type MethodTrack.Seeker
local MTrackSeeker = require "common.animation.methodtrackseeker"
local sort = table.sort
local min, max = math.min, math.max

---@class MethodTrack: AnimationTrack
---@field super AnimationTrack
---@overload fun(animation: Animation, nodePath: NodePath, keyframes: MethodTrack.KeyFrame[]?): MethodTrack
local MTrack = AnimationTrack:extend()
MTrack.CLASS_NAME = "MethodTrack"
MTrack.TRACK_TYPE = "method"

---@class MethodTrack.KeyFrame: AnimationTrack.KeyFrame
---@field method string # The method to call
---@field args any[]? # The arguments to pass

---@param animation Animation
---@param nodePath NodePath
---@param keyframes MethodTrack.KeyFrame[]?
function MTrack:new(animation, nodePath, keyframes)
	MTrack.super.new(self, animation, nodePath)

	---@type MethodTrack.KeyFrame[]
	self.keyframes = keyframes or {}
	if keyframes then self:_sort() end
end

---Adds a new KeyFrame to the AnimationTrack
---@param time number # When this KeyFrame should happen
---@param method string # The method to call
---@param args any[]? # An array of arguments; can be nil
function MTrack:newKeyframe(time, method, args)
	self:insertKeyframe({time = time, method = method, args = args})
end

---Creates a new MethodTrack.Seeker, with NodePath resolving relative to `node`
---@param node Node
---@return MethodTrack.Seeker
function MTrack:newSeeker(node)
	return MTrackSeeker(self, node)
end

---Performs all calls on `node` requested from keyframes later than or equal to `fromTime`.
---If `startingIndex` is passed, it starts looking there.
---Will always stop when either the Animation's duration or `toTime` is passed.
---@param node Node
---@param fromTime number
---@param toTime number?
---@param startingIndex integer?
function MTrack:callForwards(node, fromTime, toTime, startingIndex)
	local keyframes = self.keyframes
	local calling = false
	local duration = self.sourceAnimation.duration
	toTime = min(toTime or duration, duration)

	for i = max(startingIndex or 1, 1), #keyframes do
		local keyframe = keyframes[i]

		if not calling and keyframe.time >= fromTime then
			-- This KeyFrame passed the specified time
			-- All later KeyFrames should be called
			calling = true
		end

		if keyframe.time > toTime then
			-- Passed the Animation's duration, stop
			return
		end

		if calling then
			-- Perform the method call
			if keyframe.args then
				node[keyframe.method](node, unpack(keyframe.args))
			else
				node[keyframe.method](node)
			end
		end
	end
end

---Performs all calls on `node` requested from keyframes earlier than or equal to `time`.
---If `startingIndex` is passed, it starts looking there.
---Will always stop when either 0 or `toTime` is passed.
---`toTime` should be less than `fromTime`.
---@param node Node
---@param fromTime number
---@param toTime number?
---@param startingIndex integer?
function MTrack:callBackwards(node, fromTime, toTime, startingIndex)
	local keyframes = self.keyframes
	local totalKeyframes = #keyframes
	local calling = false
	toTime = max(toTime or 0, 0)

	for i = max(startingIndex or totalKeyframes, totalKeyframes), 1, -1 do
		local keyframe = keyframes[i]

		if not calling and keyframe.time <= fromTime then
			-- This KeyFrame passed the specified time
			-- All later KeyFrames should be called
			calling = true
		end

		if keyframe.time < toTime then
			-- Passed the Animation's bounds, stop
			return
		end

		if calling then
			-- Perform the method call
			if keyframe.args then
				node[keyframe.method](node, unpack(keyframe.args))
			else
				node[keyframe.method](node)
			end
		end
	end
end

---Performs all method calls on `node` in order from start to last, within the range [0, duration]
---@param node Node
function MTrack:callAllForwards(node)
	local keyframes = self.keyframes
	local duration = self.sourceAnimation.duration
	for i = 1, #keyframes do
		local frame = keyframes[i]
		local time = frame.time
		if time >= 0 then
			if time > duration then return end

			if frame.args then
				node[frame.method](node, frame.args and unpack(frame.args))
			else
				node[frame.method](node)
			end
		end
	end
end

---Performs all method calls on `node` in order from last to first, within the range [0, duration]
---@param node Node
function MTrack:callAllBackwards(node)
	local keyframes = self.keyframes
	local duration = self.sourceAnimation.duration
	for i = #keyframes, 1, -1 do
		local frame = keyframes[i]
		local time = frame.time
		if time <= duration then
			if time < 0 then return end

			if frame.args then
				node[frame.method](node, frame.args and unpack(frame.args))
			else
				node[frame.method](node)
			end
		end
	end
end

return MTrack
