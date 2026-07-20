---@type string
-- local PKG_NAME = ...
-- local ADORE_PATH = PKG_NAME:match("(.*)%.loader%.assetcollection")

---@type TinyTOML
local TinyTOML = require("lib.tinytoml")
---@type SimpleObject
local SimpleObject = require("lib.classic")
---@type Structures
local Structures = require("common.structures")
local tclear = Structures.tableClear

---@alias AssetID integer

---@class Adore.Loader.CacheInfo
---@field modifiedTimes {[string]: number} # Modified times for each file
---@field cacheFiles string[] # Files to delete when the cache is invalidated
---@field CACHE_VERSION integer? # The cache version; if the loaded version is different from the constant, it's invalid

---@class Adore.AssetCollection: SimpleObject
---@field super Adore.AssetCollection
---@field assets (table | userdata | any)[] # A map of asset IDs to assets
---@field idToPath {[AssetID]: string} # A map of IDs to asset paths
---@field pathToId {[string]: AssetID} # A map of asset paths to IDs
---@field nextId AssetID # The next ID to use for the next inserted asset
---@overload fun(type: string, handler: function?, destructor: function?, reloader: function?): Adore.AssetCollection
local AssetCollection = SimpleObject:extend()

---@type string # The type of this collection
AssetCollection.TYPE = nil

local CACHE_VERSION = 1

---@param type string
---@param handler any
---@param destructor any
---@param reloader any
function AssetCollection:new(type, handler, destructor, reloader)
	AssetCollection.super.new(self)
	self.TYPE = type
	---@type any[]
	self.assets = {}
	---@type {[AssetID]: string}
	self.idToPath = {}
	---@type {[string]: AssetID}
	self.pathToId = {}
	---@type AssetID
	self.nextId = 1

	if handler then
		self.handler = function(_, ...) return handler(...) end
	end
	if destructor then
		self.destructor = function(_, ...) return destructor(...) end
	end
	if reloader then
		self.reloader = function(_, ...) return reloader(...) end
	end
end

---Loads a new asset from a path, without registering it
---@param path string
---@param ... unknown
---@return (table | userdata) asset
function AssetCollection:handler(path, ...)
end

---Reloads an asset at a certain path
---@param path string
---@param ... unknown
function AssetCollection:reloader(path, ...)
end

---Destroys an asset, and optionally replaces it with another asset
---@param toDestroy (table | userdata)
---@param newAsset (table | userdata)
function AssetCollection:destructor(toDestroy, newAsset)
end

---@type {[string]: true} # A map of filepaths to `true`, used for checking if a file is in `modifiedTimes` but not `files`.
local pathMap = {}

local CACHE_DIR = ".adore/"

---Turns a normal path into a cache path
---@param self Adore.AssetCollection
---@param filepath string
---@param postfix string?
---@return string
local function getCachePath(self, filepath, postfix)
	postfix = postfix or ""
	return CACHE_DIR..filepath:gsub("[/\\%.]", "_")..postfix
end

AssetCollection.getCachePath = getCachePath

---Creates the cache directory, if it doesn't exist.
---If you include the ".adore" cache in your fused project, it may appear readable but not writable.
---To make it writable, use this function.
function AssetCollection:ensureCacheDir()
	love.filesystem.createDirectory(CACHE_DIR)
end

---With the CacheInfo table, returns `true` if all of files in `cacheInfo.cacheFiles` exist.
---Called already in `Loader.areSourceFilesChanged()`.
---@param cacheInfo Adore.Loader.CacheInfo
function AssetCollection:doCacheFilesExist(cacheInfo)
	local files = cacheInfo.cacheFiles
	for i = 1, #files do
		local fileInfo = love.filesystem.getInfo(files[i], "file")
		if not fileInfo then return false end
	end
	return true
end

local function returnTrue() return true end

---@alias Adore.Loader.ModifiedReason
---| "modified" # A file's modified time is different compared to the cache
---| "missing" # Requested in `files`, but not found in your project
---| "added" # Requested in `files`, but not included in the last cache
---| "removed" # Included in the last cache, but not requested in `files`

---Given a map of file paths to modified times, returns `false` if one file is different.
---`false` is returned if any file in `files` is either:
---* Missing from `modifiedTimes`
-- * Has a different modified time
---`false` is also returned if:
---* `modifiedTimes` has a file that is not in `files`
---* A file in `cacheInfo.cacheFiles` doesn't exist
---Otherwise, returns `true` if they are all the exact same
---@param files string[] # All filepaths to check
---@param cacheInfo Adore.Loader.CacheInfo # Cache info
---@param invalidateCallback (fun(filepath: string, reason: Adore.Loader.ModifiedReason): boolean)? # An optional callback that returns `true` if the cache should be invalidated
---@return boolean valid
function AssetCollection:areSourceFilesChanged(files, cacheInfo, invalidateCallback)
	tclear(pathMap)
	invalidateCallback = invalidateCallback or returnTrue

	-- Check the modified times
	local modifiedTimes = cacheInfo.modifiedTimes
	for i = 1, #files do
		local filepath = files[i]

		local oldModifiedTime = modifiedTimes[filepath]
		if not oldModifiedTime and invalidateCallback(filepath, "added") then
			-- File added (requested in `files` but not found in the cache)
			return false
		else
			local fileInfo = love.filesystem.getInfo(filepath, "file")
			if not fileInfo and invalidateCallback(filepath, "missing") then
				-- File missing (not found in the project)
				return false
			end

			if oldModifiedTime ~= fileInfo.modtime and invalidateCallback(filepath, "modified") then
				-- File modified (different modified time)
				return false
			end
		end

		-- Add it to the path map
		pathMap[filepath] = true
	end

	-- Now check if all included files in the last cache are the same as the currently requested files
	for cachedFilepath, oldModifiedTime in pairs(modifiedTimes) do
		if not pathMap[cachedFilepath] then
			if invalidateCallback(cachedFilepath, "removed") then
				-- A cached asset is not included in the current request
				return false
			else
				-- Check if the cached asset was modified
				local fileInfo = love.filesystem.getInfo(cachedFilepath, "file")
				if not fileInfo and invalidateCallback(cachedFilepath, "missing") then
					-- File missing (not found in the project)
					return false
				end

				if oldModifiedTime ~= fileInfo.modtime and invalidateCallback(cachedFilepath, "modified") then
					-- File modified (different modified time)
					return false
				end
			end
		end
	end

	-- Not modified, return true if all cache files exist
	return self:doCacheFilesExist(cacheInfo)
