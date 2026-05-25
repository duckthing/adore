---@type AdoreInit
local Adore = require ""
local SimpleObject = Adore.Libraries("SimpleObject")
local floor  = math.floor
local min, max = math.min, math.max

---@class MethodTrack.Seeker: SimpleObject
---@overload fun(track: MethodTrack, startingNode: Node): MethodTrack.Seeker
local MTrackSeeker = SimpleObject:extend()
MTrackSeeker.CLASS_NAME = "MethodTrackSeeker"

local MAX_LOOPS = 5

---@param track MethodTrack
---@param startingNode Node # Where NodePaths are relative to
function MTrackSeeker:new(track, startingNode)
	MTrackSeeker.super.new(self)

	local solvedNode, err = startingNode:getNodeFromPath(track.nodePath, true, true)
	if solvedNode == nil then
		error(err)
	end

	---@type MethodTrack
	self.track = track
	---@type Node
	self.node = solvedNode

	---@type number # What time this Seeker is at
	self.elapsed = 0

	---@type integer # The index of the lower KeyFrame
	self.lowerIndex = 1

	---@type MethodTrack.KeyFrame?
	self.lowerFrame = nil
	---@type MethodTrack.KeyFrame?
	self.upperFrame = nil

	---@type number
	self.lowerTime = 0
	---@type number
	self.upperTime = 0
end

---@param self MethodTrack.Seeker
local function postSeek(self)
end

---Seeks the animation to a specific time in the range [0, duration]
---@param time number
function MTrackSeeker:seek(time)
	local track = self.track
	local duration = track.sourceAnimation.duration
	time = max(0, min(time, duration))
	self.elapsed = time
	local lowerFrame, upperFrame, lowerIndex, _ = track:getKeyframePairs(time)

	if lowerFrame then
		---@cast lowerIndex integer
		self.lowerIndex = lowerIndex
		self.lowerTime, self.lowerFrame =
			lowerFrame.time, lowerFrame
	else
		self.lowerIndex = 1
		self.lowerTime, self.lowerFrame =
			0, upperFrame
	end

	if upperFrame then
		self.upperTime, self.upperFrame =
			upperFrame.time, upperFrame
	else
		self.upperTime, self.upperFrame =
			duration, lowerFrame
	end
end

---Seeks to the beginning of the track
function MTrackSeeker:seekToBeginning()
	self.elapsed = 0
	local lowerFrame, upperFrame, lowerIndex, _ = self.track:getKeyframePairs(0)
	if not upperFrame then return end

	if lowerFrame then
		---@cast lowerIndex integer
		self.lowerIndex = lowerIndex
		self.lowerTime, self.lowerFrame =
			lowerFrame.time, lowerFrame
	else
		self.lowerIndex = 1
		self.lowerTime, self.lowerFrame =
			0, upperFrame
	end

	self.upperTime, self.upperFrame =
		upperFrame.time, upperFrame
	postSeek(self)
end

---Seeks to the end of the track
function MTrackSeeker:seekToEnd()
	local track = self.track
	local duration = track.sourceAnimation.duration
	self.elapsed = duration
	local lowerFrame, upperFrame = track:getKeyframePairsBackwards(duration)
	if not lowerFrame then return end

	if upperFrame then
		self.upperTime, self.upperFrame =
			upperFrame.time, upperFrame
	else
		self.upperTime, self.upperFrame =
			duration, lowerFrame
	end

	self.lowerTime, self.lowerFrame =
		lowerFrame.time, lowerFrame
	postSeek(self)
end

