---@type AdoreInit
local Adore = require ""
local Object = Adore.Resources("Object")
local Signal = Adore.Common("Signal")
local Structures = Adore.Common("Structures")
local max = math.max
local tinsert = table.insert

---@alias Node.PauseMode
---| "inherit" # Run if the parent is running
---| "pausable" # Run when the RootNode is not paused
---| "whenPaused" # Run when the RootNode is paused
---| "always" # Run, even if the RootNode is paused
---| "disabled" # Never run

---@class Node: Object
---@field super Node
---@field _adoreSource string? # If this `Node` was instantiated from as a scene, this contains the filepath it came from
---@overload fun(): Node
local Node = Object:extend()
Node.IS_NODE = true
---@type string
Node.CLASS_NAME = "Node"
---@type Node[] # Nodes that override the current Viewport (usually the RootNode and CanvasLayer)
Node.OVERRIDES_VIEWPORT = {}
---@type RootNode
Node._root = nil
---@type Viewport # The Viewport that is currently getting drawn to; only readable inside `:draw()`
Node._activeViewport = nil
---@type Node.PauseMode # How will this Node be processed on pauses
Node._pauseMode = "inherit"
---@type number # If the pause mode isn't `inherit`, when should this Node be processed. Lower is earlier.
Node._processPriority = 0

function Node:new()
	Node.super.new(self)

	---@type Node? # The parent of this Node. DO NOT SET DIRECTLY!
	self.parent = nil
	---@type Node[] # The Nodes below this one. DO NOT SET DIRECTLY!
	self.children = {}

	---@type string # The non-unique name of this Node
	self.name = self.CLASS_NAME
	---@type boolean # Whether this Node is visible
	self._visible = true

	---@type boolean # Whether this Node's ancestors are visible
	self._ancestorsVisible = false
	---@type boolean # Whether this Node is underneath the RootNode somewhere
	self._inTree = false
	---@type boolean # If this Node is ready for simulating
	self._ready = false
	---@type boolean # If this Node has not been destroyed
	self._valid = true
	---@type Viewport? # The Viewport this Node2d belongs to
	self._parentViewport = nil
end

---Called when the Node and any expected children are instanced and correctly parented.
function Node:ready()
end

---This is used when the tree status updates to call :ready().
function Node:_intReady()
	if not self._ready then
		self._ready = true
		self:ready()
	end
end

---Called every frame
---@param dt number
function Node:update(dt)
end

---Draws this Node, usually with several world transformations applied
function Node:draw()
end

function Node:_drawChildren()
	for i = 1, #self.children do
		local child = self.children[i]
		if child._visible then
			child:_intDraw()
		end
	end
end

function Node:_beforeDraw()
	love.graphics.push("transform")
	love.graphics.origin()
end

function Node:_afterDraw()
	love.graphics.pop()
end

-- local appleCakeProfileNodeDraw
-- local appleCakeArgs = {class = ""}

function Node:_intDraw()
	self:_beforeDraw()
	-- appleCakeArgs.class = self.CLASS_NAME
	-- appleCakeProfileNodeDraw = AppleCake.profile("Node:draw", appleCakeArgs, appleCakeProfileNodeDraw)
	self:draw()
	-- appleCakeProfileNodeDraw:stop()
	self:_drawChildren()
	self:_afterDraw()
end

---Emits an event downwards. Stops when the event returns 'true'.
---@param eventName string
---@param ... unknown
function Node:emit(eventName, ...)
	for i = 1, #self.children do
		local child = self.children[i]
		if child[eventName] then
			---@type boolean?
			local result = child[eventName](child, ...)
			if result == true then
				-- Stop
				return
			end
		end
		child:emit(eventName, ...)
	end
end

---Calls an event on self, then emits it downwards. Stops when the event returns 'true'.
---@param eventName string
---@param ... unknown
function Node:callAndEmit(eventName, ...)
	if self[eventName](self, ...) then return end
	self:emit(eventName, ...)
