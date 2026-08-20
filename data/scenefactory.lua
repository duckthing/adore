---@type AdoreInit
local Adore = require ""
local Object = Adore.Resources("Object")
local Node = Adore.Nodes("Node")
local tclear = Adore.Common("Structures").tableClear

---A convenient wrapper for building scenes with scripts
---@class SceneFactory: Object
---@overload fun(func: SceneFunction?, source: string?): SceneFactory
local SceneFactory = Object:extend()
SceneFactory.CLASS_NAME = "SceneFactory"
---@type {[string]: true} # A map of sources to `true`; used to prevent infinite scene loops
SceneFactory._currentSources = {}

---@alias SceneFunction
---| fun(parent: Node?, ...): Node?

---@param func SceneFunction?
---@param source string? # What path should the output be tagged as?
function SceneFactory:new(func, source)
	SceneFactory.super.new(self)

	if func then
		-- Drop 'self'
		self.build = function(_, ...) return func(...) end
	end

	---@type string? # What path should the output be tagged as? Assigned in `:instantiate()`
	self.source = nil

	---@type {[string]: true} # Filepaths this SceneFactory relies on
	self._dependencyMap = {}

	---@type boolean # If this SceneFactory should update its dependency list
	self._shouldUpdateDependencies = true

	if source then
		-- Try to get the extension
		local extension = source:match("^.*%.(.*)")
		if extension and extension == "lua" then
			-- It's a Lua filepath, leave as is
			self.source = source
		else
			-- Convert this into a formal filepath
			self.source = source:gsub("%.", "/")..".lua"
		end
	end
end

---This function should be overloaded to define a factory's output
---@param ... unknown
---@return Node? node
function SceneFactory:build(...)
	local node = Node()
	node.name = "SceneFactory Output"
	return node
end

do
---@param node Node
---@param owner Node
local setOwner = function(node, owner) node._owner = owner end
---@param node Node
---@param owner Node
local ignoreSubScenes = function(node, owner)
	if node._sceneFilePath ~= nil then
		node._owner = owner
		return false
	end
	return true
end

local function noop() end
---@param node Node
---@param owner Node
---@param dependencies {[string]: true}
local ignoreSubScenesAndSetDependencies = function(node, owner, dependencies)
	if node._sceneFilePath ~= nil then
		node._owner = owner
		dependencies[node._sceneFilePath] = true
		return false
	end
	return true
end

do
local otherDeps = {}
---Updates the dependencies list in this SceneFactory using an instanced scene
---@param instancedScene Node
function SceneFactory:updateDependencies(instancedScene)
	local dependencies = self._dependencyMap
	tclear(dependencies)
	instancedScene:traverseDownExcludeSelf(noop, ignoreSubScenesAndSetDependencies, instancedScene, dependencies)

	local ObjectLoader = Adore.Loader.getCollection("ObjectLoader")
	local source = self.source
	if source and not ObjectLoader:has(source) then
		-- Also registers this SceneFactory (which is required for the following to work)
		ObjectLoader:register(self, source)
	end

	-- Get the dependencies from other loaded scenes
	for path, _ in pairs(dependencies) do
		local dep = ObjectLoader:has(path)
		if dep then
			---@cast dep SceneFactory
			for otherPath, _ in pairs(dep._dependencyMap) do
				otherDeps[otherPath] = true
			end
		end
	end

	-- Copy the paths from them
	for otherPath, _ in pairs(otherDeps) do
		dependencies[otherPath] = true
	end

	tclear(otherDeps)
end
end

---Instantiates this Scene underneath `parent`. Returns the starting `Node` that was instantiated.
---@param parent Node?
---@param ... unknown # Parameters that will be passed to the :create() function
---@return Node? instanced
function SceneFactory:instantiate(parent, ...)
	-- Overload :build() instead
	local source = self.source
	if source then
		if SceneFactory._currentSources[source] then
			-- Prevent the infinite loop
			print(("[Adore.SceneFactory] Prevented infinite loop from loading '%s'"):format(source))
			return
		end

		-- Mark that we're here right now
		SceneFactory._currentSources[source] = true
	end

	local node = self:build(...)

	if source then
		-- Done, unmark
		SceneFactory._currentSources[source] = nil

		if node then
			local ObjectLoader = Adore.Loader.getCollection("ObjectLoader")
			if not ObjectLoader:getModifiedSceneProperties(source) then
				-- Update what is considered a "default" property to whatever came from this scene
				ObjectLoader:updateModifiedSceneProperties(node, source)
			end
			-- Set the source file path on the Node as our source
			node._sceneFilePath = source
		end
	end

	if not node then return end

	if rawget(self, "build") then
		-- This is a SceneFactory with a custom build function
		-- Set "_owner" on all Nodes
		node:traverseDownExcludeSelf(setOwner, ignoreSubScenes, node)
	end

	if self._shouldUpdateDependencies then
		-- Update dependencies
		self._shouldUpdateDependencies = true
		self:updateDependencies(node)
	end

	if parent then
		parent:addChild(node)
	end
	return node
end
end

---Returns a function that can be called to instantiate a SceneFactory's contents
---@return SceneFunction
function SceneFactory:asSceneFunction()
	local func = self.instantiate
	return function(...)
		return func(self, ...)
	end
end

return SceneFactory
