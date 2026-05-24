Adore targets Windows, Linux, and web/love.js. Contributions for other platforms are welcome.

The following is a list of all known incompatibilities on certain platforms.

## Web
* Anything added by LuaJIT
	* table.new, table.clear, string.buffer, goto, etc.
		* Use `Adore.Common("Structures").tableClear` and others instead
	* `bit` is replaced with a Lua implementation (`numberlua`)
* ObjectSaver
* ShaderStack
* AtlasLoader (and the RTA library)
	* Bake your atlases outside of Adore, and use SheetLoader in dynamic mode instead
* `love.textinput` does not send events correctly
