---@type AdoreInit
local Adore = require ""

local StringBuffer = require "_G.string.buffer"
local SceneFactory = Adore.Resources("SceneFactory")
local ObjectSaver = Adore.Common("ObjectSaver")

---@class PackedScene: SceneFactory
---@overload fun(): PackedScene
local PackedScene = SceneFactory:extend()
PackedScene.CLASS_NAME = "PackedScene"

function PackedScene:new()
	PackedScene.super.new(self)
	---@type string.buffer
	self.buffer = StringBuffer.new()
	---@type boolean # If this PackedScene's buffer was consumed
	self._consumed = false
end

local STRING_TO_CONTROL = {
	BEGIN_NODE = 1,
	END_NODE = 2,
	BEGIN_CHILDREN = 3,
	END_CHILDREN = 4,
}

---@param buffer string.buffer
---@param node Node
---@param resources any[]
---@param owner Node? # What we're allowed to save with; if not inside of recursion, leave this `nil`
local function packInto(buffer, node, resources, owner)
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

	buffer:encode(STRING_TO_CONTROL.BEGIN_NODE)
	ObjectSaver.serializeObjectToBuffer(node, buffer, resources)

	if #node.children ~= 0 then
		local index = 1
		for i = 1, #node.children do
			local child = node.children[i]
			if child._adorePersist then
				if index == 1 then
					buffer:encode(STRING_TO_CONTROL.BEGIN_CHILDREN)
				end

				index = index + 1
				packInto(buffer, child, resources, owner)
			end
		end

		-- If there is at least 1 child that has '_adorePersist', we end the list
		if index > 1 then
			buffer:encode(STRING_TO_CONTROL.END_CHILDREN)
		end
	end
	buffer:encode(STRING_TO_CONTROL.END_NODE)
end

---Packs the node and any children.
---@param node Node
function PackedScene:pack(node)
	self.buffer:reset()
	self._consumed = false
	local resources = {}
	packInto(self.buffer, node, resources)
	ObjectSaver.serializeResourcesToBuffer(self.buffer, resources)
end

local instantiateTree

---@param ontoParent Node?
---@param buffer string.buffer
---@param allDeferredProperties {[Node]: {[string]: any}}?
---@param owner Node?
---@return Node? node
function instantiateTree(ontoParent, buffer, allDeferredProperties, owner)
	local control = buffer:decode()
	if control ~= STRING_TO_CONTROL.BEGIN_NODE then return end
	local err, obj, deferredProperties =
		ObjectSaver.deserializeFromBuffer(buffer, "Node", true, owner ~= nil)
	---@cast obj Node?

	if not obj then
		-- Errored and didn't create the Object;
		-- Try to recover from this error by skipping what would be the tree
		-- below the problematic Node
		print(("[Adore.PackedScene...instantiateTree] %s"):format(err))
		local depth = 1
		while depth > 0 do
			local success, nextControl = pcall(buffer.decode, buffer)
			if not success then
				-- Errored while decoding
				print(("[Adore.PackedScene...instantiateTree] Error while decoding buffer: %s"):format(nextControl))
			end
			if nextControl == STRING_TO_CONTROL.BEGIN_CHILDREN then
				-- Go deeper in the tree
				depth = depth + 1
			elseif nextControl == STRING_TO_CONTROL.BEGIN_NODE then
				-- Skip useless data
				buffer:decode()
				buffer:decode()
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
		print("[Adore.PackedScene...instantiateTree] Badly formatted scene; could not recover")
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

	control = buffer:decode()
	if control == STRING_TO_CONTROL.END_NODE then
		-- Finished with this Node
		if ontoParent then
			ontoParent:addChild(obj)
		end
		return obj
	elseif control == STRING_TO_CONTROL.BEGIN_CHILDREN then
		-- Repeat this until a Node isn't returned (which means END_CHILDREN was (probably) returned)
		while instantiateTree(obj, buffer, allDeferredProperties, owner) ~= nil do end
		assert(buffer:decode() == STRING_TO_CONTROL.END_NODE, "Did not get END_NODE control code (after END_CHILDREN was received)")
		if ontoParent then
			ontoParent:addChild(obj)
		end
		return obj
	else
		error("Got unexpected control code (expected END_NODE or BEGIN_CHILDREN)")
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

		local success, instanced = pcall(instantiateTree, nil, buffer, deferredData)
		if not success then
			print(("[Adore.PackedScene:build] Error while instantiating tree: %s"):format(instanced))
			return
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
