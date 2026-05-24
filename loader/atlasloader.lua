---@type AdoreInit
local Adore = require ""
local Loader = Adore.Loader
local RTA = Adore.Libraries("RTA")
local tclear = Adore.Common("Structures").tableClear
local AssetCollection = Adore.Common("Adore.AssetCollection")

---@type TextureLoader
local textureCollection, _ = Loader.getCollection("TextureLoader")

---@class AtlasLoader.Manifest.Options
---@field atlasMode "dynamic" | "fixed" | nil
---@field fixedWidth integer? # If fixed, the width of each image
---@field fixedHeight integer? # If fixed, the height of each image
---@field minFilter love.FilterMode?
---@field magFilter love.FilterMode?
---@field useImageData boolean?
---@field bakeAsPow2 boolean? # Rounds up width and height to the nearest power of 2, in case you target old hardware
---@field padding integer? # The pushing away of all images away from the edge of an atlas
---@field extrude integer? # The extending of the edges of each image outwards
---@field spacing integer? # The space **between** each image
---@field maxWidth integer?
---@field maxHeight integer?
---@field sortBy "area" | "height" | "width" | "none" | nil
---@field hardBake boolean? # Removes any references to the images to free up memory
---@field loadImagesIntoAdore boolean? # Registers all loaded images into the `love.Image` `AssetCollection`. Not recommended, as it defeats the purpose of an atlas.

---@class AtlasLoader.Manifest
---@field type "AtlasLoader"
---@field options AtlasLoader.Manifest.Options
---@field assets string[]? # An array of assets to include
---An array of directories and any Lua patterns to use.
---Ex. `{"assets/tiles/.*%.png", "assets/player/walk_.*%.png"}`
---* ...loads any file ending in '.png' under 'asset/tiles/' (but not subdirectories!)
---* ...loads any file matching 'walk_*.png', with '\*' being any character (but not subdirectories!)
---@field assetPatterns string[]?
---@field cache AtlasLoader.Manifest.Cache? # Cache settings

---@alias AtlasLoader.Manifest.CacheCheckMode
---| "alwaysGenerate" # Always creates a new atlas
---| "onChange" # Generates a new atlas when the source files are changed
---| "loadCacheWithoutCheck" # If including the ".adore" directory in your project, this will make it load from there (fused files have an incorrect modified time)

---@class AtlasLoader.Manifest.Cache
---@field checkMode AtlasLoader.Manifest.CacheCheckMode

---@class AtlasLoader.CacheInfo: Adore.Loader.CacheInfo
---@field quadInfo {[string]: integer[]} # A map of asset names to their quad regions
---@field minFilter love.FilterMode
---@field magFilter love.FilterMode
---@field ATLAS_LOADER_VERSION integer # The version of the atlas loader used, in case of compatibility issues

---@class Atlas
---@field setFilter fun(self, min: love.FilterMode, mag: love.FilterMode?)
---@field useImageData fun(self, useImageData: boolean)
---@field setBakeAsPow2 fun(self, pow2: boolean)
---@field setPadding fun(self, padding: integer)
---@field setExtrude fun(self, extrude: integer)
---@field setSpacing fun(self, spacing: integer)
---@field setMaxSize fun(self, width: integer?, height: integer?)
---@field add fun(self, image: love.Texture, id: any, bake: boolean?)
---@field remove fun(self, id: any, bake: boolean?)
---@field getViewport fun(self, id: any): integer, integer, integer, integer
---@field bake fun(self, sortBy: "area" | "height" | "width" | "none" | nil)
---@field hardBake fun(self, sortBy: "area" | "height" | "width" | "none" | nil)
---@field draw fun(self, id: any, x: number?, y: number?, r: number?, sx: number?, sy: number?, ox: number?, oy: number?, kx: number?, ky: number?)
---@field ids {[any]: integer}
---@field quads love.Quad[]
---@field image love.Image
---@field assets string[] # Added by the handler

