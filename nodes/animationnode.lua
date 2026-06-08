---@type AdoreInit
local Adore = require ""
local Node = Adore.Nodes("Node")
local min, max = math.min, math.max

---@class AnimationNode: Node
---@field super Node
---@overload fun(library: Animation.Library?, defaultAnimationName: string?, autostart: boolean?): AnimationNode
local AnimationNode = Node:extend()
AnimationNode.CLASS_NAME = "AnimationNode"

---@param library Animation.Library?
---@param defaultAnimationName string?
---@param autostart boolean?
function AnimationNode:new(library, defaultAnimationName, autostart)
	AnimationNode.super.new(self)

	---@type Animation.Library?
	self._library = library
	---@type string?
	self._currAnimationName = nil
	---@type Animation?
	self._currAnimation = nil
	---@type boolean
	self.autostart = autostart or false

	---@type number
	self._elapsed = 0
	---@type number # What will get passed
	self.speed = 1
	---@type boolean
	self._playing = false
	---@type boolean
	self._paused = false

	---@type {[string]: (PropertyTrack.Seeker | MethodTrack.Seeker)[]}
	self._allSeekers = {}
	---@type (PropertyTrack.Seeker | MethodTrack.Seeker)[]?
	self._currSeekers = nil

	---@type string? # When autostarting, what will be the Animation that plays?
	self._autostartAnimation = defaultAnimationName
end

function AnimationNode:ready()
	AnimationNode.super.ready(self)
	if self.autostart and self._autostartAnimation then
		self:setAnimation(self._autostartAnimation)
		self:play()
	else
		local currAnimationName = self._currAnimationName
		if currAnimationName then
			self._currAnimationName = nil
			self:setAnimation(currAnimationName)
		end
	end
end

---@param self AnimationNode
---@param name string
---@param animation Animation
local function useSeekers(self, name, animation)
	local seekerArr = self._allSeekers[name]
	if not seekerArr then
		seekerArr = {}
		local tracks = animation.tracks

		for i = 1, #tracks do
			local seeker = tracks[i]:newSeeker(self)
			seekerArr[i] = seeker
		end

		self._allSeekers[name] = seekerArr
	end
	self._currSeekers = seekerArr
end

---Changes the current Animation to a different one.
---* If the new Animation is different:
--- * It stops the previous one and plays the new one from the beginning if `keepElapsed` is `false`
--- * ...or plays from the same elapsed time position if `keepElapsed` is `true`
---* If the new Animation is the same:
--- * It restarts the Animation from the beginning if `keepElapsed` is `false`
--- * ...or continues playing as if nothing changed if `keepElapsed` is `true`
---@param name string
---@param keepElapsed boolean? # If the new Animation should start at the previous elapsed time; good for walking animations.
---@return AnimationNode self
function AnimationNode:setAnimation(name, keepElapsed)
	if not self._ready then
		self._currAnimationName = name
		return self
	end
	local library = self._library
	assert(library, "Library doesn't exist on AnimationNode")
	local animation = library.animations[name]
	if not animation then
		error(("Animation '%s' doesn't exist in library '%s'"):format(name, library.name or "nil"))
	end

	if self._currAnimation == animation then
		local seekers = self._currSeekers
		if not keepElapsed and seekers then
			-- Restart from the beginning
			self._elapsed = 0
			for i = 1, #seekers do
				seekers[i]:seekToBeginning()
			end
		end
		return self
	end

	-- From this point, the Animation is different
	if keepElapsed then
		-- Make sure the elapsed time is not out of bounds in the new Animation
		self._elapsed = self._elapsed % animation.duration
	else
		self._elapsed = 0
	end
	self._currAnimation = animation
	self._currAnimationName = name

	useSeekers(self, name, animation)
	local seekers = self._currSeekers

	if keepElapsed then
		local elapsed = self._elapsed
		for i = 1, #seekers do
			seekers[i]:seek(elapsed)
		end
	else
		for i = 1, #seekers do
			seekers[i]:seekToBeginning()
		end
	end

	return self
