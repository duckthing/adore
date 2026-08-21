---@type AdoreInit
local Adore = require ""

local SceneFactory = Adore.Resources("SceneFactory")
local ObjectSaver = Adore.Common("ObjectSaver")
local tremove = table.remove
local enqueue = function(arr, val) arr[#arr+1] = val end
local tclear = Adore.Common("Structures").tableClear

---@class TableScene: SceneFactory
---@overload fun(): TableScene
local TableScene = SceneFactory:extend()
TableScene.CLASS_NAME = "TableScene"

function TableScene:new()
	TableScene.super.new(self)
	---@type table[]
	self.table = {}
	---@type boolean # If this TableScene's buffer was consumed
	self._consumed = false
end

local STRING_TO_CONTROL = {
	BEGIN_NODE = 1,
	END_NODE = 2,
	BEGIN_CHILDREN = 3,
	END_CHILDREN = 4,
}

---@param array table[]
---@param node Node
---@param resources any[]
---@param owner Node? # What we're allowed to save with; if not inside of recursion, leave this `nil`
---@param dependencyMap {[string]: true} # A map of filepaths to `true`
local function packInto(array, node, resources, owner, dependencyMap)
	if not node._adorePersist then return end

	if owner then
		if node._owner ~= owner then
			-- Don't save anything not owned by this scene root
			return
		end
	else
		-- This Node is the owner
		owner = node
	end

	if node._sceneFilePath then
		-- This Node came from a scene; mark that scene as a dependency
		dependencyMap[node._sceneFilePath] = true
	end

	enqueue(array, STRING_TO_CONTROL.BEGIN_NODE)
	ObjectSaver.serializeObjectToArray(node, array, resources)

	if #node.children ~= 0 then
		local index = 1
		for i = 1, #node.children do
			local child = node.children[i]
			if child._adorePersist then
				if index == 1 then
					enqueue(array, STRING_TO_CONTROL.BEGIN_CHILDREN)
				end

				index = index + 1
				packInto(array, child, resources, owner, dependencyMap)
			end
		end

		-- If there is at least 1 child that has '_adorePersist', we end the list
		if index > 1 then
			enqueue(array, STRING_TO_CONTROL.END_CHILDREN)
		end
	end
	enqueue(array, STRING_TO_CONTROL.END_NODE)
end

---Packs the node and any children
---@param node Node
function TableScene:pack(node)
	self.table = {}
	self._consumed = false
	local resources = {}
	node._sceneFilePath = nil

	-- Clear dependency map
	local dependencyMap = self._dependencyMap
	tclear(dependencyMap)

	-- Pack the scene tree and the resources
	packInto(self.table, node, resources, nil, dependencyMap)
	self.table[#self.table+1] = resources

	-- Update dependency map with what we just found while packing
	self:updateDependencies()
	self._shouldUpdateDependencies = false
end

local instantiateTree

---@param ontoParent Node?
---@param array table[]
---@param allDeferredProperties {[Node]: {[string]: any}}?
---@param owner Node?
---@return Node? node
function instantiateTree(ontoParent, array, allDeferredProperties, owner)
	local control = tremove(array, 1)
	if control ~= STRING_TO_CONTROL.BEGIN_NODE then return end

	local header, body = tremove(array, 1), tremove(array, 1)

	local err, obj, deferredProperties =
		ObjectSaver.deserializeObjectFromArray(header, body, "Node", true, owner ~= nil)
	---@cast obj Node?

	if not obj then
		-- Errored and didn't create the Object;
		-- Try to recover from this error by skipping what would be the tree
		-- below the problematic Node
		print(("[Adore.TableScene...instantiateTree] %s"):format(err))
		local depth = 1
		while depth > 0 do
			local nextControl = tremove(array, 1)
			if nextControl == STRING_TO_CONTROL.BEGIN_CHILDREN then
				-- Go deeper in the tree
				depth = depth + 1
			elseif nextControl == STRING_TO_CONTROL.BEGIN_NODE then
				-- Skip useless data
				tremove(array, 1)
				tremove(array, 1)
			elseif nextControl == STRING_TO_CONTROL.END_CHILDREN then
				-- Go higher in the tree
				depth = depth - 1
				if depth == 1 then
					-- The end of this Node's tree
					return
				end
			elseif nextControl == nil then
				-- No more controls
				break
			end
		end
		print("[Adore.TableScene] Badly formatted scene; could not recover")
		return
	end

	if not owner then
		-- This Node is the scene root and owns the tree
		owner = obj
	else
		-- This Node is owned by the scene root
		obj._owner = owner
	end

	if deferredProperties then
		-- This Node has deferred properties
		allDeferredProperties[obj] = deferredProperties
	end

	control = tremove(array, 1)
	if control == STRING_TO_CONTROL.END_NODE then
		-- Finished with this Node
		if ontoParent then
			ontoParent:addChild(obj)
		end
		return obj
	elseif control == STRING_TO_CONTROL.BEGIN_CHILDREN then
		-- Repeat this until a Node isn't returned (which means END_CHILDREN was (probably) returned)
		while instantiateTree(obj, array, allDeferredProperties, owner) ~= nil do end
		assert(tremove(array, 1) == STRING_TO_CONTROL.END_NODE, "Did not get END_NODE control code (after END_CHILDREN was received)")
		if ontoParent then
			ontoParent:addChild(obj)
		end
		return obj
	else
		error("Got unexpected control code (expected END_NODE or BEGIN_CHILDREN)")
	end
end

---Returns `true` if this TableScene is empty
---@return boolean
function TableScene:isEmpty()
	return self._consumed or #self.table == 0
end

---Instantiates this Scene and returns the highest level `Node`
---@param consumeBuffer boolean? # [Default: `false`] Whether the buffer should be destroyed afterwards
---@return Node? instanced
function TableScene:build(consumeBuffer)
	if self:isEmpty() then
		print("[Adore.TableScene:build] Tree is empty; nothing to instantiate")
	else
		---@type {[Node]: {[string]: any}}
		local deferredData = {}
		local array = self.table
		local resources = array[#array]

		if not consumeBuffer then
			-- Clone the table
			local newArray = {}
			for i = 1, #array do
				newArray[i] = array[i]
			end
			array = newArray

			local newResources = {}
			for i = 1, #resources do
				local resource = resources[i]
				local newResource = {}
				for k, v in pairs(resource) do
					newResource[k] = v
				end
				newResources[i] = newResource
			end
			resources = newResources
		end

		local instanced = instantiateTree(nil, array, deferredData)
		if self._shouldUpdateDependencies and instanced then
			-- Update dependencies (if it was missed while packing)
			self._shouldUpdateDependencies = false
			self:updateDependencies(instanced)
		end

		local err

		if err then
			print(("[Adore.TableScene:build] Error while deserializing resources: %s"):format(err))
		end

		-- Set all deferred properties; they are usually deferred if they depend on a tree structure (like Signals)
		if deferredData then
			for node, deferredProperties in pairs(deferredData) do
				ObjectSaver.setDeferredProperties(node, deferredProperties, resources)
			end
		end

		if consumeBuffer then
			-- Make it obvious the buffer was consumed
			self._consumed = true
		end

		return instanced
	end
end

---Returns a function that can be called to instantiate a TableScene's contents
---@return SceneFunction
function TableScene:asSceneFunction()
	local func = self.instantiate
	return function(parent)
		return func(self, parent, false)
	end
end

function TableScene._addDefinition(entry)
	entry:newTable("table")
end

return TableScene
