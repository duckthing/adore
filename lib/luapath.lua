--[[
-- Author: Alexey Melnichuk <alexeymelnichuck@gmail.com>
-- Copyright (C) 2013-2016 Alexey Melnichuk <alexeymelnichuck@gmail.com>
-- This file is part of lua-path library.

Copyright (C) 2013-2016 Alexey Melnichuk.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT
SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
OR OTHER DEALINGS IN THE SOFTWARE. --]]

local package = require "package"
local string = require "string"

local DIR_SEP = package.config:sub(1,1)
local IS_WINDOWS = DIR_SEP == '\\'

---@class LuaPath
local PATH = {}

PATH.DIR_SEP = DIR_SEP
PATH.IS_WINDOWS = IS_WINDOWS

---Removes the quotations around a filepath
---`"/some/file.lua"` => `/some/file.lua`
---@param P string
---@return string
function PATH:unquote(P)
	if P:sub(1,1) == '"' and P:sub(-1,-1) == '"' then
		return (P:sub(2,-2))
	end
	return P
end

---Adds quotations around a filepath
---`/some/file.lua` => `"/some/file.lua"`
---@param P string
---@return string
function PATH:quote(P)
	if P:find("%s") then
		return '"' .. P .. '"'
	end
	return P
end

---Returns `true` if the path ends with a separator
---@param P string
---@return boolean hasSeparator
function PATH:has_dir_end(P)
	return (P:find('[\\/]$')) and true or false
end

---Removes the end separator from a filepath, if there is one
---`"/some/folder/"` => `'/some/folder'`
---@param P string
---@return string
function PATH:remove_dir_end(P)
	return (P:gsub('[\\/]+$', ''))
end

---Adds the end separator from a filepath, if there isn't one
---`"/some/folder"` => `"/some/folder/"`
---@param P string
---@return string
function PATH:ensure_dir_end(P)
	return self:remove_dir_end(P) .. self.DIR_SEP
end

---Returns `true` if the first two characters of the path are equal to two separators
---`"//some/folder"` => `true`
---`"/some/folder"` => `false`
---@param P string
---@return boolean
function PATH:is_unc(P)
	return (P:sub(1, 2) == (self.DIR_SEP .. self.DIR_SEP)) and P and true or false
end

---Replaces all backward slashes with forward slashes
---`"\some\folder"` => `"/some/folder"`
---@param P string
---@return string
function PATH:normalize_sep(P)
	return (P:gsub('\\', self.DIR_SEP):gsub('/', self.DIR_SEP))
end

PATH.normalize_sep = PATH.normalize_sep

---Cleans a path by collapsing up-level paths, redundant separators, and up-level references
---* `"\..\.\path//to\folder.txt"` => `"/path/to/folder.txt/"`
---* `"/a/fred/../b"`, `"/a//b"`, `"/a\\b"`, `"/a/./b"` all normalize to `"/a/b"`
---@param P string
---@return string
function PATH:normalize(P)
	P = self:normalize_sep(P)

	local is_unc = self:is_unc(P)
	while true do -- `/./` => `/`
		local n P,n = string.gsub(P, DIR_SEP .. '%.' .. DIR_SEP, DIR_SEP)
		if n == 0 then break end
	end
	while true do -- `//` => `/`
		local n P,n = string.gsub(P, DIR_SEP .. DIR_SEP, DIR_SEP)
		if n == 0 then break end
	end
	P = string.gsub(P, DIR_SEP .. '%.$', '')
	if (not IS_WINDOWS) and (P == '') then P = '/' end

	if is_unc then P = DIR_SEP .. P end

	local root, path = nil, P
	if is_unc then
		root, path = self:split_root(P)
	end

	path = self:ensure_dir_end(path)
	while true do
		local first, last = string.find(path, DIR_SEP .. "[^".. DIR_SEP .. "]+" .. DIR_SEP .. '%.%.' .. DIR_SEP)
		if not first then break end
		path = string.sub(path, 1, first) .. string.sub(path, last+1)
	end
	P = path

	if root then -- unc
		assert(is_unc)
		P = P:gsub( '%.%.?' .. DIR_SEP , '')
		P = DIR_SEP .. DIR_SEP .. self:join(root, P)
	elseif self.IS_WINDOWS then
		-- c:\..\foo => c:\foo
		-- \..\foo => \foo
		local root, path = self:split_root(P)
		if root ~= '' or P:sub(1,1) == DIR_SEP then
			path = path:gsub( '%.%.?' .. DIR_SEP , '')
			P = self:join(root, path)
		end
	end

	if self.IS_WINDOWS and #P <= 3 and P:sub(2,2) == ':' then -- c: => c:\ or c:\ => c:\
		if #P == 2 then return P .. self.DIR_SEP end
		return P
	end

	if (not self.IS_WINDOWS) and (P == DIR_SEP) then return '/' end
	return self:remove_dir_end(P)
end

PATH.normalize = PATH.normalize

function PATH:join_(P1, P2)
	local ch = P2:sub(1,1)
	if (ch == '\\') or (ch == '/') then
		return self:remove_dir_end(P1) .. P2
	end
	return self:ensure_dir_end(P1) .. P2
end

---Join one or more path components
---* If any component is an absolute path, all previous components are thrown away, and joining continues
---* If last parameter is empty string then result path will have trailing path name separator
---@param ... string
---@return string
function PATH:join(...)
	local t,n = {...}, select('#', ...)
	local r = t[1]
	for i = 2, #t do
		if self:is_full_path(t[i]) then
			r = t[i]
		else
			r = self:join_(r,t[i])
		end
	end
	return r