end

---Sets the position of the Animation.
---@param time number
function AnimationNode:seek(time)
	local anim = self._currAnimation
	local seekers = self._currSeekers
	local duration = (anim and anim.duration) or 0

	if time <= 0 or not anim or not seekers then
		self._elapsed = 0
		if seekers then
			for i = 1, #seekers do
				seekers[i]:seekToBeginning()
			end
		end
	elseif time >= duration then
		self._elapsed = duration
		for i = 1, #seekers do
			seekers[i]:seekToEnd()
		end
	else
		self._elapsed = time
		for i = 1, #seekers do
			seekers[i]:seek(time)
		end
	end
end

---Seeks to the beginning of the Animation
function AnimationNode:seekToBeginning() self:seek(0) end
---Seeks to the eng of the Animation, if there's one set
function AnimationNode:seekToEnd() self:seek((self._currAnimation and self._currAnimation.duration) or 0) end

---Starts the Animation from a beginning point, if it wasn't running already.
---* If `speed` is positive or 0, plays from the beginning
---* Otherwise, plays from the end
function AnimationNode:play()
	if self._playing then return end
	self._playing = true
	self._paused = false

	if self.speed >= 0 then
		self:seekToBeginning()
	else
		self:seekToEnd()
	end
end

---Pauses the Animation, and allows it to continue running later
function AnimationNode:pause()
	if self._playing then
		self._paused = true
	end
end

---Resumes the Animation from where it left off (or starts it if it's already finished)
function AnimationNode:resume()
	if self._paused then
		-- Unpause
		self._paused = false
	else
		-- Fresh start
		self:play()
	end
end

---Stops the Animation, and discards its progress
function AnimationNode:stop()
	self._playing = false
	self._paused = false
	self._elapsed = 0
end

---Starts the Animation from the beginning
function AnimationNode:restart()
	self:stop()
	self:play()
end

---Sets the speed of the Animation. Negative values make the Animation run backwards.
---@param speed number
---@return AnimationNode
function AnimationNode:setSpeed(speed)
	self.speed = speed
	return self
end

---Steps the Animation by `amount * speed`.
---Does nothing if there is no Animation playing, and quits when the Animation is finished.
---@param amount number
function AnimationNode:step(amount)
	if self._paused then return end
	local animation = self._currAnimation
	if not animation then return end

	local duration = animation.duration
	local speed = self.speed
	local stepAmount = amount * speed
	self._elapsed = self._elapsed + stepAmount

	if speed == 0 then return end
	if not animation.loop then
		-- No loop, clamp to the bounds
		if speed > 0 then
			if self._elapsed >= duration then
				-- Speed is positive, elapsed is at the end of the Animation
				-- Finished
				self._elapsed = duration
				self._playing = false
				return
			end
		elseif speed < 0 then
			if self._elapsed <= 0 then
				-- Speed is negative, elapsed is at the start
				-- Finished in reverse
				self._elapsed = 0
				self._playing = false
				return
			end
		end
	else
		-- Looping, make sure elapsed is never outside (0..duration)
		self._elapsed = self._elapsed % duration
	end

	local seekers = self._currSeekers
	if speed > 0 then
		for i = 1, #seekers do
			seekers[i]:stepForwards(stepAmount)
		end
	else
		-- stepAmount must be positive when going backwards
		stepAmount = -stepAmount
		for i = 1, #seekers do
			seekers[i]:stepBackwards(stepAmount)
		end
	end
end

function AnimationNode:update(dt)
	if self._playing then
		self:step(dt)
	end
end

function AnimationNode._addDefinition(entry)
	entry:newObject("_library", "Animation.Library")
	entry:newString("_currAnimationName", nil, nil, nil, "setAnimation")
	entry:newBoolean("autostart", false)
	entry:newNumber("speed", 1, nil, nil, nil, "setSpeed")
	entry:newBoolean("_playing", false)
	entry:newBoolean("_paused", false)
	entry:newString("_autostartAnimation")
end

return AnimationNode
