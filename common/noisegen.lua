---@class NoiseGen
local NoiseGen = {}

---@type AdoreInit
local Adore = require ""
---@type ffilib?
local ffi
if pcall(require, "_G.jit") and require("_G.jit").status() then
	ffi = Adore.Common("ffilib")
end

local floor, cos, sin, PI2 =
	math.floor, math.cos, math.sin, math.pi * 2
local FACTOR_PI2 = 1 / PI2

-- Goes from [0..1]
local noise = love.math.noise

---An array of {valueMult, frequency, sumOfOctaves}, for each octave
local OCTAVE_VALS = {
	1, 1, 1,
	0.5, 2, 0.6666666666666666,
	0.25, 4, 0.5714285714285714,
	0.125, 8, 0.5333333333333333,
	0.0625, 16, 0.5161290322580645,
	0.03125, 32, 0.5079365079365079,
}

---@class Noise2d
---@field seed number
---@field frequency number
---@field octaves integer
---@field redistribution number
---@overload fun(x: number, y: number): number
local Noise2d = {}
local Noise2dMT = {
	__index = Noise2d,
	---@param self Noise2d
	__call = function(self, ...)
		return self.get(self, ...)
	end
}

---@param seed number?
---@param frequency number?
---@param octaves integer? # Whole numbers between 1 and 6
---@param redistribution number?
---@return Noise2d
function NoiseGen.new2d(seed, frequency, octaves, redistribution)
	local t = {
		seed = (seed or love.math.random()) * 2.90234 + 124.328,
		frequency = frequency or 1,
		octaves = octaves or 1,
		redistribution = redistribution or 1
	}
	return setmetatable(t, Noise2dMT)
end

local function noise2dGet(seed, frequency, octaves, redistribution, x, y)
	x, y =
		x * frequency,
		y * frequency

	local e = 0
	for i = 1, octaves do
		local avgMult = OCTAVE_VALS[i * 3 - 2]
		local subFreq = OCTAVE_VALS[i * 3 - 1]
		e = e + avgMult * noise(subFreq * x, subFreq * y, seed)
	end
	e = (e * OCTAVE_VALS[octaves * 3]) ^ redistribution

	return e
end

---Gets the value at a certain point, in the [0..1] range
---@param x number
---@param y number
---@return number value
function Noise2d:get(x, y)
	return noise2dGet(self.seed, self.frequency, self.octaves, self.redistribution, x, y)
end

local function noise2dGetXWrapped(seed, frequency, octaves, redistribution, x, y)
	y = y * frequency

	local e = 0
	local angleX = PI2 * x
	for i = 1, octaves do
		local avgMult = OCTAVE_VALS[i * 3 - 2]
		local subFreq = OCTAVE_VALS[i * 3 - 1]
		local mult = FACTOR_PI2 * frequency * subFreq
		-- TODO: Improve seeding on X/Y wrapped noise
		e = e + avgMult * noise(
			cos(angleX) * mult,
			sin(angleX) * mult,
			y * subFreq,
			seed
		)
	end
	e = (e * OCTAVE_VALS[octaves * 3]) ^ redistribution

	return e
end

---Gets the value at a certain point, in the [0..1] range, while wrapping every 1 X unit
---@param x number
---@param y number
---@return number value
function Noise2d:getXWrapped(x, y)
	return noise2dGetXWrapped(self.seed, self.frequency, self.octaves, self.redistribution, x, y)
end

local function noise2dGetYWrapped(seed, frequency, octaves, redistribution, x, y)
	x = x * frequency

	local e = 0
	local angleY = PI2 * y
	for i = 1, octaves do
		local avgMult = OCTAVE_VALS[i * 3 - 2]
		local subFreq = OCTAVE_VALS[i * 3 - 1]
		local mult = FACTOR_PI2 * frequency * subFreq
		e = e + avgMult * noise(
			x * subFreq,
			cos(angleY) * mult,
			sin(angleY) * mult,
			seed
		)
	end
	e = (e * OCTAVE_VALS[octaves * 3]) ^ redistribution

	return e
end

---Gets the value at a certain point, in the [0..1] range, while wrapping every 1 Y unit
---@param x number
---@param y number
---@return number value
function Noise2d:getYWrapped(x, y)
	return noise2dGetYWrapped(self.seed, self.frequency, self.octaves, self.redistribution, x, y)
end

local function noise2dGetXYWrapped(seed, frequency, octaves, redistribution, x, y)
	local e = 0
	local angleX = PI2 * x
	local angleY = PI2 * y
	for i = 1, octaves do
		local avgMult = OCTAVE_VALS[i * 3 - 2]
		local subFreq = OCTAVE_VALS[i * 3 - 1]
		local mult = FACTOR_PI2 * frequency * subFreq
		e = e + avgMult * noise(
			cos(angleX) * mult + seed,
			sin(angleX) * mult + seed,
			cos(angleY) * mult + seed,
			sin(angleY) * mult + seed
		)
	end
	e = (e * OCTAVE_VALS[octaves * 3]) ^ redistribution

	return e
end

---Gets the value at a certain point, in the [0..1] range, while wrapping every 1 X and 1 Y unit
---@param x number
---@param y number
---@return number value
function Noise2d:getXYWrapped(x, y)
	return noise2dGetXYWrapped(self.seed, self.frequency, self.octaves, self.redistribution, x, y)
end

---Creates a love.Image with this Noise2d.
---Last 2 parameters are optional; they multiply the frequency to zoom out.
---@param width integer
---@param height integer
---@param xMult number?
---@param yMult number?
---@param wrapX boolean?
---@param wrapY boolean?
function Noise2d:asImage(width, height, xMult, yMult, wrapX, wrapY)
	local imgData = love.image.newImageData(width, height)

	xMult, yMult = xMult or 1, yMult or 1

	xMult = xMult / width
	yMult = yMult / height

	local f
	if wrapX then
		if wrapY then
			f = noise2dGetXYWrapped
		else
			f = noise2dGetXWrapped
		end
	elseif wrapY then
		f = noise2dGetYWrapped
	else
		f = noise2dGet
	end

	if ffi then
		local p = ffi.cast("uint8_t*", imgData:getFFIPointer())

		local seed, frequency, octaves, redistribution =
			self.seed, self.frequency, self.octaves, self.redistribution

		for y = 0, height - 1 do
			local rowOffset = y * width * 4
			for x = 0, width - 1 do
				local val = floor(f(seed, frequency, octaves, redistribution, x * xMult, y * yMult) * 255)
				local pos = rowOffset + x * 4
				p[pos], p[pos + 1], p[pos + 2], p[pos + 3] =
					val, val, val, 255
			end
		end
	else
		-- Plain Lua fallback
		local seed, frequency, octaves, redistribution =
			self.seed, self.frequency, self.octaves, self.redistribution

		imgData:mapPixel(function(x, y)
			local val = f(seed, frequency, octaves, redistribution, x * xMult, y * yMult)
			return val, val, val, 1
		end)
	end

	local image = love.graphics.newImage(imgData)
	imgData:release()
	return image
end

return NoiseGen