---@class AtlasLoader: Adore.AssetCollection
local AtlasLoader = AssetCollection:extend()
AtlasLoader.TYPE = "AtlasLoader"
AtlasLoader.ALIASES = {"atlasloader", "atlas", "atlassource"}

local AtlasFrameSource = {}
local AtlasFrameSourceMT = {__index = AtlasFrameSource}
AtlasFrameSource.from = AtlasFrameSource

local tempMap = {}

local ATLAS_LOADER_VERSION = 1

---@type AtlasLoader.Manifest.Cache
local DEFAULT_CACHE_OPTIONS = {
	checkMode = "alwaysGenerate",
}

---Returns either the simple requested paths, or the requested paths and asset patterns combined
---@param manifest AtlasLoader.Manifest
---@return string[] assetPaths
local function collectPathsFromPatterns(manifest)
	local setAssets = manifest.assets
	local patternPaths = manifest.assetPatterns

	-- Early return if there's no pattern matching
	if not patternPaths or not next(patternPaths) then return setAssets or {} end

	---@type {[string]: true} # A map of paths to `true`
	local assets = tempMap

	if setAssets then
		-- Add existing assets from the normal array into the map
		for i = 1, #setAssets do
			assets[setAssets[i]] = true
		end
	end

	if patternPaths then
		-- Add to the map each matched pattern
		for i = 1, #patternPaths do
			-- Simplify the pattern first, into the starting directory and the file pattern
			local fullPattern = patternPaths[i]
			-- Pattern returns:
			-- "assets/stuff/aaa.png" => "assets/stuff/", "aaa.png"
			-- "aaa.png" => nil
			local start, pattern = fullPattern:match("^(.*/)(.*)")
			if not start then start, pattern = "", fullPattern end
			pattern = "^"..pattern

			local items = love.filesystem.getDirectoryItems(start)
			for j = 1, #items do
				-- For each item in this directory
				local item = items[j]
				if item:match(pattern) then
					-- Matched the pattern
					local fullPath = start..item
					local info = love.filesystem.getInfo(fullPath)
					if info then
						-- It's a valid file, add it into the map
						assets[fullPath] = item
					end
				end
			end
		end
	end

	-- Add each asset to the array
	---@type string[]
	local assetArr = {}
	local i = 1
	for asset, _ in pairs(assets) do
		assetArr[i] = asset
		i = i + 1
	end
	tclear(assets)
	return assetArr
end

local function ignoreManifest(filepath, reason)
	if reason == "removed" and filepath:match("%.lua$") then
		return false
	end
	return true
end

