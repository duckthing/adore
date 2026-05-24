-- Returns either LuaJIT's bit library or the plain Lua fallback
local success, lib = pcall(require, "_G.bit")
if success then return lib end
return (require "lib.numberlua").bit
