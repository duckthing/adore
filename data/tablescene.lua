---@type AdoreInit
local Adore = require ""

local Object = Adore.Resources("Object")
local ObjectSaver = Adore.Common("ObjectSaver")
local tremove = table.remove
local enqueue = function(arr, val) arr[#arr+1] = val end

---@class TableScene: Object
---@overload fun(): TableScene
local TableScene = Object:extend()
TableScene.CLASS_NAME = "TableScene"

function TableScene:new()
	TableScene.super.new(self)
	---@type table[]
	self.table = {}
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
local function packInto(array, node, resources)
	if not node._adorePersist then return end

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
				packInto(array, child, resources)
			end
		end

		-- If there is at least 1 child that has 'adoreCanSave', we end the list
		if index > 1 then
			enqueue(array, STRING_TO_CONTROL.END_CHILDREN)
		end
	end
	enqueue(array, STRING_TO_CONTROL.END_NODE)
end

---Packs the node and any children.
---@param node Node
function TableScene:pack(node)
	self.table = {}
	local resources = {}
	packInto(self.table, node, resources)
	self.table[#self.table+1] = resources
end

local instantiateTree

---@param ontoParent Node?
---@param array table[]
---@param allDeferredProperties {[Node]: {[string]: any}}?
---@return Node? node
function instantiateTree(ontoParent, array, allDeferredProperties)
	local control = tremove(array, 1)
	if control ~= STRING_TO_CONTROL.BEGIN_NODE then return end
	local header, body = tremove(array, 1), tremove(array, 1)
	local err, obj, deferredProperties = ObjectSaver.deserializeObjectFromArray(header, body, "Node", true)
	---@cast obj Node?

	if not obj then
		print(("[Adore.TableScene...instantiateTree] %s"):format(err))
		return
	end

	if deferredProperties then
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
		while instantiateTree(obj, array, allDeferredProperties) ~= nil do end
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
	return #self.table == 0
end

---Instantiates this Scene underneath `parent`. Returns the starting `Node` that was instantiated.
---@param parent Node?
---@param consumeBuffer boolean? # [Default: `false`] Whether the buffer should be destroyed afterwards
---@return Node? instanced
function TableScene:instantiate(parent, consumeBuffer)
	if self:isEmpty() then
		print("[Adore.TableScene:instantiate] Tree is empty; nothing to instantiate")
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
		local err

		if err then
			print(("[Adore.TableScene:instantiate] Error while deserializing resources: %s"):format(err))
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

---Returns a function that can be called to instantiate a TableScene's contents
---@return SceneFunction
function TableScene:asFunction()
	local func = self.instantiate
	return function(parent)
		return func(self, parent, false)
	end
end

function TableScene._addDefinition(entry)
	entry:newTable("table")
end

return TableScene