---@param requirePath string # The require path (ex. "assets.resource")
function AtlasLoader:handler(requirePath)
	---@type string # The filesystem path (ex. "assets/resource.lua")
	local formalPath = ""

	if requirePath:find("/") then
		-- Informalize
		-- Turns "assets/resource.lua" into "assets.resource"
		formalPath = requirePath
		requirePath = requirePath:match("(.*)%.lua"):gsub("/", ".")
	else
		-- Formalize
		-- Turns "assets.resource" into "assets/resource.lua"
		formalPath = requirePath:gsub("%.", "/")..".lua"
	end

	---@type AtlasLoader.Manifest
	local manifest = require(requirePath)

	if manifest.type ~= "AtlasLoader" then
		-- In case it's missing the type
		error(("Resource of type '%s' at '%s' does not match expected type '%s'"):format(manifest.type, requirePath, "AtlasLoader"))
	end

	local options = manifest.options or {}
	local cacheOptions = manifest.cache or DEFAULT_CACHE_OPTIONS
	local cacheCheckMode = cacheOptions.checkMode

	---@type string[]
	local assets

	---@type Atlas
	local atlas

	local usingCache = false
	---@type AtlasLoader.CacheInfo?
	local cacheInfo
	if cacheCheckMode ~= "alwaysGenerate" then
		-- Check if we even need to create a new atlas, or if we can load
		-- "alwaysGenerate" means no caching at all
		cacheInfo = self:getCacheInfo(requirePath)
		---@cast cacheInfo AtlasLoader.CacheInfo?
		if cacheCheckMode == "loadCacheWithoutCheck" then
			-- Ignore the check and load the cached atlas, if the files exist
			if
				cacheInfo and
				ATLAS_LOADER_VERSION == cacheInfo.ATLAS_LOADER_VERSION and
				self:doCacheFilesExist(cacheInfo)
			then
				-- Check passed
				assets = collectPathsFromPatterns(manifest)
				usingCache = true
			end
		else -- "onChange"
			-- Check if the cache needs to be updated
			if cacheInfo then
				assets = collectPathsFromPatterns(manifest)
				if
					ATLAS_LOADER_VERSION == cacheInfo.ATLAS_LOADER_VERSION and
					self:areSourceFilesChanged(assets, cacheInfo, ignoreManifest)
				then
					-- Load the atlas
					usingCache = true
				else
					usingCache = false
				end
			else
				usingCache = false
			end
		end
	end

	if not usingCache then
		-- Create a new atlas, instead of using the cache (if it exists)
		local mode = options.atlasMode or "dynamic"

		if mode == "dynamic" then
			atlas = RTA.newDynamicSize(options.padding, options.extrude, options.spacing)
		else
			atlas = RTA.newFixedSize(options.fixedWidth, options.fixedHeight, options.padding, options.extrude, options.spacing)
		end
		---@cast atlas Atlas

		do
			local min, mag = love.graphics.getDefaultFilter()
			atlas:setFilter(options.minFilter or min, options.magFilter or mag)
		end

		if options.useImageData then
			atlas:useImageData(true)
		end
		if options.bakeAsPow2 then
			atlas:setBakeAsPow2(true)
		end
		if options.maxWidth or options.maxHeight then
			atlas:setMaxSize(options.maxWidth, options.maxHeight)
		end

		assets = assets or collectPathsFromPatterns(manifest)

		if assets then
			if not options.loadImagesIntoAdore then
				for id, assetPath in ipairs(assets) do
					-- Check if already loaded somewhere else, and use it
					-- Otherwise, only load it for us

					---@type TextureSource
					local tSource = textureCollection:has(assetPath)
					---@type love.Texture
					local image

					if not tSource then
						-- Doesn't exist, load a new image
						tSource = textureCollection:handler(assetPath)
						image = tSource.texture
					end

					-- TextureSources may be a region of a bigger texture.
					-- In that case, we should make load a new image instead.
					local tw, th = tSource.texture:getDimensions()
					local qx, qy, qw, qh = tSource.quad:getViewport()
					if qx == 0 and qy == 0 and qw == tw and qh == th then
						-- TextureSource is a whole image, safe to use
						image = tSource.texture
					else
						-- It's a region, turn the region into a new image
						-- TODO: Make Atlas object use regions in TextureSources, instead of creating a new image

						local canvas = love.graphics.newCanvas(qw, qh)
						love.graphics.push("all")
						love.graphics.setCanvas(canvas)
						love.graphics.origin()
						love.graphics.setColor(1, 1, 1)
						love.graphics.setBlendMode("alpha", "alphamultiply")
						love.graphics.draw(tSource.texture, tSource.quad)
						love.graphics.pop()

						local imgData = canvas:newImageData()
						image = love.graphics.newImage(imgData)
						imgData:release()
						canvas:release()
					end

					atlas:add(image, id, false)
				end
			else
				for id, assetPath in ipairs(assets) do
					-- Load it into the TextureCollection asset collection
					local tSource, _ = textureCollection:get(assetPath)
					atlas:add(tSource.texture, id, false)
				end
			end
		end

		if options.hardBake then
			atlas:hardBake(options.sortBy)
		else
			atlas:bake(options.sortBy)
		end
		atlas.assets = assets
	else
		-- Create the atlas from the cache
		---@cast cacheInfo AtlasLoader.CacheInfo
		local texturePath = cacheInfo.cacheFiles[1]

		---@cast cacheInfo AtlasLoader.CacheInfo

		---@type love.Quad[]
		local quads = {}
		local texture = love.graphics.newImage(texturePath, {linear = (cacheInfo.minFilter or "nearest") == "linear"})

		-- All we need is the texture and quads
		---@diagnostic disable-next-line: missing-fields
		atlas = {
			image = texture,
			quads = quads,
			assets = assets,
		}

		local cachedQuads = cacheInfo.quadInfo
		local sw, sh = texture:getDimensions()
		for i = 1, #assets do
			-- Create the quads
			local q = cachedQuads[assets[i]]
			quads[i] = love.graphics.newQuad(q[1], q[2], q[3], q[4], sw, sh)
		end
	end

	local atlasTexture = atlas.image

	if not usingCache and cacheCheckMode ~= "alwaysGenerate" then
		-- Save cache info if it's relevant
		local modifiedTimes = {}
		local cacheFiles = {}
		local quadInfo = {}
		local minFilter, magFilter = atlasTexture:getFilter()

		---@type AtlasLoader.CacheInfo
		cacheInfo = {
			modifiedTimes = modifiedTimes,
			cacheFiles = cacheFiles,
			quadInfo = quadInfo,
			minFilter = minFilter,
			magFilter = magFilter,
			ATLAS_LOADER_VERSION = ATLAS_LOADER_VERSION,
		}

		-- Insert relevant info
		for i = 1, #assets do
			local assetPath = assets[i]

			-- Store the last modified time
			local fileInfo = love.filesystem.getInfo(assetPath, "file")
			modifiedTimes[assetPath] = fileInfo.modtime

			-- Store the quad coordinates
			quadInfo[assetPath] = {atlas.quads[i]:getViewport()}
		end

		do
			-- Store the last modified time of the atlas manifest file
			local manifestFilePath = requirePath:gsub("%.", "/")..".lua"
			local manifestFileInfo = love.filesystem.getInfo(manifestFilePath, "file")
			modifiedTimes[manifestFilePath] = manifestFileInfo.modtime
		end

		local texturePath = self:getCachePath(requirePath, "_tex.png")

		-- Render the texture
		local canvas = love.graphics.newCanvas(atlasTexture:getDimensions())
		love.graphics.push("all")
		love.graphics.setCanvas(canvas)
		love.graphics.origin()
		love.graphics.setColor(1, 1, 1)
		love.graphics.setBlendMode("alpha", "alphamultiply")
		love.graphics.draw(atlasTexture)
		love.graphics.pop()

		-- Save the texture
		local imgData = canvas:newImageData()
		canvas:release()
		self:ensureCacheDir()
		imgData:encode("png", texturePath)
		imgData:release()

		cacheFiles[#cacheFiles+1] = texturePath

		self:setCacheInfo(requirePath, cacheInfo)
	elseif cacheCheckMode == "alwaysGenerate" then
		-- Remove cache info
		self:setCacheInfo(requirePath, nil)
	end

	return atlas
end

---@param atlas Atlas
---@param path string
function AtlasLoader:register(atlas, path)
	AtlasLoader.super.register(self, atlas, path)

	-- Add each frame into TextureSource
	local atlasTexture = atlas.image
	for id, assetPath in ipairs(atlas.assets) do
		local quad = atlas.quads[id]
		---@type TextureSource
		local frameSource = setmetatable({
			texture = atlasTexture,
			quad = quad,
			fromId = 0,
		}, AtlasFrameSourceMT)

		if textureCollection.pathToId[assetPath] then
			print(("[Adore.AtlasLoader] Found already loaded texture: '%s'"):format(assetPath))
			print("[Adore.AtlasLoader] Overwriting...")
		end
		textureCollection:register(frameSource, assetPath)
	end

end

-- TODO: Add atlas reloading

Loader.addCollection(AtlasLoader)
return AtlasLoader
