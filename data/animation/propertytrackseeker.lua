---@type AdoreInit
local Adore = require ""
local SimpleObject = Adore.Libraries("SimpleObject")
local min, max = math.min, math.max

---@class PropertyTrack.Seeker: SimpleObject
---@overload fun(track: PropertyTrack, startingNode: Node): PropertyTrack.Seeker
local PTrackSeeker = SimpleObject:extend()
PTrackSeeker.CLASS_NAME = "PropertyTrackSeeker"

---@param track PropertyTrack
---@param startingNode Node # Where NodePaths are relative to
function PTrackSeeker:new(track, startingNode)
	PTrackSeeker.super.new(self)

	local solvedNode, err = startingNode:getNodeFromPath(track.nodePath, true, true)
	if solvedNode == nil then
		error(err)
	end

	local property = solvedNode:getClassDBEntry():getProperty(track.propertyName, true)
	if not property then
		error(("Property '%s' does not exist on '%s' of type '%s'"):format(track.propertyName, solvedNode, solvedNode.CLASS_NAME))
	end
	---@cast property Property

	---@type PropertyTrack
	self.track = track
	---@type Node
	self.node = solvedNode
	---@type string
	self.propertyName = track.propertyName
	---@type Property
	self.property = property

	---@type number # What time this Seeker is at
	self.elapsed = 0

	---@type integer # The index of the lower KeyFrame
	self.lowerIndex = 1

	---@type any # In between KeyFrames, what's the value of the frame that is earlier
	self.lowerValue = (track.keyframes[1] and track.keyframes[1].value) or property:get(solvedNode, track.propertyName)
	---@type any # In between KeyFrames, what's the value of the frame that is later
	self.upperValue = self.lowerValue

	---@type number
	self.lowerTime = 0
	---@type number
	self.upperTime = 0
end

---@param self PropertyTrack.Seeker
local function postSeek(self)
	local lower, upper = self.lowerValue, self.upperValue
	local lowerTime, upperTime = self.lowerTime, self.upperTime
	local property = self.property
	if self.track.valueMode == "continuous" then
		-- Lerp
		local elapsed = self.elapsed
		local difference = upperTime - lowerTime
		local progress = ((elapsed - lowerTime) / difference)
		local newValue = property:lerp(lower, upper, progress)
		property:set(self.node, self.propertyName, newValue)
	else
		-- No lerping; just set the values
		property:set(self.node, self.propertyName,
			(self.elapsed >= upperTime and upper) or lower
		)
	end
end

---Seeks the animation to a specific time in the range [0, duration]
---@param time number
function PTrackSeeker:seek(time)
	local track = self.track
	local duration = track.sourceAnimation.duration
	time = max(0, min(time, duration))
	local lowerFrame, upperFrame, lowerIndex, _ = track:getKeyframePairs(time)
	local property, propertyName, node =
		self.property, self.propertyName, self.node

	self.elapsed = time
	if lowerFrame then
		---@cast lowerIndex integer
		self.lowerIndex = lowerIndex
		self.lowerTime, self.lowerValue =
			lowerFrame.time, lowerFrame.value
	else
		self.lowerIndex = 1
		self.lowerTime, self.lowerValue =
			0, property:get(node, propertyName)
	end

	if upperFrame then
		self.upperTime, self.upperValue =
			upperFrame.time, upperFrame.value
	else
		self.upperTime, self.upperValue =
			duration, property:get(node, propertyName)
	end

	postSeek(self)
end

---Seeks to the beginning of the track
function PTrackSeeker:seekToBeginning()
	self.elapsed = 0
	local lowerFrame, upperFrame, lowerIndex, _ = self.track:getKeyframePairs(0)
	if not upperFrame then return end

	if lowerFrame then
		---@cast lowerIndex integer
		self.lowerIndex = lowerIndex
		self.lowerTime, self.lowerValue =
			lowerFrame.time, lowerFrame.value
	else
		self.lowerIndex = 1
		self.lowerTime, self.lowerValue =
			0, self.property:get(self.node, self.propertyName)
	end

	self.upperTime, self.upperValue =
		upperFrame.time, upperFrame.value
	postSeek(self)
end

---Seeks to the end of the track
function PTrackSeeker:seekToEnd()
	local track = self.track
	local duration = track.sourceAnimation.duration
	self.elapsed = duration
	local lowerFrame, upperFrame, lowerIndex, _ = track:getKeyframePairsBackwards(duration)
	if not lowerFrame then return end

	if upperFrame then
		self.upperTime, self.upperValue =
			upperFrame.time, upperFrame.value
	else
		self.upperTime, self.upperValue =
			duration, self.property:get(self.node, self.propertyName)
	end

	---@cast lowerIndex integer
	self.lowerIndex = lowerIndex
	self.lowerTime, self.lowerValue =
		lowerFrame.time, lowerFrame.value
	postSeek(self)
