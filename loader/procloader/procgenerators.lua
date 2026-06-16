---@type AdoreInit
local Adore = require ""
local NoiseGen = Adore.Common("NoiseGen")
-- local Expression = Adore.Libraries("Expression")
local Expression = require "adore.lib.expression.expression"
local floor = math.floor
local sqrt = math.sqrt

---@type ffilib?
local ffi
if pcall(require, "_G.jit") and require("_G.jit").status() then
	ffi = Adore.Common("ffilib")
end

---@class ProcLoader.Manifest.Noise2dResourceOptions: ProcLoader.Manifest.ResourceOptions
---@field type "Noise2d"
---@field width integer
---@field height integer
---@field minFilter love.FilterMode?
---@field magFilter love.FilterMode?
---@field seed integer?
---@field octaves integer?
---@field frequency number?
---@field redistribution number?
---@field wrapX boolean?
---@field wrapY boolean?

---@class ProcLoader.Manifest.ExpressionResourceOptions: ProcLoader.Manifest.ResourceOptions
---@field type "Expression"
---@field width integer
---@field height integer
---@field expression string
---@field minFilter love.FilterMode?
---@field magFilter love.FilterMode?

---@class ProcLoader.Manifest.DrawnResourceOptions: ProcLoader.Manifest.ResourceOptions
---@field type "Drawn"
---@field width integer
---@field height integer
---@field script string # The code
---@field minFilter love.FilterMode?
---@field magFilter love.FilterMode?

local EXPRESSION_FUNCS = {
	dist = function(ax, ay, bx, by)
		local dx, dy = bx - ax, by - ay
		return sqrt(dx*dx + dy*dy)
	end,
	dist2 = function(ax, ay, bx, by)
		local dx, dy = bx - ax, by - ay
		return dx*dx + dy*dy
	end,
	min = math.min,
	max = math.max,
}

---@type {[string]: fun(manifest: ProcLoader.Manifest, manifestPath: string): TextureSource}
local Generators = {
	Noise2d = function(manifest, manifestPath)
		local options = manifest.options
		---@cast options ProcLoader.Manifest.Noise2dResourceOptions

		local width, height = options.width, options.height
		local image = NoiseGen.new2d(options.seed, options.frequency, options.octaves, options.redistribution)
			:asImage(width, height, nil, nil, options.wrapX, options.wrapY)

		do
			local min, mag = love.graphics.getDefaultFilter()
			image:setFilter(options.minFilter or min, options.magFilter or mag)
		end

		---@type TextureSource
		return {
			texture = image,
			quad = love.graphics.newQuad(0, 0, width, height, width, height)
		}
	end,
	Expression = function(manifest, manifestPath)
		local options = manifest.options
		---@cast options ProcLoader.Manifest.ExpressionResourceOptions

		local width, height = options.width, options.height
		local imgData = love.image.newImageData(width, height)

		local solver, errMessage = Expression.sandboxExpression(options.expression)
		if not solver then
			error(("Errored loading expression in '%s': %s"):format(manifestPath, errMessage))
		end

		local constants = setmetatable({
			width = width,
			height = height,
			halfWidth = width * 0.5,
			halfHeight = height * 0.5,
			x = 1,
			y = 1
		}, {__index = EXPRESSION_FUNCS})

		if ffi then
			local p = ffi.cast("uint8_t*", imgData:getFFIPointer())

			for y = 0, height - 1 do
				local rowOffset = y * width * 4
				for x = 0, width - 1 do
					constants.x, constants.y = x + 1, y + 1
					local exSuccess, result = solver(constants)
					if not exSuccess then
						error(("Errored running expression in '%s': '%s'"):format(manifestPath, result))
					end
					local val = floor(result * 255)
					local pos = rowOffset + x * 4
					p[pos], p[pos + 1], p[pos + 2], p[pos + 3] =
						val, val, val, 255
				end
			end
		else
			-- Plain Lua fallback
			imgData:mapPixel(function(x, y)
				constants.x, constants.y = x, y
				local exSuccess, result = solver(constants)
				if not exSuccess then
					error(("Errored running expression in '%s': '%s'"):format(manifestPath, result))
				end
				local val = floor(result * 255)
				return val, val, val, 1
			end)
		end

		local image = love.graphics.newImage(imgData)
		imgData:release()
		---@type TextureSource
		return {
			texture = image,
			quad = love.graphics.newQuad(0, 0, width, height, width, height)
		}
	end,
	Drawn = function(manifest, manifestPath)
		local options = manifest.options
		---@cast options ProcLoader.Manifest.DrawnResourceOptions

		local width, height = options.width, options.height
		local canvas = love.graphics.newCanvas(width, height)

		local success, func = pcall(loadstring, options.script)
		if not success then
			error(("Errored loading function in '%s': %s"):format(manifestPath, func))
		end

		love.graphics.push("all")
		love.graphics.reset()
		love.graphics.setCanvas(canvas)
		func()
		love.graphics.pop()

		local imgData = canvas:newImageData()
		local image = love.graphics.newImage(imgData)
		imgData:release()
		canvas:release()
		---@type TextureSource
		return {
			texture = image,
			quad = love.graphics.newQuad(0, 0, width, height, width, height)
		}
	end
}
return Generators
