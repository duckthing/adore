---@class Structures
local Structures = {}
local tremove = table.remove

--- While you can use metatables, I don't recommend it if your keys can match a method name

do
	-- table.new
	local success, val = pcall(require, "table.new")
	local finalValue = val

	if not success then
		---@diagnostic disable-next-line: undefined-field
		finalValue = table.new or function() return {} end
	end

	---Creates a new table
	Structures.tableNew = finalValue
end

do
	-- table.clear
	local success, val = pcall(require, "table.clear")
	local finalValue = val

	if not success then
		---@diagnostic disable-next-line: undefined-field
		finalValue = table.clear or function(t)
			for k, _ in pairs(t) do
				t[k] = nil
			end
		end
	end

	---Clears a table
	Structures.tableClear = finalValue
end

local tclear = Structures.tableClear

local function returnTrue() return true end

---@class Set
local Set = {}
local SetMT = {__index = Set}

---If `key` does not exist, set it and return `true`.
---If it exists, do nothing and return `false`.
---@param t table
---@param key any
---@return boolean added
function Set.mark(t, key)
	if rawget(t, key) == nil then
		rawset(t, key, true)
		return true
	end
	return false
end

---If `key` exists, remove it and return `true`.
---If it does not exist, do nothing and return `false`.
---@param t table
---@param key any
---@return boolean removed
function Set.unmark(t, key)
	if rawget(t, key) ~= nil then
		rawset(t, key, nil)
		return true
	end
	return false
end

Set.clear = tclear

Structures.Set = Set
---Creates a new Set
---@return Set
function Structures.newSet()
	return setmetatable({}, SetMT)
end

---Converts an existing table into a Set
---@param existing table
---@return Set
function Structures.castToSet(existing)
	return setmetatable(existing, SetMT)
end

---@class Stack
local Stack = {}
local StackMT = {__index = Stack}

