local PKG_NAME = ...
---@class AdoreInit
local Adore = {}
Adore.PATH = PKG_NAME

-- The following are globals that can be set **before** you load Adore
-- * Setting to `nil` makes the option use the default value
if false then
	---Enable/disable FFI types.
	---**Default:** `true` on desktop, `false` anywhere else.
	---@type boolean?
	ADORE_FORCE_FFI = nil
end

local Libraries = require(PKG_NAME..".lib")

local allLazyLoaders = {
	Nodes = false,
	Resources = false,
	Common = false,
	Libraries = Libraries
}

---Finds a type somewhere in Adore, in case the developer mistyped something
---@param type string
---@param exclude string
---@return any
local function fallbackToOthers(type, exclude)
	for category, loader in pairs(allLazyLoaders) do
		if category ~= exclude then
			local val = loader[type]
			if val then
				-- Found it under this category, tell the user
				print(debug.traceback(
					("[Adore] Found '%s' in category 'Adore.%s' instead of 'Adore.%s'; you should change it"):format(type, category, exclude),
					3
				))
				return val
			end
		end
	end
	error(("Type '%s' is not found inside of Adore"):format(type))
end


---A Library is a dependency that does not rely on Adore, but is used within Adore.
---They may be outdated.
---@generic T
---@param name `T` | Adore.Libraries
---@return T
Adore.Libraries = function(name)
	return Libraries[name] or fallbackToOthers(name, "Libraries")
end

do
	-- Load submodules, and throw a good error if someone forgets
	-- (done before doing relative requires, because they sometimes act weird)
	local submoduleNames = {
		"RTA",
		"Expression",
		-- The following are not submodules, they just act weird with relative requires:
		"InputField",
	}
	local missingSubmoduleMessage = [[
Failed to load submodule '%s' at path '%s'.
Did you forget to include the submodules in your Adore clone?

To fix, run this in your project root: git submodule update --init --recursive

...if you clone next time: git clone <url> --recursive
]]

	for i = 1, #submoduleNames do
		local submoduleName = submoduleNames[i]
		if not pcall(Adore.Libraries, submoduleName) then
			-- Failed require
			error(missingSubmoduleMessage:format(submoduleName, PKG_NAME.."."..Libraries._paths[submoduleName]))
		end
	end
end

local Nodes = require(PKG_NAME..".nodes")
local Resources = require(PKG_NAME..".data")
local Common = require(PKG_NAME..".common")

allLazyLoaders.Nodes, allLazyLoaders.Resources, allLazyLoaders.Common =
	Nodes, Resources, Common

---A Node is an instanced object that is used in the scene tree
---@generic T
---@param name `T` | Adore.Nodes
---@return T
Adore.Nodes = function(name)
	return Nodes[name] or fallbackToOthers(name, "Nodes")
end

---A Resource is an instanced object that other objects depend on
---@generic T
---@param name `T` | Adore.Resources
---@return T
Adore.Resources = function(name)
	return Resources[name] or fallbackToOthers(name, "Resources")
end

---Collections of behaviors and primitives commonly found between objects
---@generic T
---@param name `T` | Adore.Common
---@return T
Adore.Common = function(name)
	return Common[name] or fallbackToOthers(name, "Common")
end

---@type Adore.Loader # The asset loader, which prevents duplicating assets in memory
Adore.Loader = Adore.Common("Adore.Loader")
require(PKG_NAME..".loader.textureloader")
require(PKG_NAME..".loader.imageloader")
require(PKG_NAME..".loader.sheetloader")
require(PKG_NAME..".loader.fontloader")

---@class Adore.Builder: AdoreInit
---@field list {func: (fun(root: RootNode, adore: AdoreInit, ...): RootNode), args: table}[]
local AdoreBuilderMT = {__index = Adore}

---Calls a function, with either the `RootNode` or former function's return value passed into it.
---It should return a value; if not, it will use the passed parameter as the return value.
---@param func (fun(root: RootNode, adore: AdoreInit, ...): (RootNode | any)?) | table
---@param ... unknown
---@return Adore.Builder
function Adore:with(func, ...)
	if self == Adore then
		self = setmetatable({
			list = {}
		}, AdoreBuilderMT)
	end
	---@cast self Adore.Builder

	local args
	if select("#", ...) > 0 then
		args = {...}
	end

	self.list[#self.list+1] = {
		func = func,
		args = args
	}

	return self
end

---Creates the RootNode, with the former methods if they exist. There can only be one at any time.
---First parameter is the options for the RootNode; most of the graphical options (and the physics world) are here.
---Second parameter is the default Theme; pass `nil` to use the built-in Theme.
---* There's significant overlap with `Viewport.Options`
---* Some features rely on Love2D's set functions
--- * `love.keyboard.setKeyRepeat` is one function that should be set to `true` if you want `ShortcutContext`s to run on repeats
---@param rootOptions RootNode.Options?
---@param defaultTheme Theme? # Optional default theme; will use the bundled default theme if nil
---@return RootNode root
function Adore:build(rootOptions, defaultTheme)
	local root

	do
		-- Create the RootNode
		defaultTheme = defaultTheme or Adore.Resources("DefaultTheme")()

		if rootOptions and rootOptions.physicsWorld then
			-- Sets the default love.World.
			-- By default, most physics nodes will not use it, as they'll get the physics world from the Viewport they belong to.
			-- It's used for generic raycasts, however, you should still pass in the world you want.
			Adore.Nodes("Physical2d").setWorld(rootOptions.physicsWorld)
		end

		root = Adore.Nodes("RootNode")(rootOptions, defaultTheme)
	end

	if self ~= Adore then
		-- Using a builder to initialize the RootNode
		---@cast self Adore.Builder
		local list = self.list

		for i = 1, #list do
			-- Call every function, and set the `RootNode` if needed
			local item = list[i]
			local func = item.func
			local args = item.args

			local val
			if args then
				val = func(root, Adore, unpack(item.args))
			else
				val = func(root, Adore)
			end

			if val then
				root = val
			end
		end
	end

	return root
end

do
local deviceMap = {
	["OS X"] = "desktop",
	Windows = "desktop",
	Linux = "desktop",
	Android = "mobile",
	iOS = "mobile",

	--- love.js (https://github.com/Davidobot/love.js/issues/74)
	web = "web",
}

---Returns the device type of this system.
---For strange systems, "unknown" will be returned.
---@return "desktop" | "mobile" | "web" | "unknown"
function Adore.getDeviceType()
	local os = love.system.getOS()
	return deviceMap[os] or "unknown"
end
end

return Adore
