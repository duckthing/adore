local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.loader%.sheetloader")
local Structures = require(ADORE_PATH..".common.structures")
local tnew = Structures.tableNew

---@type Adore.Loader
local Loader = require(ADORE_PATH..".loader")
---@type Adore.AssetCollection
local AssetCollection = require(ADORE_PATH..".loader.assetcollection")

---@type Adore.AssetCollection
local textureCollection, _ = Loader.getCollection("TextureLoader")

---@class SheetLoader: Adore.AssetCollection
local SheetLoader = AssetCollection:extend()
SheetLoader.TYPE = "SheetLoader"
SheetLoader.ALIASES = {"sheetloader", "spritesheetloader", "spritesheet", "sprite"}

---You should choose between `SheetSource.Manifest.Even` or `SheetSource.Manifest.Dynamic`
---@class SheetLoader.Manifest
---@field type "SheetLoader"
---@field path string # Path to the asset (ex: `assets/player.png`)
---@field names {[string]: integer}? # An optional map of names to frame indices (ex: `player.png@idle` vs. `player.png@1`)

---The base class of `SheetSource.Even` and `SheetSource.Dynamic`
---@class SheetSource: TextureSource
---@field names {[string]: integer}?
---@field frames TextureSource[] # An array of each frame

---A `SheetLoader.Even` manifest, for sprite sheets where each frame is the same size
---@class SheetLoader.Manifest.Even: SheetLoader.Manifest
---@field rows integer? # Amount of rows; default of `1`
---@field columns integer? # Amount of columns; default of `1`

---A `SheetSource` where all frames are evenly split across frames.
---Ideal for normal sprite sheets, where each frame takes up the same space.
---@class SheetSource.Even: SheetSource
---@field rows integer
---@field columns integer

---A `SheetLoader.Dynamic` manifest, for sprite sheets where each frame can have varying sizes
---@class SheetLoader.Manifest.Dynamic: SheetLoader.Manifest
---@field rows integer? # Amount of rows; default of `1`
---@field columns integer? # Amount of columns; default of `1`
---@field quads integer[][]

---A `SheetSource` where frames can have varying sizes.
---Ideal for packed sprite sheets, where many frames take up different portions of the texture.
---@class SheetSource.Dynamic: SheetSource
---An array of (X/Y) + (W/H) for each quad.
---(ex. `{0, 0, 32, 16}` marks a quad from X: 0, Y: 0, with a width of 32 and height of 16)

---ImageLoader does real loading through `love.graphics.newImage`, in the expected format

---A section of a `SheetSource`; frames may be unevenly split
---@class FrameSource: TextureSource
local FrameSource = {}
FrameSource.from = SheetLoader
local FrameSourceMT = {__index = FrameSource}

---Creates and returns the frames for even sheets
---@param manifestPath string
---@param manifest SheetLoader.Manifest.Even
---@return SheetSource.Even
---@return FrameSource[]
local function createEvenFrames(manifestPath, manifest)
	local rows, columns =
		manifest.rows or 1, manifest.columns or 1

	local texturePath = manifest.path
	local tSource = textureCollection:get(texturePath)

	local ox, oy, ow, oh = tSource.quad:getViewport()

	local frameW, frameH =
		ow / columns, oh / rows

	-- Check if frame sizes are evenly divisible
	if frameW % 1 ~= 0 or frameH % 1 ~= 0 then
		error(
			("[Adore.SheetLoader] Asset '%s' has a dimension that is not cleanly divisible.\n[Width: %d, Height: :%d] into [Col: %d, Row: %d]")
			:format(manifestPath, ow, oh, columns, rows)
		)
	end

	tSource.rows, tSource.columns =
		rows, columns

	---@type FrameSource[]
	local frames = tnew(rows * columns, 0)
	tSource.frames = frames
	local assetPrefix = texturePath.."@"
	local texture = tSource.texture

	for row = 1, rows do
		for column = 1, columns do
			-- Create the FrameSource for each frame
			local frameI = column + (columns * (row - 1))
			local quad = love.graphics.newQuad(
				-- ox, oy,
				ox + (column - 1) * frameW,
				oy + (row - 1) * frameH,
				frameW, frameH, texture
			)

			---@type FrameSource
			local frameSource = setmetatable({
				texture = texture,
				quad = quad,
				fromId = 0,
			}, FrameSourceMT)
			frames[frameI] = frameSource
			frameSource.fromId = textureCollection:register(frameSource, assetPrefix..frameI)
		end
	end

	return tSource, frames
