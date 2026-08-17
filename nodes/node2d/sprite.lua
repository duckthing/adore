---@type AdoreInit
local Adore = require ""
local Node2d = Adore.Nodes("Node2d")
local min, max, floor = math.min, math.max, math.floor

---@class Sprite: Node2d
---@field super Node2d
---@overload fun(x: number?, y: number?, texture: TextureSource?, rows: integer?, columns: integer?): Sprite
local Sprite = Node2d:extend()
Sprite.CLASS_NAME = "Sprite"

function Sprite:new(x, y, texture, rows, columns)
	Sprite.super.new(self, x, y)

	---@type TextureSource?
	self._texture = texture
	---@type love.Quad
	self._quad = love.graphics.newQuad(0, 0, 1, 1, 1, 1)

	---@type boolean
	self._centered = true
	---@type integer
	self._frame = 1

	---@type integer
	self._actualFrame = 0
	---@type integer
	self._frameCount = 1
	---@type integer, integer
	self._frameW, self._frameH = 1, 1

	---@type boolean, boolean # Whether this Sprite should get flipped along a certain axis
	self.flipH, self.flipV = false, false

	---@type number, number # The offset, used when a texture is centered
	self._offsetX, self._offsetY =
		0, 0

	self._columns, self._rows =
		1, 1

	rows, columns =
		rows or 1,
		columns or 1

	self:setFrameCount(rows, columns)
end

---Updates the viewport of the Quad so that it shows the specified frame in the texture
function Sprite:_updateQuad()
	local tSource = self._texture
	if not tSource then
		return
	end

	local frameCount = self._frameCount

	if frameCount == 1 then
		-- Only 1 frame
		local ox, oy, ow, oh = tSource.quad:getViewport()
		self._actualFrame = 0
		self._quad:setViewport(ox, oy, ow, oh, tSource.texture:getDimensions())
		self._localContentRect:iSetComponents(self._offsetX, self._offsetY, ow, oh)
		self:_updateGlobalBounds()
	else
		-- Check if the quad should be changed
		local newActualFrame = max(1, min(self._frame, frameCount))
		self._actualFrame = newActualFrame

		local frame = newActualFrame - 1
		local tx, ty, _, _ = tSource.quad:getViewport()

		local xIndex = (frame % self._columns)
		local yIndex = floor(frame / self._columns)
		local frameW, frameH =
			self._frameW,
			self._frameH
		self._quad:setViewport(xIndex * frameW + tx, yIndex * frameH + ty, frameW, frameH, tSource.texture:getDimensions())
		self._localContentRect:iSetComponents(self._offsetX, self._offsetY, frameW, frameH)
		self:_updateGlobalBounds()
	end
end

---Sets the frame count and updates the quad
---@param rows integer
---@param columns integer
---@return self
function Sprite:setFrameCount(rows, columns)
	local tSource = self._texture
	if not tSource then
		-- No texture to reference
		return self
	end

	rows, columns =
		(rows and floor(rows)) or 1,
		(columns and floor(columns)) or 1

	local _, _, w, h = tSource.quad:getViewport()
	local frameW, frameH =
		w / columns, h / rows
	self._frameW, self._frameH = frameW, frameH
	self._rows, self._columns =
		rows, columns
	self._frameCount = rows * columns

	-- Update the offset
	if self._centered then
		self._offsetX, self._offsetY =
			-frameW * 0.5,
			-frameH * 0.5
	else
		self._offsetX, self._offsetY =
			0, 0
	end

	-- Update the quad
	self:_updateQuad()

	return self
end

function Sprite:setColumns(columns) self:setFrameCount(self._rows, columns) end
function Sprite:setRows(rows) self:setFrameCount(rows, self._columns) end

---Sets whether the texture will be centered in the Sprite
---@param centered boolean
---@return self
function Sprite:setCentered(centered)
	if self._centered == centered then return self end
	self._centered = centered
	self:setFrameCount(self._rows, self._columns)
	return self
end

---Sets the texture used for drawing
---@param texture TextureSource?
---@return self
function Sprite:setTexture(texture)
	if self._texture ~= texture then
		self._texture = texture
		self:setFrameCount(self._rows, self._columns)
	end
	return self
end

---Sets the current frame index
---@param frame integer
---@return self
function Sprite:setFrame(frame)
	if self._frame ~= frame then
		self._frame = frame
		self:_updateQuad()
	end
	return self
end

function Sprite:draw()
	local tSource = self._texture
	if tSource then
		local offsetX, offsetY = self._offsetX, self._offsetY
		local scaleX, scaleY = 1, 1

		if self.flipH then
			scaleX = -scaleX
			offsetX = offsetX + self._frameW
		end

		if self.flipV then
			scaleY = -scaleY
			offsetY = offsetY + self._frameH
		end

		love.graphics.draw(tSource.texture, self._quad, offsetX, offsetY, 0, scaleX, scaleY)
	end
end

function Sprite._addDefinition(entry)
	entry:newAssetPath("_texture", "TextureLoader", nil, "setTexture")
	entry:newInteger("_frame", 1, 1, nil, nil, "setFrame")
	entry:newInteger("_columns", 1, 1, nil, nil, "setColumns")
	entry:newInteger("_rows", 1, 1, nil, nil, "setRows")
	entry:newBoolean("_centered", true, "setCentered")
	entry:newBoolean("flipH", false)
	entry:newBoolean("flipV", false)
end

return Sprite