end

---Split the path into the root and its extension
---* If there is no extension, it returns an empty string
---* `"/some/file.txt"` => `"/some/path"`, `".txt"`
---* `"/some/.passwords"` => `"/some/.passwords"`, `""`
---* `"/some/.file.passwords"` => `"/some/.file"`, `".passwords"`
---@param P string
---@return string root
---@return string extension
function PATH:split_ext(P)
	local s1,s2 = string.match(P,"(.-[^\\/.])(%.[^\\/.]*)$")
	if s1 then return s1,s2 end
	return P, ''
end

---Split the path into its directory and file name
---`"/some/more/folders/file.txt"` => `"/some/more/folders"`, `"file.txt"`
---@param P string
---@return string dirName
---@return string fileName
function PATH:split_path(P)
	return string.match(P,"^(.-)[\\/]?([^\\/]*)$")
end

---Splits the path into its root path and file path
---`"c:\\some\path"` => `"c:"`, `"\some\path"`
---`"/some/more/folders/file.txt"` => `"some"`, `"more/folders/file.txt"`
---@param P string
---@return string root
---@return string
function PATH:split_root(P)
	if self.IS_WINDOWS then
		if self:is_unc(P) then
			return string.match(P, [[^\\([^\/]+)[\]?(.*)$]])
		end
		if string.sub(P,2,2) == ':' then
			return string.sub(P,1,2), string.sub(P,4)
		end
		return '', P
	else
		if string.sub(P,1,1) == '/' then
			return string.match(P,[[^/([^\/]+)[/]?(.*)$]])
		end
		return '', P
	end
end

---Splits a path into a drive and path
---* Always returns `nil` on non-Windows systems
---@param P string
---@return string? drive
---@return string path
function PATH:split_drive(P)
	if self.IS_WINDOWS then
		return self:split_root(P)
	end
	return '', P
end

---Returns the file part of a path
---`"/some/more/folders/file.txt"` => `"file.txt"`
---@param P string
---@return string fileName
function PATH:file_name(P)
	local s1,s2 = self:split_path(P)
	return s2
end

---Returns the directory name of a path
---`"/some/more/folders/file.txt"` => `"/some/more/folders"`
---`"/some/more/folders/"` => `"/some/more/folders"`
---@param P string
---@return string dirName
function PATH:dir_name(P)
	return (self:split_path(P))
end

---Returns the parent directory name of a path
---`"/some/more/folders/file.txt"` => `"/some/more/folders"`
---`"/some/more/folders/"` => `"/some/more"`
---`"/some/more/folders"` => `"/some/more"`
---@param P string
---@return string dirName
function PATH:parent_dir(P)
	return (self:split_path(self:remove_dir_end(P)))
end

---Returns the extension of a path
---* If there is no extension, it returns an empty string
---* `path.splitext("/some/file.txt")` => `".txt"`
---* `path.splitext("/some/.passwords")` => `""`
---* `path.splitext("/some/.file.passwords")` => `".passwords"`
---@param P string
---@return string extension
function PATH:extension(P)
	local s1,s2 = self:split_ext(P)
	return s2
end

---Returns the extension of a path, with the dot excluded
---* If there is no extension, it returns an empty string
---* `path.splitext("/some/file.txt")` => `"txt"`
---* `path.splitext("/some/.passwords")` => `""`
---* `path.splitext("/some/.file.passwords")` => `"passwords"`
---@param P string
---@return string extensionName
function PATH:extension_name(P)
	local s1,s2 = self:split_ext(P)
	if #s2 > 1 then return s2:sub(2) end
	return s2
end

---Return first path part for absolute path
---* On Windows this is drive letter (e.g. "c:\\some\path" => "c:")
---* On *nix this is first directory name (e.g. "/usr/etc" => "/usr")
---@param P string
---@return string root
function PATH:root(P)
	return (self:split_root(P))
end

---Returns `true` if the path contains the root
---`"/folder/file.txt"` => `true`
---`"folder/file.txt"` => `false`
---@param P string
---@return boolean isFull
function PATH:is_full_path(P)
	return (self:root(P) ~= '') and P and true or false
end

local function path_new(o)
	o = o or {}
	for k, f in pairs(PATH) do
		if type(f) == 'function' then
			o[k] = function(...)
				if o == ... then return f(...) end
				return f(o, ...)
			end
		else
			o[k] = f
		end
	end
	return o
end

local function lock_table(t)
	return setmetatable(t,{
		__newindex = function()
			error("Can not change path library", 2)
		end;
		__metatable = "lua-path object";
	})
end

local M = path_new()

local path_cache = setmetatable({}, {__mode='v'})

function M.new(DIR_SEP)
	local is_win, sep

	if type(DIR_SEP) == 'string' then
		sep = DIR_SEP
		is_win = (DIR_SEP == '\\')
	elseif DIR_SEP ~= nil then
		assert(type(DIR_SEP) == 'boolean')
		is_win = DIR_SEP
		sep = is_win and '\\' or '/'
	else
		sep = M.DIR_SEP
		is_win = M.IS_WINDOWS
	end

	if M.DIR_SEP == sep then
		assert(M.IS_WINDOWS == is_win)
		return M
	end

	local o = path_cache[sep]

	if not o then
		o = path_new()
		o.DIR_SEP = sep
		o.IS_WINDOWS = is_win
		path_cache[sep] = lock_table(o)
	end

	return o
end

return lock_table(M)
