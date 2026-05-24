---@type AdoreInit
local Adore = require ""
local Node2d = Adore.Nodes("Node2d")
local LoveAudio = love.audio
local sin, cos = math.sin, math.cos

---@class AudioListener2d: Node2d
---@field super Node2d
---@overload fun(x: number?, y: number?, current: boolean?): AudioListener2d
local AudioListener2d = Node2d:extend()
AudioListener2d.CLASS_NAME = "AudioListener2d"

function AudioListener2d:new(x, y, current)
	AudioListener2d.super.new(self, x, y)

	---@type boolean? # Whether this AudioListener2d is the active listener
	self._current = current or false
	---@type boolean? # Whether this AudioListener2d should use its current rotation
	self._useRotation = true

	---@type number # The Z position of the listener
	self._listenerZ = 0

	if current then
		self:makeCurrent()
	end
end

---@param self AudioListener2d
local function setPosition(self)
	local x, y = self:getPosition(true)
	love.audio.setPosition(x, y, self._listenerZ)
	if self._useRotation then
		-- Forward axis stays the same
		-- Rotate the up axis instead
		local rotation = self:getRotation(true)
		love.audio.setOrientation(
			0, 0, 1,
			sin(rotation), -cos(rotation), 0
		)
	else
		-- In Love2d, Y is negative, and X is positive
		-- We assume the Z axis is going into the screen from the viewer
		love.audio.setOrientation(
			0, 0, 1,
			0, -1, 0
		)
	end
end

function AudioListener2d:_onGlobalTransformChanged()
	AudioListener2d.super._onGlobalTransformChanged(self)
	if self._current then
		setPosition(self)
	end
end

---Makes this AudioListener2d current
function AudioListener2d:makeCurrent()
	local root = self:getRoot()
	local otherAudio = root._activeAudioListener

	if otherAudio then
		otherAudio._current = false
	end

	root._activeAudioListener = self
	self._current = true
	setPosition(self)
end

function AudioListener2d:onAddedToTree()
	AudioListener2d.super.onAddedToTree(self)
	local root = self:getRoot()
	if not root._activeAudioListener then
		-- No existing audio listener, assume this one will be current
		self:makeCurrent()
	end
end

function AudioListener2d:onRemovedFromTree()
	AudioListener2d.super.onRemovedFromTree(self)
	if self._current then
		self:getRoot()._activeAudioListener = nil
		self._current = false
	end
end

return AudioListener2d
