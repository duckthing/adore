---@type string
local PKG_NAME = ...
---@type string # It's "path.to.adore", excluding the period at the end
local ADORE_PATH = PKG_NAME:match("^(.*)%.lazyrequire")

local originalRequire = require

---@param path string
local function relRequire(path)
	if not path then
		-- Calling `require` without a parameter returns ADORE_PATH
		return ADORE_PATH
	elseif path:find("_G") == 1 then
		-- Adding _G to the start makes it cancel the relative path
		-- ex: require("_G.bit") equals the original require("bit")
		return originalRequire(path:sub(4))
	elseif path:find(ADORE_PATH) == 1 then
		-- In case we forgot the to remove "adore."
		if not path:find(ADORE_PATH..".lib") then
			print(debug.traceback(
				("[Adore.Internal] Required '%s', remember to remove '%s.' next time"):format(path, ADORE_PATH),
				2
			))
		end
		return originalRequire(ADORE_PATH..path:sub(6))
	end

	if path ~= "" then
		-- Return the relative path
		return originalRequire(ADORE_PATH.."."..path)
	else
		-- Return Adore
		return originalRequire(ADORE_PATH)
	end
end

---@class LazyRequire
---@field _paths {[string]: string}
local LazyRequire = {}
local LazyRequireMT = {
	__index = function(self, k)
		local path = self._paths[k]

		if not path then
			-- Path doesn't exist here, so we don't try to load anything
			return nil
		end

		local oldRequire = require
		local keepOriginal = rawget(self, "_keepOriginalRequire") or false

		if not keepOriginal then
			-- DO change the `require` global, for Adore libraries that expect that
			require = relRequire
		else
			-- Don't change `require` for dependencies that don't expect it.
			-- Change the path instead.
			path = ADORE_PATH.."."..path
			require = originalRequire
		end

		local val = require(path)
		rawset(self, k, val)

		-- Change the `require` global back
		require = oldRequire

		return val
	end
}

---Creates a new `LazyRequire`
---@param paths {[string]: string}
---@param keepOriginalRequire boolean # Should `require` be left unchanged?
local function newLazyRequire(paths, keepOriginalRequire)
	return setmetatable({_paths = paths, _keepOriginalRequire = keepOriginalRequire}, LazyRequireMT)
end

return newLazyRequire
