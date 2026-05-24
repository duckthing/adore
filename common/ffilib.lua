-- Returns nil if ffi isn't found
local success, lib = pcall(require, "_G.ffi")
if success then return lib end
return nil