end

---Emits an event down to the immediate children only. Stops when the event returns 'true'.
---@param eventName string
---@param ... unknown
function Node:shallowEmit(eventName, ...)
	for i = 1, #self.children do
		local child = self.children[i]
		if child[eventName] then
			---@type boolean?
			local result = child[eventName](child, ...)
			if result == true then
				-- Stop
				return
			end
		end
	end
end

---Bubbles an event upwards. Stops when the event returns 'true'.
---@param eventName string
---@param ... unknown
function Node:bubble(eventName, ...)
	local ancestor = self.parent
	while ancestor ~= nil do
		if ancestor[eventName] then
			---@type boolean?
			local result = ancestor[eventName](ancestor, ...)
			if result == true then
				-- Stop
				return
			end
		end
		ancestor = ancestor.parent
	end
end

---Bubbles an event up to the parent only. This is a safe way to call a method that might not exist.
---@param eventName string
---@param ... unknown
---@return ...
function Node:shallowBubble(eventName, ...)
	local parent = self.parent
	if parent then
		local method = parent[eventName]
		return (method and method(parent, ...)) or nil
	end
	return nil
end

---Creates a new Signal bound to this Node and returns it
---@return Signal signal
function Node:newSignal()
	return Signal.new(self)
end

---Runs a function for each child; if it returns a value, it will stop the loop and return it.
---@param forEach fun(child: Node, ...: unknown): any
---@param ... unknown
---@return any
function Node:forEachChild(forEach, ...)
	for i = 1, #self.children do
		local result = forEach(self.children[i], ...)
		if result then return result end
	end
end

---Checks this Nodes parents to see if one is equal to 'ancestor', and returns true if found.
---@param ancestor Node
---@return boolean found
function Node:hasAncestor(ancestor)
	local currParent = self.parent
	while currParent do
		-- Found the ancestor
		if currParent == ancestor then return true end
		currParent = currParent.parent
	end

	-- No parent found
	return false
end

