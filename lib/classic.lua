--
-- classic
--
-- Copyright (c) 2014, rxi
--
-- This module is free software; you can redistribute it and/or modify it under
-- the terms of the MIT license. See LICENSE for details.
--

-- WHEN USING ADORE:
-- Use this if you don't want ClassDB metadata
-- Otherwise, use ./data/object.lua, which is basically the same

---@class SimpleObject
---@field super self
---@overload fun(): Object
local SimpleObject = {}
SimpleObject.__index = SimpleObject

---@generic T
---@param self T
---@param ... unknown
function SimpleObject:new(...)
end

---@generic T
---@param self T
---@return unknown
function SimpleObject:extend()
	local cls = {}
	for k, v in pairs(self) do
		if k:find("__") == 1 then
			cls[k] = v
		end
	end
	cls.__index = cls
	cls.super = self
	setmetatable(cls, self)
	return cls
end

---@generic T
---@param self T
function SimpleObject:implement(...)
	for _, cls in pairs({ ... }) do
		for k, v in pairs(cls) do
			if self[k] == nil and type(v) == "function" then
				self[k] = v
			end
		end
	end
end

function SimpleObject:is(T)
	local mt = getmetatable(self)
	while mt do
		if mt == T then
			return true
		end
		mt = getmetatable(mt)
	end
	return false
end

function SimpleObject:__tostring()
	return "SimpleObject"
end

function SimpleObject:__call(...)
	local obj = setmetatable({}, self)
	obj:new(...)
	return obj
end

return SimpleObject
