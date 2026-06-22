---@type AdoreInit
local Adore = require ""
local Loader = Adore.Loader
local AssetCollection = Adore.Common("Adore.AssetCollection")
local Generators = require "loader.procloader.procgenerators"

local TextureLoader = Loader.getCollection("TextureLoader")

---@class ProcLoader.Manifest.ResourceOptions
---@field type string # The type of resource to create

---@class ProcLoader.Manifest
---@field type "ProcLoader"
---@field options ProcLoader.Manifest.ResourceOptions
---@field cache ProcLoader.Manifest.Cache? # Cache settings

---@alias ProcLoader.Manifest.CacheCheckMode
---| "alwaysGenerate" # Always creates a new texture
---| "onChange" # Generates a new texture when the source files are changed
---| "loadCacheWithoutCheck" # If including the ".adore" directory in your project, this will make it load from there (fused files have an incorrect modified time)

---@class ProcLoader.Manifest.Cache
---@field checkMode ProcLoader.Manifest.CacheCheckMode

---@class ProcLoader.CacheInfo: Adore.Loader.CacheInfo
---@field minFilter love.FilterMode
---@field magFilter love.FilterMode
---@field PROC_LOADER_VERSION integer # The version of the ProcLoader used, in case of compatibility issues

---@class ProcLoader: Adore.AssetCollection
local ProcLoader = AssetCollection:extend()
ProcLoader.TYPE = "ProcLoader"

local PROC_LOADER_VERSION = 1
local EMPTY_ARR = {}

---@type ProcLoader.Manifest.Cache
local DEFAULT_CACHE_OPTIONS = {
	checkMode = "alwaysGenerate",
}

local function ignoreManifest(filepath, reason)
	if reason == "removed" and filepath:match("%.lua$") then
		return false
	end
	return true
end

---@param requirePath string
function ProcLoader:handler(requirePath)
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

	---@type ProcLoader.Manifest
	local manifest = require(requirePath)

	if manifest.type ~= "ProcLoader" then
		-- In case it's missing the type
		error(("Resource of type '%s' at '%s' does not match expected type '%s'"):format(manifest.type, requirePath, "ProcLoader"))
	end

	local options = manifest.options
	if not options or not options.type then error(("Missing options for ProcLoader: '%s'"):format(requirePath)) end
	local cacheOptions = manifest.cache or DEFAULT_CACHE_OPTIONS
	local cacheCheckMode = cacheOptions.checkMode

	local usingCache = false
	---@type ProcLoader.CacheInfo?
	local cacheInfo
	if cacheCheckMode ~= "alwaysGenerate" then
		-- Check if we even need to create a new noise, or if we can load
		-- "alwaysGenerate" means no caching at all
		cacheInfo = ProcLoader:getCacheInfo(requirePath)
		---@cast cacheInfo ProcLoader.CacheInfo?
		if cacheCheckMode == "loadCacheWithoutCheck" then
			-- Ignore the check and load the cached resource, if the files exist
			if
				cacheInfo and
				PROC_LOADER_VERSION == cacheInfo.PROC_LOADER_VERSION and
				ProcLoader:doCacheFilesExist(cacheInfo)
			then
				-- Check passed
				usingCache = true
			end
		else -- "onChange"
			-- Check if the cache needs to be updated
			if cacheInfo then
				if
					PROC_LOADER_VERSION == cacheInfo.PROC_LOADER_VERSION and
					ProcLoader:areSourceFilesChanged(EMPTY_ARR, cacheInfo, ignoreManifest)
				then
					-- Load the cached resource
					usingCache = true
				else
					usingCache = false
				end
			else
				usingCache = false
			end
		end
	end

	---@type TextureSource
	local newTSource
	if not usingCache then
		-- Create a new image, instead of using the cache
		newTSource = Generators[options.type](manifest, requirePath)
	else
		-- Create the noise from the cache
		---@cast cacheInfo ProcLoader.CacheInfo
		local texturePath = cacheInfo.cacheFiles[1]
		local texture = love.graphics.newImage(texturePath, {linear = (cacheInfo.minFilter or "nearest") == "linear"})
		local tw, th = texture:getDimensions()

		-- All we need is the texture and quad
		newTSource = {
			texture = texture,
			quad = love.graphics.newQuad(0, 0, tw, th, tw, th)
		}
	end

	-- Add each frame into TextureSource
	local texture = newTSource.texture

	if not usingCache and cacheCheckMode ~= "alwaysGenerate" then
		-- Save cache info if it's relevant
		local modifiedTimes = {}
		local minFilter, magFilter = texture:getFilter()

		local texturePath = ProcLoader:getCachePath(requirePath, "_tex.png")

		---@type ProcLoader.CacheInfo
		cacheInfo = {
			modifiedTimes = modifiedTimes,
			cacheFiles = {texturePath},
			minFilter = minFilter,
			magFilter = magFilter,
			type = options.type,
			PROC_LOADER_VERSION = PROC_LOADER_VERSION,
		}

		do
			-- Store the last modified time of the noise manifest file
			local manifestFilePath = requirePath:gsub("%.", "/")..".lua"
			local manifestFileInfo = love.filesystem.getInfo(manifestFilePath, "file")
			modifiedTimes[manifestFilePath] = manifestFileInfo.modtime
		end

		-- Render the texture
		local canvas = love.graphics.newCanvas(newTSource.texture:getDimensions())
		love.graphics.push("all")
		love.graphics.setCanvas(canvas)
		love.graphics.setColor(1, 1, 1)
		love.graphics.origin()
		love.graphics.draw(newTSource.texture)
		love.graphics.pop()

		-- Save the texture
		local imgData = canvas:newImageData()
		canvas:release()
		ProcLoader:ensureCacheDir()
		imgData:encode("png", texturePath)
		imgData:release()

		ProcLoader:setCacheInfo(requirePath, cacheInfo)
	elseif cacheCheckMode == "alwaysGenerate" then
		-- Remove cache info
		ProcLoader:setCacheInfo(requirePath, nil)
	end
	return newTSource
end

function ProcLoader:register(asset, path)
	-- Handler should not register assets into the TextureLoader
	ProcLoader.super.register(self, asset, path)
	asset.fromId = TextureLoader:register(asset, path)
end

-- TODO: Add ProcLoader reloading

Loader.addCollection(ProcLoader)
return ProcLoader
