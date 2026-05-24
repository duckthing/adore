local max, ceil = math.max, math.ceil
local lgDraw = love.graphics.draw

---@class NinePatch
---@field widths integer[] # The widths of each split
---@field heights integer[] # The heights of each split
---@field xStartCache integer[] # Where to start rendering a quad on the X axis
---@field yStartCache integer[] # Where to start rendering a quad on the Y axis
---@field quads love.Quad[] # The quads to draw
---@field texture love.Image # The texture
local NinePatch = {}
local NinePatchMT = {__index = NinePatch}

---Creates a NinePatch that can be drawn
---@param tSource TextureSource
---@param leftSize integer # The size of the left split
---@param rightSize integer # The size of the right split
---@param topSize integer # The size of the top split
---@param bottomSize integer # The size of the bottom split
---@return NinePatch
function NinePatch.new(tSource, leftSize, rightSize, topSize, bottomSize)
	local texture, quad = tSource.texture, tSource.quad
	local sourceX, sourceY, sourceW, sourceH = quad:getViewport()
	local textureW, textureH = texture:getDimensions()

	local midHSize = sourceW - leftSize - rightSize
	if midHSize < 0 then
		error(
			("Left and right splits leave a negative middle slice size (%d - %d - %d) = %d")
				:format(sourceW, leftSize, rightSize, midHSize)
		)
	end

	local midVSize = sourceH - topSize - bottomSize
	if midVSize < 0 then
		error(
			("Upper and lower splits leave a negative middle slice size (%d - %d - %d) = %d")
				:format(sourceH, topSize, bottomSize, midVSize)
		)
	end

	local widths = {leftSize, midHSize, rightSize}
	local heights = {topSize, midVSize, bottomSize}

	local quads = {
		0,0,0,
		0,0,0,
		0,0,0
	}
	---@cast quads love.Quad[]

	local xStartCache = {0, leftSize, leftSize + midHSize}
	local yStartCache = {0, topSize, topSize + midVSize}

	for x = 1, 3 do
		local xStart = xStartCache[x]
		local xSize = widths[x]
		for y = 1, 3 do
			local yStart = yStartCache[y]
			local ySize = heights[y]

			quads[x + (y - 1) * 3] = love.graphics.newQuad(xStart + sourceX, yStart + sourceY, xSize, ySize, textureW, textureH)
		end
	end

	return setmetatable({
		widths = widths,
		heights = heights,
		quads = quads,
		texture = texture,
		tSource = tSource,
	}, NinePatchMT)
end

---Draws the NinePatch
---@param self NinePatch
---@param x integer
---@param y integer
---@param w integer
---@param h integer
---@param scale integer?
function NinePatch:draw(x, y, w, h, scale)
	local texture = self.texture

	if not scale then scale = 1 end

	local widths, heights, quads =
		self.widths, self.heights, self.quads

	local midXScale = max(0, w - (widths[1] + widths[3]) * scale)
	local midYScale = max(0, h - (heights[1] + heights[3]) * scale)
	local midXPos = widths[1] * scale
	local midYPos = heights[1] * scale
	local lastXPos = (widths[1] * scale) + widths[2] * midXScale
	local lastYPos = (heights[1] * scale) + heights[2] * midYScale

	for i = 1, #quads do
		local quad = quads[i]
		local xIndex = (i - 1) % 3 + 1
		local yIndex = ceil(i * 0.3333333)

		local xScale, yScale = scale, scale
		local xPos, yPos = x, y

		if xIndex == 2 then
			xPos = xPos + midXPos
			xScale = midXScale
		elseif xIndex == 3 then
			xPos = xPos + lastXPos
		end

		if yIndex == 2 then
			yPos = yPos + midYPos
			yScale = midYScale
		elseif yIndex == 3 then
			yPos = yPos + lastYPos
		end

		lgDraw(texture, quad, xPos, yPos, 0, xScale, yScale)
	end
end

return NinePatch