end

---Creates and returns the frames for even sheets
---@param manifestPath string
---@param manifest SheetLoader.Manifest.Dynamic
---@return SheetSource.Dynamic
---@return FrameSource[]
local function createDynamicFrames(manifestPath, manifest)
	local quads = manifest.quads
	local numQuads = #quads

	local texturePath = manifest.path
	local tSource = textureCollection:get(texturePath)

	local ox, oy, ow, oh = tSource.quad:getViewport()

	---@type FrameSource[]
	local frames = tnew(numQuads, 0)
	tSource.frames = frames
	local assetPrefix = texturePath.."@"
	local texture = tSource.texture

	for frameI = 1, numQuads do
		-- Create the FrameSource for each frame
		local q = quads[frameI]
		local qx, qy, qw, qh =
			q[1], q[2],
			q[3], q[4]

		-- Check if the quad fits inside the texture
		if
			qx < ox -- Starting X passes the left edge of the texture
			or
			qy < oy -- Starting Y passes the upper edge of the texture
			or
			qx + qw > ow -- Width goes past the right edge of the texture
			or
			qy + qh > oh -- Height goes past the bottom edge of the texture
		then
			error(
				("[Adore.SheetLoader] On quad '%d' in asset '%s':\n[Adore.SheetLoader] Quad bounds leave the texture bounds")
					:format(frameI, manifestPath)
			)
		end

		local quad = love.graphics.newQuad(
			ox + qx,
			oy + qy,
			qw,
			qh,
			texture
		)

		---@type FrameSource
		local frameSource = setmetatable({
			texture = texture,
			quad = quad,
			fromId = 0,
		}, FrameSourceMT)
		frames[frameI] = frameSource
		frameSource.fromId = textureCollection:register(frameSource, assetPrefix..frameI)
	end

	return tSource, frames
end

---@param assetPath string
---@return TextureSource
function SheetLoader:handler(assetPath)
	local luaRequirePath = assetPath:match("(.*)%.lua$"):gsub("[/\\]", ".")

	---@type SheetLoader.Manifest.Even | SheetLoader.Manifest.Dynamic
	local manifest = require(luaRequirePath)

	if manifest.type ~= "SheetLoader" then
		-- In case it's missing the type
		error(("Resource of type '%s' at '%s' does not match expected type '%s'"):format(manifest.type, assetPath, "SheetLoader"))
	end

	local sheetSource, frames
	if manifest.columns or manifest.rows then
		-- It's for SheetSource.Even
		---@cast manifest SheetLoader.Manifest.Even
		sheetSource, frames = createEvenFrames(assetPath, manifest)
	elseif manifest.quads then
		-- It's for SheetSource.Dynamic
		---@cast manifest SheetLoader.Manifest.Dynamic
		sheetSource, frames = createDynamicFrames(assetPath, manifest)
	else
		-- It's ambiguous/missing fields
		error(("[Adore.SheetLoader] Missing required fields in '%s'"):format(assetPath))
	end

	return sheetSource
end

---@param sheetSource SheetSource
---@param assetPath string
function SheetLoader:register(sheetSource, assetPath)
	local luaRequirePath = assetPath:match("(.*)%.lua$"):gsub("[/\\]", ".")
	---@type SheetLoader.Manifest.Even | SheetLoader.Manifest.Dynamic
	local manifest = require(luaRequirePath)

	local names = manifest.names
	if names then
		-- Add the alternate names, if they exist
		sheetSource.names = names
		local assetPrefix = manifest.path.."@"
		local frames = sheetSource.frames
		for altName, frameI in pairs(names) do
			local frame = frames[frameI]
			if not frame then
				error(("[Adore.SheetLoader] Frame '%d' doesn't exist inside of Sheet '%s'"):format(frameI, assetPath))
			end

			-- Register the alternate name
			textureCollection:register(frame, assetPrefix..altName)
		end
	end
end

---@param collection Adore.AssetCollection
---@param path string
---@param ... unknown
function SheetLoader:reloader(collection, path, ...)
	local id = collection.pathToId[path]
	---@type TextureSource
	local tSource = collection.assets[id]
	local imageData = love.image.newImageData(path)
	local image = tSource.texture
	---@cast image love.Image
	image:replacePixels(imageData)
	imageData:release()
end

Loader.addCollection(SheetLoader)
return SheetLoader
