---@type AdoreInit
local Adore = require ""
local Node = Adore.Nodes("Node")
local max = math.max

---@class AudioPlayer: Node
---@field super Node
---@overload fun(source: love.Source?): AudioPlayer
local AudioPlayer = Node:extend()
AudioPlayer.CLASS_NAME = "AudioPlayer"

---@param source love.Source?
function AudioPlayer:new(source)
	AudioPlayer.super.new(self)

	self:_initAudioPlayer(source)
end

---Initializes all AudioPlayer variables
---@param source love.Source?
function AudioPlayer:_initAudioPlayer(source)
	---@type love.Source?
	self._source = nil
	if source and source:getType() == "static" then
		self._source = source:clone()
	end

	---@type integer # When calling :play() repeatedly, should new sounds be played?
	self._maxPolyphony = 1

	---@type integer # The current polyphony index we're on
	self._polyIndex = 1
	---@type love.Source[]?
	self._polySources = nil
end

---Creates the polyphony array or destroys it
---@param self AudioPlayer
local function createPolyphonyArray(self)
	local amount = self._maxPolyphony
	if amount == 1 or not self._source then
		self._polySources = nil
	else
		local source = self._source
		---@cast source love.Source

		local arr = self._polySources
		if arr then
			-- Clear the existing array
			for i = #arr, 1, -1 do
				arr[i] = nil
			end
		else
			arr = {}
		end

		for i = 1, amount do
			arr[i] = source:clone()
		end
		self._polySources = arr
		self._polyIndex = 1
	end
end

---Internal; you may call this if the source parameters have changed
function AudioPlayer:_createPolyphonyArray()
	createPolyphonyArray(self)
end

---Sets the Source
---@param source love.Source
---@return self
function AudioPlayer:setSource(source)
	if source ~= self._source then
		local oldSource = self._source
		if oldSource then
			oldSource:stop()
		end

		self._source = source

		if source and self._maxPolyphony > 1 then
			-- Creates the polyphone array
			local amount = self._maxPolyphony
			self._maxPolyphony = 1
			self:setPolyphony(amount)
		end
	end

	return self
end

---Whether duplicate calls to `:play()` should overlap new sounds instead of restarting
---@param amount integer
---@return self
function AudioPlayer:setPolyphony(amount)
	amount = (amount and max(amount, 1)) or 1
	if amount ~= self._polyIndex then
		self._maxPolyphony = amount
		createPolyphonyArray(self)
	end

	return self
end

---Plays the Source
---@return self
function AudioPlayer:play()
	if self._polySources then
		-- Use the polyphony
		local index = self._polyIndex
		local arr = self._polySources
		if arr then
			arr[index]:play()
			index = index + 1
			if index >= self._maxPolyphony then
				index = 1
			end
			self._polyIndex = index
		end
	else
		-- Use the source
		self._source:play()
	end
	return self
end

---Pauses the Source
---@return self
function AudioPlayer:pause()
	if self._polySources then
		-- Use the polyphony
		local arr = self._polySources
		if arr then
			for i = 1, self._maxPolyphony do
				arr[i]:pause()
			end
		end
	elseif self._source then
		-- Use the source
		self._source:pause()
	end
	return self
end

---Stops the Source
---@return self
function AudioPlayer:stop()
	if self._polySources then
		-- Use the polyphony
		local arr = self._polySources
		if arr then
			for i = 1, self._maxPolyphony do
				arr[i]:stop()
			end
			self._polyIndex = 1
		end
	elseif self._source then
		-- Use the source
		self._source:stop()
	end
	return self
end

---Seeks the Source to the specified position
---@param offset number
---@param unit love.TimeUnit?
---@return self
function AudioPlayer:seek(offset, unit)
	if self._polySources then
		-- Use the polyphony
		-- (Next audio played will be at this position)
		self._polySources[self._polyIndex]:seek(offset, unit)
	elseif self._source then
		-- Use the source
		self._source:seek(offset, unit)
	end
	return self
end

---Clones this AudioPlayer and the source, and returns it
---@return AudioPlayer
function AudioPlayer:clone()
	local newSource = (self._source and self._source:clone())
	return AudioPlayer(newSource):setPolyphony(self._maxPolyphony)
end

function AudioPlayer:forceDestroy(...)
	self._source:release()
	local polySources = self._polySources
	if polySources then
		for i = self._maxPolyphony, 1, -1 do
			polySources[i]:release()
			polySources[i] = nil
		end
		self._polySources = nil
	end
	AudioPlayer.super.forceDestroy(self, ...)
end

return AudioPlayer
