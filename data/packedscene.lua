---@type AdoreInit
local Adore = require ""

local StringBuffer = require "_G.string.buffer"
local Object = Adore.Resources("Object")
local ObjectSaver = Adore.Common("ObjectSaver")

---@class PackedScene: Object
---@overload fun(): PackedScene
local PackedScene = Object:extend()
PackedScene.CLASS_NAME = "PackedScene"

function PackedScene:new()
	PackedScene.super.new(self)
	---@type string.buffer
	self.buffer = StringBuffer.new()
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
local function packInto(buffer, node, resources)
	if not node._adorePersist then return end

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
				packInto(buffer, child, resources)
			end
		end

		-- If there is at least 1 child that has 'adoreCanSave', we end the list
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
	local resources = {}
	packInto(self.buffer, node, resources)
	ObjectSaver.serializeResourcesToBuffer(self.buffer, resources)
end

local instantiateTree

---@param ontoParent Node?
---@param buffer string.buffer
---@param allDeferredProperties {[Node]: {[string]: any}}?
---@return Node? node
function instantiateTree(ontoParent, buffer, allDeferredProperties)
	local control = buffer:decode()
	if control ~= STRING_TO_CONTROL.BEGIN_NODE then return end
	local err, obj, deferredProperties = ObjectSaver.deserializeFromBuffer(buffer, "Node", true)
	---@cast obj Node?

	if not obj then
		print(("[Adore.PackedScene...instantiateTree] %s"):format(err))
		return
	end

	if deferredProperties then
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
		while instantiateTree(obj, buffer, allDeferredProperties) ~= nil do end
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
	return #self.buffer == 0
end

---Instantiates this Scene underneath `parent`. Returns the starting `Node` that was instantiated.
---@param parent Node?
---@param consumeBuffer boolean? # [Default: `false`] Whether the buffer should be destroyed afterwards
---@return Node? instanced
function PackedScene:instantiate(parent, consumeBuffer)
	if self:isEmpty() then
		print("[Adore.PackedScene:instantiate] Tree is empty; nothing to instantiate")
	else
		---@type {[Node]: {[string]: any}}
		local deferredData = {}
		local buffer = self.buffer
		if not consumeBuffer then
			buffer = StringBuffer.new()
			buffer:put(self.buffer:tostring())
		end

		local instanced = instantiateTree(nil, buffer, deferredData)
		local err, resources = ObjectSaver.deserializeResourcesFromBuffer(buffer)

		if err then
			print(("[Adore.PackedScene:instantiate] Error while deserializing resources: %s"):format(err))
		end

		-- Set all deferred properties; they are usually deferred if they depend on a tree structure (like Signals)
		if deferredData then
			for node, deferredProperties in pairs(deferredData) do
				ObjectSaver.setDeferredProperties(node, deferredProperties, resources)
			end
		end

		if parent and instanced then
			parent:addChild(instanced)
		end
		return instanced
	end
end

---Returns a function that can be called to instantiate a PackedScene's contents
---@return SceneFunction
function PackedScene:asFunction()
	local func = self.instantiate
	return function(parent)
		return func(self, parent, true)
	end
end

function PackedScene._addDefinition(entry)
	entry:newStringBuffer("buffer")
end
PackedScene:getClassDBEntry()

return PackedScene
