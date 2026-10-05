---@type AdoreInit
local Adore = require ""

local StringBuffer = require "_G.string.buffer"
local SceneFactory = Adore.Resources("SceneFactory")
local ObjectSaver = Adore.Common("ObjectSaver")
local tclear = Adore.Common("Structures").tableClear

---@class PackedScene: SceneFactory
---@overload fun(): PackedScene
local PackedScene = SceneFactory:extend()
PackedScene.CLASS_NAME = "PackedScene"

local END_CONTROL_CODE = "$END_SCENE_TREE^"

function PackedScene:new()
	PackedScene.super.new(self)
	---@type string.buffer
	self.buffer = StringBuffer.new()
	---@type boolean # If this PackedScene's buffer was consumed
	self._consumed = false
end

---@param buffer string.buffer
---@param node Node
---@param parentPath string
---@param resources any[]
---@param owner Node? # What we're allowed to save with; if not inside of recursion, leave this `nil`
---@param dependencyMap {[string]: true} # A map of filepaths to `true`
local function packInto(buffer, node, parentPath, resources, owner, dependencyMap)
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
	buffer:encode(parentPath)
	ObjectSaver.serializeObjectToBuffer(node, buffer, resources)

	-- Pack any children
	local children = node.children
	local childrenCount = #children
	if childrenCount ~= 0 then
		local ownPath = ""
		if node ~= owner then
			ownPath = ("%s/%s"):format(parentPath, node.name)
		end
		for i = 1, childrenCount do
			local child = children[i]
			packInto(buffer, child, ownPath, resources, owner, dependencyMap)
		end
	end
end

---Packs the node and any children
---@param node Node
function PackedScene:pack(node)
	self.buffer:reset()
	self._consumed = false
	local resources = {}
	node._sceneFilePath = nil

	-- Clear dependency map
	local dependencyMap = self._dependencyMap
	tclear(dependencyMap)

	-- Pack the scene tree and the resources
	packInto(self.buffer, node, "", resources, nil, dependencyMap)
	self.buffer:encode(END_CONTROL_CODE)
	ObjectSaver.serializeResourcesToBuffer(self.buffer, resources)

	-- Update dependency map with what we just found while packing
	self:updateDependencies()
	self._shouldUpdateDependencies = false
end

---@param lastParent Node?
---@param lastPath string
---@param buffer string.buffer
---@param allDeferredProperties {[Node]: {[string]: any}}?
---@param owner Node?
---@return Node? node
local function instantiateTree(lastParent, lastPath, buffer, allDeferredProperties, owner)
	local parentPath = buffer:decode()
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
			buffer:decode()
			buffer:decode()
			return instantiateTree(lastParent, parentPath, buffer, allDeferredProperties, owner)
		end
		lastParent = newParent
	end

	local err, obj, deferredProperties =
		ObjectSaver.deserializeFromBuffer(buffer, "Node", true, owner ~= nil)

	if not obj then
		-- Errored and didn't create the Object; continue
		print(("[Adore.TableScene...instantiateTree] %s"):format(err))
		return instantiateTree(lastParent, parentPath, buffer, allDeferredProperties, owner)
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
		return instantiateTree(lastParent, parentPath, buffer, allDeferredProperties, owner)
	elseif ownsTree then
		-- The instanced Node is the owner of the tree
		lastParent = obj
		parentPath = "."
		instantiateTree(lastParent, parentPath, buffer, allDeferredProperties, owner)
		-- Return it
		return obj
	end
end

---Returns `true` if this PackedScene is empty
---@return boolean
function PackedScene:isEmpty()
	return self._consumed or #self.buffer == 0
end

---Instantiates this Scene and returns the highest level `Node`
---@param consumeBuffer boolean? # [Default: `false`] Whether the buffer should be destroyed afterwards
---@return Node? instanced
function PackedScene:build(consumeBuffer)
	if self:isEmpty() then
		print("[Adore.PackedScene:build] Tree is empty; nothing to instantiate")
	else
		---@type {[Node]: {[string]: any}}
		local deferredData = {}
		local buffer = self.buffer

		if not consumeBuffer then
			-- Clone the buffer
			buffer = StringBuffer.new()
			buffer:put(self.buffer)
		end

		local success, instanced = pcall(instantiateTree, nil, "", buffer, deferredData)
		if not success then
			print(("[Adore.PackedScene:build] Error while instantiating tree: %s"):format(instanced))
			return
		end

		if self._shouldUpdateDependencies and instanced then
			-- Update dependencies (if it was missed while packing)
			self._shouldUpdateDependencies = false
			self:updateDependencies(instanced)
		end

		local resources, err = ObjectSaver.deserializeResourcesFromBuffer(buffer)

		if err then
			print(("[Adore.PackedScene:build] Error while deserializing resources: %s"):format(err))
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

---Returns a function that can be called to instantiate a PackedScene's contents
---@return SceneFunction
function PackedScene:asSceneFunction()
	local func = self.instantiate
	return function(parent)
		return func(self, parent, false)
	end
end

function PackedScene._addDefinition(entry)
	entry:newStringBuffer("buffer")
end

return PackedScene