---Adds a child to this Node.
---Returns self, *not* the child.
---@generic T: Node
---@param self T
---@param child Node
---@return T
function Node:addChild(child)
	assert(child ~= self, "Can't add self to self")
	if not child._valid then
		if rawget(child, "CLASS_ID") then
			-- Passed a class without calling it (and instancing the Node)
			error("Child is not an instance (did you forget to initialize it?)")
		else
			-- It was destroyed
			error("Child is not valid (was destroyed)")
		end
	end

	local oldParent = child.parent
	if oldParent then
		if oldParent ~= self then
			-- Remove the old parent
			oldParent:removeChild(child)
		else
			-- It's ourselves, do nothing
			return self
		end
	end

	-- Set the new parent
	self.children[#self.children+1] = child
	child.parent = self
	child:onAddedToParent(self)

	-- (The following is done in :_eAncestorTreeStatusUpdated()
	-- child._inTree = self._inTree

	return self
end

---Inserts a child to this Node at a certain index.
---Returns self, *not* the child.
---@generic T: Node
---@param self T
---@param child Node
---@param index integer
---@return T
function Node:insertChild(child, index)
	-- It's very hacky, as `:addChild` always adds at the end
	if child.parent then
		child.parent:removeChild(child)
	end

	local children = self.children
	if index > #children + 1 then
		-- `:addChild` adds to the end by default
		return self:addChild(child)
	end
	index = max(1, index)
	tinsert(children, index, child)
	child.parent = self
	child:onAddedToParent(self)

	self:addChild(child)
	return self
end

---Returns the index the child is in. Returns `nil` if not found.
---@param child Node?
---@return integer? index
function Node:getIndexOfChild(child)
	if not child or child.parent ~= self then return nil end
	local children = self.children
	for i = 1, #children do
		if children[i] == child then return i end
	end
	return nil
end

---Removes the child at the specified index from this Node
---@param index integer
---@param shouldDestroy boolean?
function Node:removeChildAtIndex(index, shouldDestroy)
	local child = self.children[index]
	if child then
		-- Remove it
		table.remove(self.children, index)
		child.parent = nil
		child:onRemovedFromParent(self)
		if shouldDestroy then
			child:forceDestroy(true)
		end
	end
end

---Removes a child from this Node
---@param child Node
---@param shouldDestroy boolean?
function Node:removeChild(child, shouldDestroy)
	local index = self:getIndexOfChild(child)
	if index then
		self:removeChildAtIndex(index, shouldDestroy)
	end
end

---Removes all children from this Node
---@param shouldDestroy boolean?
function Node:clearChildren(shouldDestroy)
	for i = #self.children, 1, -1 do
		self:removeChildAtIndex(i, shouldDestroy)
	end
end

---Removes this Node from its parent, if it has one
function Node:unparent()
	if self.parent then
		self.parent:removeChild(self, false)
	end
end

---Gets the node with the given name relative to this Node. Add extra parameters to go deeper.
---This method allows traversing upwards; if you don't want this, use `:getNodeByPath()`.
---* `self:getNodeByName("Level", "Player", "CollisionShape")` => `./Level/Player/CollisionShape`
---@param ... string
---@return Node?
function Node:getNodeByName(...)
	local total = select("#", ...)
	if total == 0 then return nil end

	local currNode = self
	for i = 1, total do
		local name = select(i, ...)

		if name == ".." then
			-- .. will return the parent
			return currNode.parent
		elseif name == "." then
			-- . returns self, in case the user is *nix-brained
			return currNode
		end

		-- No other special keywords; search all children
		local children = currNode.children
		local foundChild
		for j = 1, #children do
			local child = children[j]
			if child.name == name then
				-- Found it
				foundChild = child
				break
			end
		end

		if foundChild then
			currNode = foundChild
		else
			return nil
		end
	end

	return currNode
end

---@alias NodePath string

---Gets a Node from a path structured like the following:
---* `"Character"` gets a Node called `Character` from this Node
---* `"./Character"` does the same as above
---* `"CanvasLayer/Control"` searches for a Node called `CanvasLayer`, and returns a Node called `Control` underneath it
---* `"../Enemy"` goes up to this Node's parent and searches for the Node called `Enemy`
---* `"/root/Level"` goes to the `RootNode` and returns a Node called `Level` that is underneath the `RootNode`
---@param path NodePath
---@param allowUp boolean? # Whether we can search upwards via '..' or '/root'; default is `true`
---@param verbose boolean? # Whether returned error messages should be detailed; default is `false`, good for detailed errors
---@return Node?
---@return string? err
function Node:getNodeFromPath(path, allowUp, verbose)
	allowUp = (allowUp == nil and true) or allowUp

	---@type Node
	local currNode = self
	if path:sub(1, 5) == "/root" then
		if not allowUp then
			if verbose then
				return nil, ("Attempted to move upwards via '/root' (with '%s')"):format(path)
			else
				return nil, "Attempted to move upwards via '/root'"
			end
		end
		currNode = self:getRoot()
		path = path:sub(7)
	end

	-- Remove the starting slash
	if path:sub(1, 1) == "/" then
		path = path:sub(2)
	end

	-- In case there's no more path
	if #path == 0 then
		return currNode
	end

	for name in path:gmatch("([^/]+)") do
		if not allowUp and name == ".." then
			-- Attempt to move up when disallowed
			if verbose then
				return nil, ("Attempted to move upwards via '..' (with '%s')"):format(path)
			else
				return nil, "Attempted to move upwards via '..'"
			end
		end

		if not (#name == 0 or name == ".") then
			-- Not an empty string nor "."
			local newNode = currNode:getNodeByName(name)

			if not newNode then
				-- Node `name` wasn't found under `currNode`
				if verbose then
					return nil, ("Could not find '%s' under '%s'\n[Start]: %s\n[Error Point]: %s"):format(
						name,
						currNode,
						self:getFullPath(),
						currNode:getFullPath()
					)
				else
					return nil, "Could not find node by name"
				end
			else
				-- Node WAS found
				currNode = newNode
			end
		end
	end
	return currNode
end

---If this Node is in the tree, returns its path relative to the RootNode.
---Ex. `"/root/Level1/Player/Hitbox"`
---If outside the tree, it may look like `"/[NO ROOT]/Level1/Player/Hitbox"`
---@return NodePath fullPath
function Node:getFullPath()
	local path = self.name
	local currNode = self.parent
	while currNode do
		path = currNode.name.."/"..path
		currNode = currNode.parent
	end

	if self._inTree then
		return "/"..path
	else
		return "/[NO ROOT]/"..path
	end
end

---Gets the path relative to `self` that results in `node`
---@param node Node
---@return NodePath? relativePath
function Node:getRelativePathToOther(node)
	-- TODO: Make this not concatenate a lot of strings

	---@type {[Node]: NodePath}
	local ownAncestors = {}

	-- Iterate through our ancestors and add them
	do
		local currNode = self
		local ownPath = "./"
		while currNode do
			ownAncestors[currNode] = ownPath
			currNode = currNode.parent
			ownPath = ownPath .. "../"
		end
	end

	-- Iterate through the other Node's ancestors, find the common ancestor, and path down from there
	do
		local currNode = node.parent
		local otherPath = node.name
		local ownPath = nil

		while currNode do
			local ancestorPath = ownAncestors[currNode]
			if ancestorPath then
				-- Found the common ancestor; break
				ownPath = ancestorPath
				break
			end

			otherPath = currNode.name .. "/" .. otherPath
			currNode = currNode.parent
		end

		if ownPath then
			return ownPath..otherPath
		end
	end
end

---Checks if this Node would get rendered if its status didn't change.
---Returns `true` if the Node is in the tree (which is detected by the next condition), its ancestors are visible, and the Node itself is visible.
---@return boolean visible
function Node:isVisibleInTree()
	return self._ancestorsVisible and self._visible
end

local treeIter = Structures.newTreeIterator()

---Goes downward the Scene Tree all descendents, and returns if the value returned by `forEach` is not nil.
---@param forEach fun(node: Node, ...: unknown): any?
---@param currNodeValidator (fun(node: Node, ...: unknown): boolean)? # Returns true if the current node is valid to travel to
---@param ... unknown # Passed into both functions
function Node:traverseDownExcludeSelf(forEach, currNodeValidator, ...)
	return treeIter:traverseDownExcludeSelf(self, forEach, currNodeValidator, ...)
end

---Goes downward the Scene Tree through ourselves and all descendents, and returns if the value returned by `forEach` is not nil.
---@param forEach fun(node: Node, ...: unknown): any?
---@param currNodeValidator (fun(node: Node, ...: unknown): boolean)? # Returns true if the current node is valid to travel to
---@param ... unknown # Passed into both functions
function Node:traverseDownSelf(forEach, currNodeValidator, ...)
	return treeIter:traverseDownSelf(self, forEach, currNodeValidator, ...)
end

---Goes downward the Scene Tree through ourselves, all descendents, and later neighbors's descendents, and returns if the value returned by `forEach` is not nil.
---@param forEach fun(node: Node, ...: unknown): any?
---@param currNodeValidator (fun(node: Node, ...: unknown): boolean)? # Returns true if the current node is valid to travel to
---@param ... unknown # Passed into both functions
function Node:traverseDownwards(forEach, currNodeValidator, ...)
	return treeIter:traverseDownwards(self, forEach, currNodeValidator, ...)
end

---Goes through ourselves and up through the Scene Tree, and returns if the value returned by `forEach` is not nil.
---Imagine the Scene Tree in a Tree format, with all groups expanded. It will go 'up' towards neighboring children.
---@param forEach fun(node: Node, ...: unknown): any?
---@param currNodeValidator (fun(node: Node, ...: unknown): boolean)? # Returns true if the current node is valid to travel to
---@param ... unknown # Passed into both functions
function Node:traverseUpwards(forEach, currNodeValidator, ...)
	return treeIter:traverseUpwards(self, forEach, currNodeValidator, ...)
end

---Returns the deepest Node, or nil if this Node doesn't have children.
---@return Node?
function Node:getDeepestNode()
	local currNode = self
	while currNode and #currNode.children > 0 do
		currNode = currNode.children[#currNode.children]
	end

	if currNode ~= self then
		return currNode
	else
		return nil
	end
end

---Sets the value of a property. Useful when emitting or bubbling.
---@generic T: Node
---@param self T
---@param property any
---@param value any
---@return T self
function Node:set(property, value)
	self[property] = value
	return self
end

---Destroys this Node immediately.
---
---DANGEROUS! Use :queueDestroy() instead if you want to destroy a node during :draw(), :update(), or any :emit() event.
---@param recursive boolean?
function Node:forceDestroy(recursive)
	if self.parent then
		self.parent:removeChild(self)
		self.parent = nil
	end

	self._inTree = false
	self._valid = false

	if recursive then
		self:clearChildren(true)
	end
end

---Returns the method from these parameters
---@param node Node
---@param method string | function
---@return function
local function getMethodFromParameter(node, method)
	local type = type(method)
	if type == "function" then
		return method
	elseif type == "string" then
		local m = node[method]
		if m == nil then
			-- Not found
			error(("'%s' was not found in '%s'"):format(method, node))
		else
			return m
		end
	else
		-- Invalid type
		error(("'%s' is not a method or method name"):format(method))
	end
end

---Queues a method to be called when not busy, which is usually before the end of `:update`.
---If you queue a method in `:draw`, it won't take effect until the next frame.
---You can queue any function if you go through the `RootNode` directly.
---@param method string | fun(self: self, ...: unknown)
---@param ... unknown
function Node:queue(method, ...)
	self:getRoot():queue(self, getMethodFromParameter(self, method), ...)
end

---Queues a method to be called after a certain amount of time, depending on the game's speed.
---You can queue any function if you go through the `RootNode` directly.
---@param duration number
---@param method string | fun(self: self, ...: unknown)
---@param ... unknown
function Node:queueAfterGameTime(duration, method, ...)
	self:getRoot():queueAfterGameTime(duration, self, getMethodFromParameter(self, method), ...)
end

---Queues a method to be called after a certain amount of time, depending on the real time passed.
---You can queue any function if you go through the `RootNode` directly.
---@param duration number
---@param method string | fun(self: self, ...: unknown)
---@param ... unknown
function Node:queueAfterRealTime(duration, method, ...)
	self:getRoot():queueAfterRealTime(duration, self, getMethodFromParameter(self, method), ...)
end

---Queues this Node to be destroyed when the RootNode is free to do so.
---@param recursive boolean?
function Node:queueDestroy(recursive)
	self:queue(self.forceDestroy, recursive)
end

---Called when this Node is added to a parent.
---This method calls `:onAddedToTree()`.
---@param parent Node
function Node:onAddedToParent(parent)
	if parent._inTree then
		-- The following is done in :_eAncestorTreeStatusUpdated()
		-- self._inTree = parent._inTree
		self:_eAncestorTreeStatusUpdated(parent, parent._inTree)
		self:emit("_eAncestorTreeStatusUpdated", parent, parent._inTree)

		if parent:isVisibleInTree() then
			self:_eAncestorVisibilityChanged(true)
		end
	end
end

---Called when this Node is removed from a parent
---@param parent Node
function Node:onRemovedFromParent(parent)
	if self._inTree then
		self._inTree = false
		self:onRemovedFromTree()
		self:emit("_eAncestorTreeStatusUpdated", false)
		if self._ancestorsVisible then
			self:_eAncestorVisibilityChanged(false)
		end
	end
end

---Calls a method on this Node, and returns self
---@generic T: Node
---@param self T
---@param methodName string
---@param ... unknown
---@return T self
function Node:chain(methodName, ...)
	return self, self[methodName](self, ...)
end

---Returns a function with the passed parameters inserted, for use with passing around.
---Relatively slow due to function creation, try to cache results.
---@param methodName any
---@param ... unknown
---@return fun(): unknown?
function Node:bind(methodName, ...)
	local method = self[methodName]
	if type(method) ~= "function" then
		error(("%s is not a method"):format(methodName))
	end

	local packed = {...}
	local unpackFunc = unpack
	return function()
		return method(self, unpackFunc(packed))
	end
end

---Gets the RootNode
---@return RootNode
function Node:getRoot()
	return Node._root
end

---Gets the Viewport that this Node is actively getting drawn to.
---This makes it only reliable inside of the Node's `:draw()` method; use `Node2d:getParentViewport()` or `:getTreeViewport()` to check the tree instead.
---@return Viewport
function Node:getDrawingViewport()
	return Node._activeViewport
end

---Gets the Viewport that this Node is beneath by looking at the tree.
---If you need the Viewport a Node will be drawn to by default, use `:getViewport()` instead.
---@return Viewport
function Node:getTreeViewport()
	if self._parentViewport then return self._parentViewport end
	local currNode = self.parent
	while currNode do
		-- Check if a CanvasLayer/RootNode overrides the normal Viewport check
		do
			-- The viewport property in RootNode or CanvasLayer
			local viewport = rawget(currNode, "_viewport")
			if viewport then
				local arr = Node.OVERRIDES_VIEWPORT
				for i = 1, #arr do
					if currNode:is(arr[i]) then
						-- This Node overrides the Viewport, return the Viewport
						return viewport
					end
				end
			end
		end

		-- Second, check the parent viewport that all Nodes use
		if self._inTree then
			local viewport = rawget(currNode, "_parentViewport")
			if viewport and currNode:is(Node) then
				-- Got the Viewport from the `_parentViewport` property in a Node
				return viewport
			end
		end

		currNode = currNode.parent
	end
	error(("Could not find Viewport from '%s'"):format(self:getFullPath()))
end

---Gets the first Node that is, or inherits, a class.
---@param type Node
---@return Node? found
function Node:findFirstNodeOfType(type)
	local children = self.children
	for i = 1, #children do
		if children[i]:is(type) then
			return children[i]
		end
	end

	return nil
end

---Gets the first Node that matches a class name.
---@param name string
---@return Node? found
function Node:findFirstNodeOfClassName(name)
	local children = self.children
	for i = 1, #children do
		if children[i].CLASS_NAME == name then
			return children[i]
		end
	end

	return nil
end

---Returns a Tween created under the Root and bound to this Node. The Tween updates while the game is unpaused.
---
---If you'd like to make a Tween run regardless of the pause state, use `Tween.new()` and call `:update()` on it manually.
---@param realTime boolean?
---@return Tween
function Node:createTween(realTime)
	local tween = self:getRoot():createTween(realTime)
	tween:bindNode(self)
	return tween
end

---Shows this Node, which allows this Node and all children to be drawn
---@return self
function Node:show()
	return self:setVisible(true)
end

---Hides this Node, which prevents this Node and all children from being drawn
---@return self
function Node:hide()
	return self:setVisible(false)
end

---Sets the visibility of this Node
---@param visible boolean
---@return self
function Node:setVisible(visible)
	if self._visible ~= visible then
		self._visible = visible
		if self._ancestorsVisible then
			self:shallowEmit("_eAncestorVisibilityChanged", visible)
		end
	end
	return self
end

---Sets the Node.PauseMode of this Node
---@param mode Node.PauseMode
function Node:setPauseMode(mode)
	if mode ~= self._pauseMode then
		self._pauseMode = mode
		if mode ~= "inherit" then
			-- No longer inheriting
			local root = self:getRoot()
			local rootPaused = root._paused
			root:insertTopLevelProcess(self)
			self:_pauseStatusChanged(
				(mode == "always")
				or
				(mode == "pausable" and not rootPaused)
				or
				(mode == "whenPaused" and rootPaused)
			)
		else
			-- Inheriting the pause status
			self:getRoot():removeTopLevelProcess(self)
			self:_pauseStatusChanged(self:getRoot()._paused)
		end
	end
end

---Called via emit; includes the changed ancestor and whether they are in the tree.
---Called inside of `:onAddedToParent()`.
---@param ancestor Node
---@param ancestorInTree boolean
function Node:_eAncestorTreeStatusUpdated(ancestor, ancestorInTree)
	local oldStatus = self._inTree
	if oldStatus ~= ancestorInTree then
		-- Status changed
		self._inTree = ancestorInTree
		if ancestorInTree then
			self:onAddedToTree()
		else
			self:onRemovedFromTree()
		end
	end
end

---Called via emit; occurs when an above Viewport is added or removed
---@param newViewport Viewport
function Node:_eAncestorViewportChanged(newViewport)
	local oldViewport = self._parentViewport
	if oldViewport then
		self:onViewportRemoved(oldViewport)
	end
	self._parentViewport = newViewport
	self:onViewportAdded(newViewport)
	self:shallowEmit("_eAncestorViewportChanged", newViewport)
end

---Called when this Node is getting added to a new Viewport (from :_eAncestorTreeStatusUpdated);
---:onViewportRemoved() will always get called before if there's an existing Viewport.
---@param newViewport Viewport
function Node:onViewportAdded(newViewport)
end

---Called when this Node2d is getting removed from a Viewport (from :_eAncestorTreeStatusUpdated)
---@param oldViewport Viewport
function Node:onViewportRemoved(oldViewport)
end

---Returns the Viewport this Node2d belongs to
---@return Viewport?
function Node:getViewport()
	return self._parentViewport
end

---This is ran whenever this Node run status switches between running/paused,
---usually due to an ancestor's changes (but not always)
---@param paused boolean
function Node:_pauseStatusChanged(paused)
	if paused then
		self:onPaused()
	else
		self:onResumed()
	end

	-- Tell any children which inherit the pause mode from us that something changed
	for i = 1, #self.children do
		local child = self.children[i]
		if child._pauseMode == "inherit" then
			child:_pauseStatusChanged(paused)
		end
	end
end

---Called via emit; occurs whenever an ancestor's visibility changes
---@param visible boolean
function Node:_eAncestorVisibilityChanged(visible)
	self._ancestorsVisible = visible
	if self._visible then
		self:shallowEmit("_eAncestorVisibilityChanged", visible)
	end
end

---Called when this Node is paused due to changes in the tree
function Node:onPaused() end
---Called when this Node is unpaused due to changes in in the tree
function Node:onResumed() end

---Called when this Node is added somewhere underneath the RootNode
function Node:onAddedToTree()
	-- Get the new Viewport
	local newViewport = self:getTreeViewport()
	if newViewport then
		self._parentViewport = newViewport
		self:onViewportAdded(newViewport)
	end
	self:_intReady()
end

---Called when this Node was formerly under the RootNode, but now removed from it
function Node:onRemovedFromTree()
	-- Remove the Viewport
	if self._parentViewport then
		self:onViewportRemoved(self._parentViewport)
		self._parentViewport = nil
	end
end

function Node:__tostring()
	return self.name or self.CLASS_NAME
end

function Node._addDefinition(entry)
	entry:newString("name")
	entry:newBoolean("_visible", true, "setVisible")
end

return Node
