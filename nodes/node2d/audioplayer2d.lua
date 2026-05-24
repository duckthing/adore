---@type AdoreInit
local Adore = require ""
local Nodes = Adore.Nodes
local Node2d = Nodes("Node2d")
local AudioPlayer = Nodes("AudioPlayer")
local sin, cos = math.sin, math.cos

---@class AudioPlayer2d: Node2d, AudioPlayer
---@field super Node2d
---@overload fun(x: number?, y: number?, source: love.Source?): AudioPlayer2d
local AudioPlayer2d = Node2d:extend()
AudioPlayer2d.CLASS_NAME = "AudioPlayer2d"

---@param x number?
---@param y number?
---@param source love.Source?
function AudioPlayer2d:new(x, y, source)
	AudioPlayer2d.super.new(self, x, y)
	AudioPlayer._initAudioPlayer(self, source)

	---@type boolean # Whether we should use the rotation of the AudioPlayer2d
	self._useRotation = false
	---@type boolean # Whether polyphony sources should keep their start position or keep updating
	self._polyKeepPosition = true
	---@type number # The Z position of the source
	self._sourceZ = 0
end

AudioPlayer2d._createPolyphonyArray = AudioPlayer._createPolyphonyArray
AudioPlayer2d.setSource = AudioPlayer.setSource
AudioPlayer2d.setPolyphony = AudioPlayer.setPolyphony
AudioPlayer2d.play = AudioPlayer.play
AudioPlayer2d.pause = AudioPlayer.pause
AudioPlayer2d.seek = AudioPlayer.seek
AudioPlayer2d.stop = AudioPlayer.stop
AudioPlayer2d.clone = AudioPlayer.clone

function AudioPlayer2d:_onGlobalTransformChanged()
	AudioPlayer2d.super._onGlobalTransformChanged(self)

	if not self._source then return end

	local x, y = self:getPosition(true)
	local z = self._sourceZ

	-- The direction vector
	local dx, dy = 1, 0
	if self._useRotation then
		local rotation = self:getRotation(true)
		dx, dy = cos(rotation), sin(rotation)
	end

	if self._maxPolyphony == 1 then
		-- One source, set its position
		local source = self._source
		---@cast source love.Source
		source:setPosition(x, y, z)
		source:setDirection(dx, dy, 0)
	elseif self._polySources then
		if self._polyKeepPosition then
			-- Update the next source's position
			local source = self._polySources[self._polyIndex]
			source:setPosition(x, y, z)
			source:setDirection(dx, dy, 0)
		else
			-- Update all source positions
			local arr = self._polySources
			---@cast arr love.Source[]
			for i = 1, self._maxPolyphony do
				local source = arr[i]
				source:setPosition(x, y, z)
				source:setDirection(dx, dy, 0)
			end
		end
	end
end

function AudioPlayer2d:update(dt)
	AudioPlayer.super.update(self, dt)
	local num = love.math.random(0, 10)
	if num == 1 then
		self:play()
	end
end

function AudioPlayer2d:forceDestroy(...)
	self._source:release()
	if self._polySources then
		local arr = self._polySources
		for i = self._maxPolyphony, 1, -1 do
			arr[i]:release()
			arr[i] = nil
		end
		self._polySources = nil
	end
	AudioPlayer.super.forceDestroy(self, ...)
end

return AudioPlayer2d
