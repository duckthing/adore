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
		self.build = func
	end

	---@type string? # What path should the output be tagged as? Assigned in `:instantiate()`
	self.source = source
end

---This function should be overloaded to define a factory's output
---@param ... unknown
---@return Node node
function SceneFactory:build(...)
	local node = Node()
	node.name = "SceneFactory Output"
	return node
end

---Instantiates this Scene underneath `parent`. Returns the starting `Node` that was instantiated.
---@param parent Node?
---@param ... unknown # Parameters that will be passed to the :create() function
---@return Node instanced
function SceneFactory:instantiate(parent, ...)
	-- Overload :create() instead
	local node = self:build(...)
	node._adoreSource = self.source
	if parent then
		parent:addChild(node)
	end
	return node
end

---Returns a function that can be called to instantiate a SceneFactory's contents
---@return SceneFunction
function SceneFactory:asFunction()
	local func = self.instantiate
	return function(...)
		return func(self, ...)
	end
end

return SceneFactory