---Pushes a value to the end of the Stack
---@param t table
---@param value any
function Stack.push(t, value)
	rawset(t, #t + 1, value)
end

---Removes a value at the end of the Stack and returns it.
---If there are no values left, returns `nil`.
---@param t table
---@return any? value
function Stack.pop(t)
	local index = #t
	if index > 0 then
		local value = rawget(t, index)
		rawset(t, index, nil)
		return value
	end
	return nil
end

---Returns the value at the top of a Stack.
---Similar to `pop`, but does not modify the Stack.
---@param t table
---@return any
function Stack.peek(t)
	return t[#t]
end

---Finds a value from the Stack and removes it.
---Returns `true` if it existed.
---@param t table
---@param value any
---@return boolean existed
function Stack.removeValue(t, value)
	for i = #t, 1, -1 do
		if rawget(t, i) == value then
			tremove(t, i)
			return true
		end
	end
	return false
end

Stack.clear = tclear

---Creates a new Stack
---@return Stack
function Structures.newStack()
	return setmetatable({}, StackMT)
end

---Converts an existing table into a Stack
---@param existing table
---@return Stack
function Structures.castToStack(existing)
	return setmetatable(existing, StackMT)
end

Structures.Stack = Stack

---@class Queue
local Queue = {}
local QueueMT = {__index = Queue}

---Adds a value to the start, if it is not `nil`
---@param t table
---@param value any
function Queue.enqueue(t, value)
	if value then
		table.insert(t, 1, value)
	end
end

---Removes a value at the start of the Queue and returns it.
---If there are no values left, returns `nil`.
---@param t table
---@return any? value
function Queue.dequeue(t)
	return table.remove(t, 1)
end

---Returns the value at the start of the Queue.
---Similar to `dequeue`, but does not modify the Queue.
---@param t table
---@return any
function Queue.peek(t)
	return t[1]
end

---Finds a value from the Queue and removes it.
---Returns `true` if it existed.
---@param t table
---@param value any
---@return boolean existed
function Queue.removeValue(t, value)
	for i = 1, #t do
		if rawget(t, i) == value then
			tremove(t, i)
			return true
		end
	end
	return false
end

Queue.clear = tclear

---Creates a new Queue
---@return Queue
function Structures.newQueue()
	return setmetatable({}, QueueMT)
end

---Converts an existing table into a Queue
---@param existing table
---@return Queue
function Structures.castToQueue(existing)
	return setmetatable(existing, QueueMT)
end

---Doesn't fit in here, but where else would it be?
---CheapIter is basically `:emit()` but without returning any results.
---It avoids any costs associated with those checks, with the downside of not being able to return early.
---
---Was in the process of being moved out of `rootnode.lua` and `scenetree.lua`, but there
---needs to be more measurement.
---@class CheapTreeIter
local CheapIter = {}
local CheapIterMT = {
	__index = CheapIter
}

---Calls a method on `start`s children recursively, but does not call it on `start`
---@param startNode Node
---@param methodName string
---@param ... unknown
function CheapIter:emit(startNode, methodName, ...)
	---@type Node[] # The current chain of parents
	local parents = self._parents
	---@type integer[] # The index of the parent in its parent children array (its index from above)
	local childIndices = self._childIndices

	parents[1] = startNode
	childIndices[1] = 1

	while #parents > 0 do
		local i = #parents
		local parent = parents[i]
		local childIndex = childIndices[i]
		local child = parent.children[childIndex]

		if not child then
			-- Child doesn't exist, go up one level
			parents[i] = nil
			childIndices[i] = nil
		else
			-- Child exists
			local method = child[methodName]
			if method and method(child, ...) then
				-- Method exists and returned true, exit
				break
			end

			if #child.children > 0 then
				-- Add this child to the array
				parents[i + 1] = child
				childIndices[i + 1] = 1
			end

			childIndices[i] = childIndex + 1
		end
	end

	tclear(parents)
	tclear(childIndices)
end

---Calls the desired method on `startNode`, and emits it downwards
---@param startNode Node
---@param methodName string
---@param ... unknown
function CheapIter:callAndEmit(startNode, methodName, ...)
	startNode[methodName](self, ...)
	self:emit(startNode, methodName, ...)
end

---Calls a function for each child beneath `startNode`
---@param startNode Node
---@param func fun(node: Node, depth: integer, ...)
---@param ... unknown
function CheapIter:iterate(startNode, func, ...)
	---@type Node[] # The current chain of parents
	local parents = self._parents
	---@type integer[] # The index of the parent in its parent children array (its index from above)
	local childIndices = self._childIndices

	parents[1] = startNode
	childIndices[1] = 1

	while #parents > 0 do
		local depth = #parents
		local parent = parents[depth]
		local childIndex = childIndices[depth]
		local child = parent.children[childIndex]

		if not child then
			-- Child doesn't exist, go up one level
			parents[depth] = nil
			childIndices[depth] = nil
		else
			-- Child exists
			func(child, depth, ...)

			if #child.children > 0 then
				-- Add this child to the array
				parents[depth + 1] = child
				childIndices[depth + 1] = 1
			end

			childIndices[depth] = childIndex + 1
		end
	end

	for i = #parents, 1, -1 do
		parents[i] = nil
		childIndices[i] = nil
	end
end

---Creates a new `CheapTreeIter`
---@return CheapTreeIter
function Structures.newCheapTreeIterator()
	---@class CheapTreeIter
	local t = {
		_parents = {},
		_childIndices = {},
	}
	return setmetatable(t, CheapIterMT)
end

---Moved out of `Node` into its own class, as I believe there could be more optimizations
---that involve less recursive calls.
---Not doing that right now, though; moving was annoying.
---TODO: Optimize TreeIter traversals
---@class TreeIter
local TreeIter = {}
local TreeIterMT = {__index = TreeIter}

---Goes downward the Scene Tree all descendents, and returns if the value returned by `forEach` is not nil.
---`currNodeValidator` can skip a path and Nodes on said path if it returns `false`.
---@param node Node
---@param forEach fun(node: Node, ...: unknown): any?
---@param currNodeValidator (fun(node: Node, ...: unknown): boolean)? # Returns `true` if the current node is valid to travel to
---@param ... unknown # Passed into both functions
function TreeIter:traverseDownExcludeSelf(node, forEach, currNodeValidator, ...)
	if not currNodeValidator then currNodeValidator = returnTrue end

	-- Check all children if they are the result
	local nodeChildren = node.children
	for i = 1, #nodeChildren do
		local child = nodeChildren[i]
		local result = self:traverseDownSelf(child, forEach, currNodeValidator, ...)
		if result then return result end
	end

	-- Not the result
	return nil
end

---Goes downward the Scene Tree through ourselves and all descendents, and returns if the value returned by `forEach` is not nil.
---`currNodeValidator` can skip a path and Nodes on said path if it returns `false`.
---@param node Node
---@param forEach fun(node: Node, ...: unknown): any?
---@param currNodeValidator (fun(node: Node, ...: unknown): boolean)? # Returns `true` if the current node is valid to travel to
---@param ... unknown # Passed into both functions
function TreeIter:traverseDownSelf(node, forEach, currNodeValidator, ...)
	if not currNodeValidator then currNodeValidator = returnTrue end

	-- Check if this Node is the result
	do
		if not currNodeValidator(node, ...) then return end
		local result = forEach(node, ...)
		if result then return result end
	end

	-- Check all children if they are the result
	local nodeChildren = node.children
	for i = 1, #nodeChildren do
		local child = nodeChildren[i]
		local result = self:traverseDownSelf(child, forEach, currNodeValidator, ...)
		if result then return result end
	end

	-- Not the result
	return nil
end

---Goes downward the Scene Tree through ourselves, all descendents, and later neighbors's descendents, and returns if the value returned by `forEach` is not nil.
---`currNodeValidator` can skip a path and Nodes on said path if it returns `false`.
---@param node Node
---@param forEach fun(node: Node, ...: unknown): any?
---@param currNodeValidator (fun(node: Node, ...: unknown): boolean)? # Returns `true` if the current node is valid to travel to
---@param ... unknown # Passed into both functions
function TreeIter:traverseDownwards(node, forEach, currNodeValidator, ...)
	if not currNodeValidator then currNodeValidator = returnTrue end

	-- Check self
	do
		local result = self:traverseDownSelf(node, forEach, currNodeValidator, ...)
		if result then return result end
	end

	-- Check later neighbors
	local currNode = node
	while currNode do
		local parent = currNode.parent
		if not parent then return end

		local currNodeIndex = parent:getIndexOfChild(currNode)
		local parentChildren = parent.children
		for i = currNodeIndex + 1, #parentChildren do
			local child = parentChildren[i]
			local result = self:traverseDownSelf(child, forEach, currNodeValidator, ...)
			if result then return result end
		end

		if not currNodeValidator(parent, ...) then return end
		currNode = parent
	end

	-- Not the result
	return nil
end

---Goes through ourselves and up through the Scene Tree, and returns if the value returned by `forEach` is not nil.
---Imagine the Scene Tree in a Tree format, with all groups expanded. It will go 'up' towards neighboring children.
---The "above" Node will either be the deepest Node in an earlier sibling, the earlier sibling, or the parent.
---`currNodeValidator` can skip a path and Nodes on said path if it returns `false`.
---@param node Node
---@param forEach fun(node: Node, ...: unknown): any?
---@param currNodeValidator (fun(node: Node, ...: unknown): boolean)? # Returns `true` if the current node is valid to travel to
---@param ... unknown # Passed into both functions
function TreeIter:traverseUpwards(node, forEach, currNodeValidator, ...)
	if not currNodeValidator then currNodeValidator = returnTrue end

	-- Check if this Node is the result
	do
		if not currNodeValidator(node, ...) then return end
		local result = forEach(node, ...)
		if result then return result end
	end

	-- Get the 'previous' node and continue iterating upwards
	local parent = node.parent
	if parent then
		local ownIndex = parent:getIndexOfChild(node)
		if ownIndex == 1 then
			-- We are the earliest child, iterate with the parent
			return self:traverseUpwards(parent, forEach, currNodeValidator, ...)
		else
			-- Get the previous sibling, and continue iterating with either its
			-- deepest (valid) node or itself (if valid)
			local previousNode = parent.children[ownIndex - 1]

			return self:traverseUpwards(
				previousNode:getDeepestNode(currNodeValidator, ...) or previousNode,
			forEach, currNodeValidator, ...)
		end
	end

	-- Not the result
	return nil
end

---Creates a new `TreeIter`
---@return TreeIter
function Structures.newTreeIterator()
	---@class TreeIter
	local t = {
		-- _parents = {},
		-- _childIndices = {},
	}
	return setmetatable(t, TreeIterMT)
end

return Structures
