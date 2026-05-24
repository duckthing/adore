---@type AdoreInit
local Adore = require ""
local Node2d = Adore.Nodes("Node2d")

---`Particles2d` moves and updates a `love.ParticleSystem` along with its `Node2d` transform. It overwrites the original
---direction with its own, with a rotation of `0` emitting to the right `(X+, 0)`.
---@class Particles2d: Node2d
---@field super Node2d
---@overload fun(x: number?, y: number?, system: love.ParticleSystem?, global: boolean?, autostart: boolean?): Particles2d
local Particles2d = Node2d:extend()
Particles2d.CLASS_NAME = "Particles2d"

function Particles2d:extend(x, y, system, global, autostart)
	Particles2d.super.new(self, x, y)

	---@type love.ParticleSystem?
	self.particleSystem = nil
	---@type number # The update amount is based off of the delta time received and this value
	self.particleSpeed = 1
	---@type boolean # Whether the particles should start emitting when ready/changed
	self.autostart = autostart or false

	---@type boolean # Whether the particles are based in global space; make `true` to make particles stay where they were emitted
	self._globalParticles = global or true

	self:setParticleSystem(system)
end

---Sets the ParticleSystem used.
---If you're putting the ParticleSystem into multiple Nodes, don't forget to call `:clone()` on the ParticleSystems.
---@param system love.ParticleSystem?
---@return Particles2d
function Particles2d:setParticleSystem(system)
	if self.particleSystem ~= system then
		self.particleSystem = system

		if system then
			if self._globalParticles then
				local x, y, angle = self:getWorldPositionAndRotation()
				system:setPosition(x, y)
				system:setDirection(angle)
			else
				system:setPosition(0, 0)
				system:setDirection(0)
			end

			if self._ready and self.autostart then
				system:start()
			end
		end
	end

	return self
end

---Sets whether the particles are positioned based on where they were emitted in global space.
---`true` makes the particles linger where they were originally emitted, while `false` makes them move with the Node2D's
---transform.
---@param global boolean
---@return Particles2d
function Particles2d:setGlobalParticles(global)
	if self._globalParticles ~= global then
		self._globalParticles = global

		local system = self.particleSystem
		if system then
			if global then
				local x, y, angle = self:getWorldPositionAndRotation()
				system:setPosition(x, y)
				system:setDirection(angle)
			else
				system:setPosition(0, 0)
				system:setDirection(0)
			end
		end
	end

	return self
end

---Sets the speed the ParticleSystem will be processed.
---@param speed number?
---@return self
function Particles2d:setSpeed(speed)
	self.particleSpeed = speed or 1
	return self
end

---Sets whether the ParticleSystem will get started immediately (upon `:ready()` or system change).
---@param autostart boolean?
---@return Particles2d
function Particles2d:setAutostart(autostart)
	if self.autostart ~= autostart then
		self.autostart = autostart or false
	end
	return self
end

function Particles2d:_onGlobalTransformChanged()
	Particles2d.super._onGlobalTransformChanged(self)
	local system = self.particleSystem
	if system then
		if self._globalParticles then
			local x, y, angle = self:getWorldPositionAndRotation()
			system:moveTo(x, y)
			system:setDirection(angle)
		end
	end
end

---Calls `:emit(amount)` on the ParticleSystem
---@param amount integer
function Particles2d:emitParticles(amount)
	local system = self.particleSystem
	if system then system:emit(amount) end
end

---Calls `:start()` on the ParticleSystem
function Particles2d:start()
	local system = self.particleSystem
	if system then system:start() end
end

---Calls `:stop()` on the ParticleSystem
function Particles2d:stop()
	local system = self.particleSystem
	if system then system:stop() end
end

---Calls `:pause()` on the ParticleSystem
function Particles2d:pause()
	local system = self.particleSystem
	if system then system:pause() end
end

---Calls `:reset()` on the ParticleSystem
function Particles2d:reset()
	local system = self.particleSystem
	if system then system:reset() end
end

function Particles2d:draw()
	local system = self.particleSystem
	if system then
		if self._globalParticles then
			-- Particles are drawn based on their original position
			love.graphics.push("transform")
			love.graphics.origin()
			love.graphics.draw(system, 0, 0, self:getRotation(true))
			love.graphics.pop()
		else
			-- Particles are drawn relative to this node's transform
			love.graphics.draw(system)
		end
	end
end

function Particles2d:update(dt)
	local system = self.particleSystem
	if system then
		system:update(dt * self.particleSpeed)
	end
end

return Particles2d
