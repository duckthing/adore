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
	---Enable/disable culling for Node2d
	---@type boolean?
	ADORE_NODE2D_CULL = nil
end

local Libraries = require(PKG_NAME..".lib")

local allLazyRequires = {
	Nodes = false,
	Resources = false,
	Common = false,
	Internal = false,
	User = false,
	Libraries = Libraries
}

---Finds a type somewhere in Adore, in case the developer mistyped something
---@param type string
---@param exclude string?
---@return any
local function fallbackToOthers(type, exclude)
	for category, loader in pairs(allLazyRequires) do
		if loader and category ~= exclude then
			local val = loader[type]
			if val then
				-- Found it under this category
				if exclude then
					-- Print it out if we've checked a category already
					print(debug.traceback(
						("[Adore] Found '%s' in category 'Adore.%s' instead of 'Adore.%s'; you should change it"):format(type, category, exclude),
						3
					))
				end
				return val
			end
		end
	end
	error(("Class '%s' is not found inside of Adore\nIf it's your class, add it in 'Adore.addUserPaths' before performing that action (such as in 'love.load')"):format(type))
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
	-- (also good for loading any library that acts strange when lazy loaded)
	local submoduleNames = {
		"Expression",
		"InputField",
		-- RTA is excluded due to issues on web
	}

	local missingSubmoduleMessage
	if love.filesystem.isFused() then
		-- Fused message
		missingSubmoduleMessage = [[
Failed to load submodule '%s' at path '%s'.

Some automatic build tools don't include ignored git files (submodules).
If using 'makelove', add "./adore/*" to the 'love_files' array.
]]
	else
		-- Unfused message
		missingSubmoduleMessage = [[
Failed to load submodule '%s' at path '%s'.
Did you forget to include the submodules in your Adore clone?

To fix, run this in your project root: git submodule update --init --recursive

...if you clone next time: git clone <url> --recursive
]]
end

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
local Internal = require(PKG_NAME..".data.internal")
local User = require(PKG_NAME..".data.userspecified")

allLazyRequires.Nodes, allLazyRequires.Resources, allLazyRequires.Common, allLazyRequires.Internal, allLazyRequires.User =
	Nodes, Resources, Common, Internal, User

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

---Behaviors and objects that are not intended to be used directly by developers.
---Mainly used for deserialization later.
---@generic T
---@param name `T` | Adore.Internal
---@return T
Adore.Internal = function(name)
	return Internal[name] or fallbackToOthers(name, "Internal")
end

---User-specified paths
---@generic T
---@param name `T` | Adore.Nodes | Adore.Resources | Adore.Common | Adore.Libraries
---@return T
Adore.User = function(name)
	return User[name] or fallbackToOthers(name, "User")
end

---Everything that can be loaded
---@generic T
---@param name `T` | Adore.Nodes | Adore.Resources | Adore.Common | Adore.Libraries
---@return T
Adore.Any = function(name)
	return fallbackToOthers(name)
end

---Searches for any class name matches in non-user paths
---@param className string
---@return boolean exists
---@return string? categoryName
local function hasClassName(className)
	for categoryName, lazyRequire in pairs(allLazyRequires) do
		---@diagnostic disable-next-line: cast-type-mismatch
		---@cast lazyRequire LazyRequire
		local namesToPaths = lazyRequire._paths
		if namesToPaths[className] then return true, categoryName end
	end
	return false
end

---An array containing every class name in Adore
---@type string[]
local allClassNames = {}

---Whether the array of all class names should be updated
---@type boolean
local shouldReloadClasses = true

---Adds user-specified paths so that internal Adore operations can find them.
---
---For example, loading a custom `Player` class from a PackedScene requires
---Adore to know where the class is.
---@param paths {[string]: string | false}
function Adore.addUserPaths(paths)
	shouldReloadClasses = true
	local userPaths = User._paths
	for className, path in pairs(paths) do
		if path == false then
			-- Remove a path
			userPaths[className] = nil
			User[className] = nil
		else
			-- Add it
			local exists, inCategory = hasClassName(className)
			if exists and inCategory ~= "User" then
				error(("Can't add user path for class name '%s'; already exists in category '%s'"):format(className, inCategory))
			end
			userPaths[className] = path
		end
	end
end

