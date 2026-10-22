local Lurker

---Overrides for certain parts of the RootNode (like `RootNode:mousemoved()`)
---@type {[string]: fun(self: RootNode, ...)}
local METHOD_OVERRIDES = {
	focus = function(self, focused)
		self:focus(focused)

		if focused then
			local changed = Lurker.scan()
			if #changed > 0 and Lurker.lasterrorfile then
				local f = Lurker.lasterrorfile
				Lurker.lasterrorfile = nil
				Lurker.hotswapfile(f)
			end
		end
	end
}

local function lurkerPostswap(f)
	local modname = Lurker.modname(f)
	local m = require(modname)
	---@cast m Object
	if not (type(m) == "table" and type(m.CLASS_NAME) == "string" and type(m.getClassDBEntry) == "function") then
		-- It's not an Object, ignore this
		return
	end
	-- This updates the entry
	m:getClassDBEntry()
end

---@param originalRoot RootNode
---@param lurkerParam table | string
local function createLurkerCompat(originalRoot, lurkerParam)
	if type(lurkerParam) == "string" then
		-- In case the module path was passed, load it
		local success, moduleOrErr = pcall(require, lurkerParam)
		if success then
			lurkerParam = moduleOrErr
		else
			error(("Failed to load Lurker at path '%s': %s"):format(lurkerParam, moduleOrErr))
		end
	end
	---@cast Lurker table

	assert(type(lurkerParam) == "table" and type(lurkerParam.scan) == "function", "Lurker was not set correctly")
	lurkerParam.postswap = lurkerPostswap
	Lurker = lurkerParam

	local defaultCallbacks = originalRoot._defaultCallbacks

	-- Add any overrides we have
	for k, v in pairs(METHOD_OVERRIDES) do
		local existing = defaultCallbacks[k]
		if not existing then
			-- Not there, set it
			defaultCallbacks[k] = v
		else
			-- Existing method, wrap around it
			defaultCallbacks[k] = function(...)
				v(...)
				existing(...)
			end
		end
	end
end

return createLurkerCompat