end

---Removes any file associated with the cache, but not the cache info.
---To remove cache info, call `Loader.setCacheInfo(filepath, nil)`.
---@param cacheInfo Adore.Loader.CacheInfo
function AssetCollection:removeCacheFiles(cacheInfo)
	local cacheFiles = cacheInfo.cacheFiles
	if cacheFiles then
		for i = 1, #cacheFiles do
			love.filesystem.remove(cacheFiles[i])
		end
	end
end

local TINYTOML_PARSE_ARGS = {load_from_string = true}

---Returns the cache info for the filepath
---@param filepath string
---@return Adore.Loader.CacheInfo?
function AssetCollection:getCacheInfo(filepath)
	local cacheFilePath = self:getCachePath(filepath, "_cacheinfo.toml")
	if love.filesystem.getInfo(cacheFilePath) then
		local contents = love.filesystem.read("string", cacheFilePath)
		---@type Adore.Loader.CacheInfo
		local t = TinyTOML.parse(contents, TINYTOML_PARSE_ARGS)
		if t.CACHE_VERSION == CACHE_VERSION then
			-- It's valid, return it
			return t
		end
	end
	-- No info
	return nil
end

---Sets the cache info for the filepath
---@param filepath string
---@param info Adore.Loader.CacheInfo?
function AssetCollection:setCacheInfo(filepath, info)
	local cacheFilePath = self:getCachePath(filepath, "_cacheinfo.toml")
	if info then
		-- Write the cache info
		AssetCollection:ensureCacheDir()
		info.CACHE_VERSION = CACHE_VERSION
		local encoded = TinyTOML.encode(info)
		local file = love.filesystem.newFile(cacheFilePath)
		file:open("w")
		file:write(encoded)
		file:close()
	else
		-- Remove the cache info
		love.filesystem.remove(cacheFilePath)
	end
end

---Adds an already created asset into this AssetCollection and returns its ID.
---Don't add an already existing asset.
---@param asset table | userdata
---@param path string?
---@return AssetID id
function AssetCollection:register(asset, path)
	local id = self.nextId
	self.nextId = id + 1
	self.assets[id] = asset
	if path then
		self.idToPath[id] = path
		self.pathToId[path] = id
	end
	return id
end

---(Loads if needed, and) returns the asset and asset ID at the path
---@param path string
---@param ... unknown
---@return any asset
---@return AssetID id
function AssetCollection:get(path, ...)
	-- Check for existing path
	local id = self.pathToId[path]
	if not id then
		-- Doesn't exist; create it
		if path:match("@") then
			-- Requesting a sub-asset ("asset.png@1")
			-- If the parent doesn't exist, create it
			-- If not, the sub-asset doesn't exist
			local filepath = path:match("(.*)@")
			if not self.pathToId[filepath] then
				-- Parent exists, create it and try again
				local asset = self:handler(filepath, ...)
				self:register(asset, filepath)
				return self:get(path, ...)
			else
				-- Parent asset exists, sub-asset doesn't
				error(("Sub-asset '%s' doesn't exist on %s"):format(path, self.TYPE))
			end
		else
			-- Create this asset
			local asset = self:handler(path, ...)
			return asset, self:register(asset, path)
		end
	else
		-- Returns the existing ID
		return self.assets[id], id
	end
end

---Returns an already existing asset and asset ID, but does not try to load it
---@param path string
---@return any? asset
---@return AssetID? id
function AssetCollection:has(path)
	-- Check for existing path
	local id = self.pathToId[path]
	if id then
		-- Returns the existing ID
		return self.assets[id], id
	end
	return nil, nil
end

---Reloads an asset from its path
---@param path string
---@param ... unknown
---@return boolean success
---@return string? err
function AssetCollection:reload(path, ...)
	-- Check for existing path
	local id = self.pathToId[path]
	if not id then
		return false, "Asset does not have a path association"
	end

	local oldAsset = self.assets[id]
	if not oldAsset then
		return false, "Asset doesn't exist"
	end

	local reloader = self.reloader
	if not reloader then
		-- By default, we destroy and replace the asset
		local newAsset = self:handler(path, ...)
		self.assets[id] = newAsset
		self:destructor(oldAsset, newAsset)
	else
		-- Otherwise, the reloader should handle it
		reloader(self, path)
	end

	return true
end

---Gets the AssetID and path for a given asset
---@param asset any
---@return AssetID? id
---@return string? path
function AssetCollection:getAssetPath(asset)
	local assets = self.assets
	for i = 1, #assets do
		local curr = assets[i]
		if curr == asset then
			-- `i` is the AssetID
			return i, self.idToPath[i]
		end
	end
	-- Not found
end

function AssetCollection:__tostring()
	return ("AssetCollection (%s)"):format(self.TYPE)
end

return AssetCollection
