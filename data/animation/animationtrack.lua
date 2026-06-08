---@type AdoreInit
local Adore = require ""
local Object = Adore.Resources("Object")
local sort = table.sort
local max = math.max

---@class AnimationTrack: Object
---@overload fun(animation: Animation, nodePath: NodePath): PropertyTrack
local AnimationTrack = Object:extend()
AnimationTrack.CLASS_NAME = "AnimationTrack"
AnimationTrack.TRACK_TYPE = "none"

---@class AnimationTrack.KeyFrame
---@field time number # When this keyframe begins

---@param animation Animation
---@param nodePath NodePath
function AnimationTrack:new(animation, nodePath)
	AnimationTrack.super.new(self)

	---@type Animation
	self.sourceAnimation = animation
	---@type NodePath
	self.nodePath = nodePath

	---@type number # How long this Track runs for
	self._ownDuration = 0

	---@type PropertyTrack.KeyFrame[]
	self.keyframes = nil
end

---Inserts a KeyFrame into the Track, overwriting any KeyFrame that exists at that time
---@param keyframe AnimationTrack.KeyFrame
function AnimationTrack:insertKeyframe(keyframe)
	local time = keyframe.time
	local keyframes = self.keyframes
	local _, index = self:getNextKeyframe(time)
	index = index or (#keyframes + 1)
	table.insert(keyframes, index, keyframe)

	for i = index + 1, index - 1, -2 do
		-- Check 1 ahead and 1 behind the insertion point to see if there's a keyframe at this exact time
		-- TODO: Make detecting similar times better
		local k = keyframes[i]
		if k and k.time == time then
			table.remove(keyframes, i)
		end
	end
end

---Starting at `time`, looks forward (from `startingIndex`, or 1) to find the next KeyFrame
---@param time number
---@param startingIndex number? # Looks at this KeyFrame index and forward; skips the first few indices
---@return AnimationTrack.KeyFrame? keyframe
---@return integer? index
function AnimationTrack:getNextKeyframe(time, startingIndex)
	local keyframes = self.keyframes
	for i = startingIndex or 1, #keyframes do
		local keyframe = keyframes[i]
		if keyframe.time > time then
			-- This KeyFrame passed the specified time
			-- Return this KeyFrame
			local nextKeyframe = keyframes[i]
			return nextKeyframe, i
		end
	end

	return nil, nil
end

---Returns the KeyFrame that occurs just before `time` (from `startingIndex`, or 1)
---@param time number
---@param startingIndex number? # Looks at this KeyFrame index and forward; skips the first few indices
---@return AnimationTrack.KeyFrame? keyframe
---@return integer? index
function AnimationTrack:getPreviousKeyframe(time, startingIndex)
	local keyframes = self.keyframes
	for i = max(startingIndex or 1, 1), #keyframes do
		local keyframe = keyframes[i]
		if keyframe.time > time then
			-- This KeyFrame passed the specified time
			-- Return the previous KeyFrame, if it exists
			local previousKeyframe = keyframes[i - 1]
			return previousKeyframe, (previousKeyframe and i - 1) or nil
		end
	end

	return keyframes[#keyframes], #keyframes
end

---Returns the pair of KeyFrames that contain `time` (from `startingIndex`, or 1).
---* If there's an exact match, `lowerKeyFrame` will equal `time`
---* If less than 0, `lowerKeyFrame` will be `nil` and `upperKeyFrame` will be the first KeyFrame
---* If greater than the last KeyFrame time, `lowerKeyFrame` will be returned and `upperKeyFrame` will be `nil`
---@param time number
---@param startingIndex number? # Looks at this KeyFrame index and forward; skips the first few indices
---@return AnimationTrack.KeyFrame? lowerKeyFrame
---@return AnimationTrack.KeyFrame? upperKeyFrame
---@return integer? lowerIndex
---@return integer? upperIndex
function AnimationTrack:getKeyframePairs(time, startingIndex)
	local keyframes = self.keyframes
	for i = max(startingIndex or 1, 1), #keyframes do
		local keyframe = keyframes[i]
		if keyframe.time >= time then
			-- This KeyFrame just passed the specified time
			-- Return this KeyFrame and the former
			local previousKeyframe = keyframes[i - 1]
			return previousKeyframe, keyframe, (previousKeyframe and i - 1) or nil, i
		end
	end

	-- `time` is past the end of the available KeyFrames
	local lastIndex = #keyframes
	if lastIndex ~= 0 then
		return keyframes[lastIndex], nil, lastIndex, nil
	end

	-- No KeyFrames exist
	return nil
end

---Similar to `AnimationTrack:getKeyframePairs`, but iterates backwards.
---@param time number
---@param startingIndex number? # Looks at this KeyFrame index and before; skips the last few indices
---@return AnimationTrack.KeyFrame? lowerKeyFrame
---@return AnimationTrack.KeyFrame? upperKeyFrame
---@return integer? lowerIndex
---@return integer? upperIndex
function AnimationTrack:getKeyframePairsBackwards(time, startingIndex)
	local keyframes = self.keyframes
	local totalKeyframes = #keyframes

	if time < 0 then
		return nil, keyframes[1], nil, (keyframes[1] and 1) or nil
	end

	for i = max(startingIndex or totalKeyframes, totalKeyframes), 1, -1 do
		local keyframe = keyframes[i]
		if keyframe.time <= time then
			-- This KeyFrame is before the specified time
			-- Return this KeyFrame and the later one
			local nextKeyframe = keyframes[i + 1]
			return keyframe, nextKeyframe, i, (nextKeyframe and i + 1) or nil
		end
	end
end

local function sortKeyframes(a, b)
	return a.time < b.time
end

---Sorts the keyframes of this AnimationTrack by their time, and then sets the duration of this track
function AnimationTrack:_sort()
	local keyframes = self.keyframes
	sort(keyframes, sortKeyframes)
	if #keyframes > 0 then
		self._ownDuration = keyframes[#keyframes].time
	else
		self._ownDuration = 0
	end
end

function AnimationTrack._addDefinition(entry)
	entry:newObject("sourceAnimation", "Animation")
	entry:newString("nodePath")
	entry:newNumber("_ownDuration", 0, 0)
end

return AnimationTrack
