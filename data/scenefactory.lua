---@type AdoreInit
local Adore = require ""
local Object = Adore.Resources("Object")
local Node = Adore.Nodes("Node")

---A convenient wrapper for building scenes with scripts
---@class SceneFactory: Object
---@overload fun(func: SceneFunction?, source: string?): SceneFactory
local SceneFactory = Object:extend()
SceneFactory.CLASS_NAME = "SceneFactory"

---@alias SceneFunction
---| fun(parent: Node?, ...): Node

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
---@return Node node
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
local ignoreSubScenes = function(node, owner)
	if node._sceneFilePath ~= nil then
		node._owner = owner
		return false
	end
	return true
end

---Instantiates this Scene underneath `parent`. Returns the starting `Node` that was instantiated.
---@param parent Node?
---@param ... unknown # Parameters that will be passed to the :create() function
---@return Node instanced
function SceneFactory:instantiate(parent, ...)
	-- Overload :create() instead
	local node = self:build(...)
	node._sceneFilePath = self.source

	if rawget(self, "build") then
		-- This is a SceneFactory with a custom build function
		-- Set "_owner" on all Nodes
		node:traverseDownExcludeSelf(setOwner, ignoreSubScenes, node)
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
