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

local END_CONTROL_CODE = "$END_SCENE_TREE^"

function TableScene:new()
	TableScene.super.new(self)
	---@type (table | string)[]
	self.table = {}
	---@type boolean # If this TableScene's buffer was consumed
	self._consumed = false
end

---@param array table[]
---@param node Node
---@param parentPath string
---@param resources any[]
---@param owner Node? # What we're allowed to save with; if not inside of recursion, leave this `nil`
---@param dependencyMap {[string]: true} # A map of filepaths to `true`
local function packInto(array, node, parentPath, resources, owner, dependencyMap)
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

	-- Add the path of the parent and this Node to the array
	enqueue(array, parentPath)
	ObjectSaver.serializeObjectToArray(node, array, resources)

	-- Pack any children
	local children = node.children
	local childrenCount = #children
	if childrenCount ~= 0 then
		local ownPath = "."
		if node ~= owner then
			-- Has a parent; append our name to the path and give it to the children
			ownPath = ("%s/%s"):format(parentPath, node.name)
		end
		for i = 1, childrenCount do
			local child = children[i]
			packInto(array, child, ownPath, resources, owner, dependencyMap)
		end
	end
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
	packInto(self.table, node, "", resources, nil, dependencyMap)
	self.table[#self.table+1] = END_CONTROL_CODE
	self.table[#self.table+1] = resources

	-- Update dependency map with what we just found while packing
	self:updateDependencies()
	self._shouldUpdateDependencies = false
end

---@param lastParent Node?
---@param lastPath string
---@param array table[]
---@param allDeferredProperties {[Node]: {[string]: any}}?
---@param owner Node?
---@return Node? node
local function instantiateTree(lastParent, lastPath, array, allDeferredProperties, owner)
	local parentPath = tremove(array, 1)
	if parentPath == nil or parentPath == END_CONTROL_CODE then return end
	if parentPath ~= lastPath then
		-- If it's not a string, don't look at it
		if type(parentPath) ~= "string" then return end

		---@diagnostic disable-next-line
		local newParent = owner:getNodeFromPath(parentPath)
		if not lastParent then
			-- Parent doesn't exist; continue
			print(("[Adore.TableScene...instantiateTree] Path doesn't result in Node: '%s'"):format(parentPath))
			-- Skip the body and header
			tremove(array, 1)
			tremove(array, 1)
			return instantiateTree(lastParent, parentPath, array, allDeferredProperties, owner)
		end
		lastParent = newParent
	end

	local header, body = tremove(array, 1), tremove(array, 1)

	local err, obj, deferredProperties =
		ObjectSaver.deserializeObjectFromArray(header, body, "Node", true, owner ~= nil)

	if not obj then
		-- Errored and didn't create the Object; continue
		print(("[Adore.TableScene...instantiateTree] %s"):format(err))
		return instantiateTree(lastParent, parentPath, array, allDeferredProperties, owner)
	end

	local ownsTree = false
	if not owner then
		-- This Node is the scene root and owns the tree
		owner = obj
		ownsTree = true
	else
		-- This Node is owned by the scene root
		obj._owner = owner
	end

	if deferredProperties then
		-- This Node has deferred properties
		allDeferredProperties[obj] = deferredProperties
	end

	if lastParent and not ownsTree then
		-- Parent exists, add it
		lastParent:addChild(obj)
		return instantiateTree(lastParent, parentPath, array, allDeferredProperties, owner)
	elseif ownsTree then
		-- The instanced Node is the owner of the tree
		lastParent = obj
		parentPath = "."
		instantiateTree(lastParent, parentPath, array, allDeferredProperties, owner)
		-- Return it
		return obj
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

		local instanced = instantiateTree(nil, "", array, deferredData)
		if self._shouldUpdateDependencies and instanced then
			-- Update dependencies (if it was missed while packing)
			self._shouldUpdateDependencies = false
			self:updateDependencies(instanced)
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