---Steps the TrackSeeker a certain amount forwards
---@param amount number # Positive number
function MTrackSeeker:stepForwards(amount)
	self.elapsed = self.elapsed + amount

	if self.elapsed > self.upperTime then
		-- Just passed this KeyFrame
		local track = self.track
		local node = self.node
		local duration = track.sourceAnimation.duration
		local looping = track.sourceAnimation.loop
		---@type boolean # Whether we looped in this step
		local justLooped = false
		track:callForwards(node, self.upperTime, self.elapsed, self.lowerIndex)
		--TODO: Check if elapsed equalling `upperTime` causes odd behavior

		if self.elapsed > duration then
			if looping then
				-- Not 'loops', more like 'total times we passed the end point'
				-- If we passed the end point more than once in a single update...
				-- ...we simulate that by calling everything inside of the track.
				local loops = floor(self.elapsed / duration)
				self.elapsed = self.elapsed - duration * loops

				if loops >= MAX_LOOPS then
					print(("[Adore.MethodTrackSeeker] Looped %d times in one update; clamped to %d"):format(loops, MAX_LOOPS))
					loops = MAX_LOOPS + 1
				end

				for _ = 2, loops do
					-- Call all methods in the track `loops - 1` times
					track:callAllForwards(node)
				end

				track:callForwards(node, 0, self.elapsed)
				justLooped = true
				self.lowerIndex = 1
			else
				-- Don't loop
				self.elapsed = duration
				return
			end
		end

		local lowerFrame, upperFrame, lowerIndex, _ = track:getKeyframePairs(self.elapsed, self.lowerIndex)

		if not lowerFrame then
			if justLooped then
				-- Just looped to the beginning, and the first KeyFrame doesn't exist
				-- so we do it relative to the former KeyFrame (at the end of the last animation)
				lowerIndex = 1
				lowerFrame = self.upperFrame

				if not lowerFrame then return end
			end
		end

		---@cast lowerFrame MethodTrack.KeyFrame
		---@cast upperFrame MethodTrack.KeyFrame

		if lowerFrame then
			self.lowerFrame = lowerFrame or self.upperFrame
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
			self.lowerTime, self.lowerFrame =
				0, nil
		end

		if upperFrame then
			self.upperTime, self.upperFrame =
				upperFrame.time, upperFrame
		else
			self.upperTime = duration
			if not looping then
				self.upperFrame = self.lowerFrame
			else
				local firstFrame = track.keyframes[1]
				self.upperFrame = firstFrame or self.lowerFrame
			end
		end
	end
end

---Steps a certain amount backwards, with `amount` being a *positive* number
---@param amount number # Positive number
function MTrackSeeker:stepBackwards(amount)
	self.elapsed = self.elapsed - amount
	self.lowerIndex = nil

	if self.elapsed < self.lowerTime then
		-- Just passed this KeyFrame
		local track = self.track
		local duration = track.sourceAnimation.duration
		local looping = track.sourceAnimation.loop
		local node = self.node

		---@type boolean # Whether we looped in this step
		local justLooped = false
		track:callBackwards(node, self.lowerTime, self.elapsed, self.lowerIndex)

		if self.elapsed < 0 then
			if looping then
				-- Loop
				local loops = -floor(self.elapsed / duration)
				self.elapsed = self.elapsed + duration * loops

				if loops >= MAX_LOOPS then
					print(("[Adore.MethodTrackSeeker] Looped %d times in one update; clamped to %d"):format(loops, MAX_LOOPS))
					loops = MAX_LOOPS + 1
				end

				for _ = 2, loops do
					-- Call all methods in the track `loops - 1` times
					track:callAllBackwards(node)
				end

				track:callBackwards(node, duration, self.elapsed)
				justLooped = true
				self.lowerIndex = #self.track.keyframes
			else
				-- Don't loop
				self.elapsed = 0
				return
			end
		end

		local lowerFrame, upperFrame, lowerIndex, _ = track:getKeyframePairsBackwards(self.elapsed, self.lowerIndex)

		if not upperFrame then
			if justLooped then
				upperFrame = track.keyframes[1]
			end
		end

		---@cast lowerFrame MethodTrack.KeyFrame
		---@cast upperFrame MethodTrack.KeyFrame

		if lowerFrame then
			---@cast lowerIndex integer
			self.lowerIndex = lowerIndex
			self.lowerTime, self.lowerFrame =
				lowerFrame.time, lowerFrame
		else
			lowerIndex = #track.keyframes
			lowerFrame = track.keyframes[lowerIndex]

			if not lowerFrame then return end

			self.lowerTime, self.lowerFrame =
				0, lowerFrame
		end

		self.upperFrame = upperFrame
		if justLooped then
			self.upperTime = duration
		else
			self.upperTime = upperFrame.time
		end
	end

	postSeek(self)
end

---Steps the animation forwards or backwards, depending on the sign of `amount`.
---`amount` can be positive or negative.
---@param amount number
function MTrackSeeker:step(amount)
	if amount > 0 then
		self:stepForwards(amount)
	elseif amount < 0 then
		self:stepBackwards(-amount)
	end
end

return MTrackSeeker