end

---Steps the TrackSeeker a certain amount forwards
---@param amount number # Positive number
function PTrackSeeker:stepForwards(amount)
	self.elapsed = self.elapsed + amount
	-- TODO: Fix high speed animations acting weird

	if self.elapsed > self.upperTime then
		-- Just passed this KeyFrame
		local track = self.track
		local duration = track.sourceAnimation.duration
		local looping = track.sourceAnimation.loop
		---@type boolean # Whether we looped in this step
		local justLooped = false
		if self.elapsed > duration then
			if looping then
				-- Loop
				self.elapsed = self.elapsed % duration
				self.lowerIndex = 1
				justLooped = true
			else
				-- Don't loop
				local property = self.property
				local node = self.node
				local propertyName = self.propertyName
				self.elapsed = duration
				property:set(node, propertyName, self.upperValue)
				return
			end
		end

		local lowerFrame, upperFrame, lowerIndex, _ = track:getKeyframePairs(self.elapsed, self.lowerIndex)

		if not lowerFrame then
			if justLooped then
				-- Just looped to the beginning, and the first KeyFrame doesn't exist
				-- so we do it relative to the former KeyFrame (at the end of the last animation)
				lowerIndex = 1
				lowerFrame = track.keyframes[#track.keyframes]

				if not lowerFrame then return end
			end
		end

		---@cast lowerFrame PropertyTrack.KeyFrame
		---@cast upperFrame PropertyTrack.KeyFrame

		if lowerFrame then
			self.lowerValue = lowerFrame.value
			if justLooped then
				self.lowerIndex = 1
				self.lowerTime = 0
			else
				---@cast lowerIndex integer
				self.lowerIndex = lowerIndex
				self.lowerTime = lowerFrame.time
			end
		else
			self.lowerIndex = 1
			self.lowerTime, self.lowerValue =
				0, self.property:get(self.node, self.propertyName)
		end

		if upperFrame then
			self.upperTime, self.upperValue =
				upperFrame.time, upperFrame.value
		else
			self.upperTime = duration
			if not looping then
				self.upperValue = self.lowerValue
			else
				local firstFrame = track.keyframes[1]
				self.upperValue = (firstFrame and firstFrame.value) or self.lowerValue
			end
		end
	end

	postSeek(self)
end

---Steps a certain amount backwards, with `amount` being a *positive* number
---@param amount number # Positive number
function PTrackSeeker:stepBackwards(amount)
	self.elapsed = self.elapsed - amount

	if self.elapsed < self.lowerTime then
		-- Just passed this KeyFrame
		local track = self.track
		local duration = track.sourceAnimation.duration
		local looping = track.sourceAnimation.loop
		---@type boolean # Whether we looped in this step
		local justLooped = false
		if self.elapsed < 0 then
			if looping then
				-- Loop
				self.lowerIndex = #track.keyframes
				self.elapsed = self.elapsed % duration
				justLooped = true
			else
				-- Don't loop
				local property = self.property
				local node = self.node
				local propertyName = self.propertyName
				self.elapsed = 0
				property:set(node, propertyName, self.lowerValue)
				return
			end
		end

		local lowerFrame, upperFrame, lowerIndex, _ = track:getKeyframePairsBackwards(self.elapsed, self.lowerIndex)

		if not upperFrame then
			if justLooped then
				upperFrame = track.keyframes[1]
			end
		end

		---@cast lowerFrame PropertyTrack.KeyFrame
		---@cast upperFrame PropertyTrack.KeyFrame

		if lowerFrame then
			---@cast lowerIndex integer
			self.lowerIndex = lowerIndex
			self.lowerTime, self.lowerValue =
				lowerFrame.time, lowerFrame.value
		else
			lowerIndex = #track.keyframes
			lowerFrame = track.keyframes[lowerIndex]

			if not lowerFrame then return end

			self.lowerTime, self.lowerTime =
				0, lowerFrame.value
		end

		if upperFrame then
			self.upperValue = upperFrame.value
			if justLooped then
				self.upperTime = duration
			else
				self.upperTime = upperFrame.time
			end
		else
			self.upperTime, self.upperValue =
				0, self.property:get(self.node, self.propertyName)
		end
	end

	postSeek(self)
end

---Steps the animation forwards or backwards, depending on the sign of `amount`.
---`amount` can be positive or negative.
---@param amount number
function PTrackSeeker:step(amount)
	if amount > 0 then
		self:stepForwards(amount)
	elseif amount < 0 then
		self:stepBackwards(-amount)
	end
end

return PTrackSeeker
