---@type AdoreInit
local Adore = require ""
local Node2d = Adore.Nodes("Node2d")
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
		self:setCurrent(true)
	end
end

---@param self AudioListener2d
local function setPosition(self)
	local x, y = self:getWorldPosition()
	love.audio.setPosition(x, y, self._listenerZ)
	if self._useRotation then
		-- Forward axis stays the same
		-- Rotate the up axis instead
		local rotation = self:getWorldRotation()
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

---Sets whether this AudioListener2d is active
---@generic T: AudioListener2d
---@param self T | AudioListener2d
---@param current boolean
---@return T
function AudioListener2d:setCurrent(current)
	if self._current ~= current then
		local root = self:getRoot()
		if current then
			-- Activate
			local otherAudio = root._activeAudioListener

			if otherAudio then
				otherAudio._current = false
			end

			root._activeAudioListener = self
			self._current = true
			setPosition(self)
		else
			-- Deactivate
			root._activeAudioListener = nil
			self._current = false
		end
	end
	return self
end

---Sets whether rotation on this AudioListener2d rotates the audio listener
---@generic T: AudioListener2d
---@param self T | AudioListener2d
---@param useRot boolean
---@return T
function AudioListener2d:setUseRotation(useRot)
	if self._useRotation ~= useRot then
		self._useRotation = useRot
		if self._current then
			setPosition(self)
		end
	end
	return self
end

---Sets where the listener is on the Z axis
---@generic T: AudioListener2d
---@param self T | AudioListener2d
---@param zPosition number
---@return T
function AudioListener2d:setListenerZ(zPosition)
	if self._listenerZ ~= zPosition then
		self._listenerZ = zPosition
		if self._current then
			setPosition(self)
		end
	end
	return self
end

function AudioListener2d:onAddedToTree()
	AudioListener2d.super.onAddedToTree(self)
	local root = self:getRoot()
	if not root._activeAudioListener then
		-- No existing audio listener, assume this one will be current
		self:setCurrent(true)
	end
end

function AudioListener2d:onRemovedFromTree()
	AudioListener2d.super.onRemovedFromTree(self)
	if self._current then
		self:getRoot()._activeAudioListener = nil
		self._current = false
	end
end

function AudioListener2d._addDefinition(entry)
	entry:newBoolean("_current", false, "setCurrent")
	entry:newBoolean("_current", true, "setUseRotation")
	entry:newNumber("_listenerZ", 0, nil, nil, nil, "setListenerZ")
end

return AudioListener2d