---Returns a read-only array containing every class name in Adore
---@return string[] classNames
function Adore.getClassNames()
	if shouldReloadClasses then
		-- Clear the array
		for i = #allClassNames, 1, -1 do
			allClassNames[i] = nil
		end

		-- Now get every class name
		local i = 1
		for _, lazyRequire in pairs(allLazyRequires) do
			---@diagnostic disable-next-line: cast-type-mismatch
			---@cast lazyRequire LazyRequire
			for className, _ in pairs(lazyRequire._paths) do
				allClassNames[i] = className
				i = i + 1
			end
		end
	end
	return allClassNames
end

---Returns an array of all classes which inherit from this class, including the base class
---@param baseClassName string
---@return string[] descendants
function Adore.getClassDescendants(baseClassName)
	local classNames = Adore.getClassNames()
	local descendants = {baseClassName}
	local BaseClass = Adore.Any(baseClassName)

	for i = 1, #classNames do
		local currClassName = classNames[i]
		local Class = Adore.Any(currClassName)
		if type(Class) == "table" and Class.is and Class:is(BaseClass) and Class ~= BaseClass then
			descendants[#descendants+1] = currClassName
		end
	end

	return descendants
end

---Returns an array of all super classes from this base class
---@param baseClassName string
---@return string[] ancestors
function Adore.getClassAncestors(baseClassName)
	local ancestors = {baseClassName}
	local BaseClass = Adore.Any(baseClassName)

	local CurrClass = BaseClass.super
	while CurrClass do
		ancestors[#ancestors+1] = CurrClass.CLASS_NAME
		CurrClass = CurrClass.super
	end

	return ancestors
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

---@return Adore.Builder
local function createBuilder()
	local builder = setmetatable({
		list = {},
		---@type Adore.ProjectConfig
		projectConfig = nil,
		---@type boolean # If we should write the Project Config
		shouldWriteConfig = false,
	}, AdoreBuilderMT)
	---@cast builder Adore.Builder
	return builder
end

do
---@type {[string]: fun(contents: string): Adore.ProjectConfig}
local configReaders = {
	json = function(contents)
		local JSON = Adore.Libraries("JSON")
		local config, err = JSON.decode(contents)
		if not config then
			error(("Errored while reading config: %s"):format(err))
		end
		return config
	end,
	toml = function(contents)
		local TinyTOML = Adore.Libraries("TinyTOML")
		local config = TinyTOML.parse(contents, {load_from_string = true})
		return config
	end
}

---Sets the configuration file path, which makes the parameters in
---`:builder` unnecessary.
---* `Adore:config("path/config.toml"):build()`
---* `Adore:config("path/config.json"):build()`
---* etc.
---@return Adore.Builder
function Adore:config(path)
	if self == Adore then
		self = createBuilder()
	end
	---@cast self Adore.Builder

	local LuaPath = Adore.Libraries("LuaPath")
	local extension = LuaPath:extension_name(path)

	local reader = configReaders[extension]
	if not reader then
		error(("Invalid config extension '%s'"):format(extension))
	end

	---@type Adore.ProjectConfig
	local projectConfig
	local shouldWrite = false

	-- Get the Project Config
	if love.filesystem.getInfo(path, "file") then
		-- The file exists
		local contents, err = love.filesystem.read(path)
		if not contents then
			error(("Failed to read contents at '%s':\n%s"):format(path, err))
		end

		projectConfig = reader(contents)
	else
		-- Create the default config (and write it to disk later)
		---@type Adore.ProjectConfig
		local ProjectConfig = require(PKG_NAME..".data.projectconfig")
		projectConfig = ProjectConfig()
		shouldWrite = true
	end
	projectConfig.path = path
	projectConfig.extension = extension

	self.projectConfig = projectConfig
	self.shouldWriteConfig = shouldWrite

	return self
end
end

---Calls a function, with either the `RootNode` or former function's return value passed into it.
---It should return a value; if not, it will use the passed parameter as the return value.
---@param func (fun(root: RootNode, adore: AdoreInit, ...): (RootNode | any)?) | table
---@param ... unknown
---@return Adore.Builder
function Adore:with(func, ...)
	if self == Adore then
		self = createBuilder()
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

	local config = self.projectConfig
	if config then
		-- The configuration exists
		if config.userPaths then
			Adore.addUserPaths(config.userPaths)
		end
	end

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
		root._projectConfig = config
		if self.shouldWriteConfig and config then
			root:writeConfiguration()
		end
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
	Web = "web",
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
