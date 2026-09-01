local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local tclear = Adore.Common("Structures").tableClear
local floor, ceil = math.floor, math.ceil
local min, max = math.min, math.max

---@class Toolbox.SceneTree: Control
---@overload fun(toolbox: Toolbox): Toolbox.SceneTree
local SceneTreeViewer = Nodes("Control"):extend()
SceneTreeViewer.CLASS_NAME = "SceneTreeViewer"

local font = love.graphics.getFont()
local fontHeight = font:getHeight()

local SCROLL_SPEED = -50
local buttonSize = 14
local labelYOffset = (buttonSize - fontHeight) * 0.5
local labelXOffset = 2

---@param toolbox Toolbox
---@param container Toolbox.EditableScene
function SceneTreeViewer:new(toolbox, container)
	SceneTreeViewer.super.new(self)

	self.toolbox = toolbox

	---@type Toolbox.EditableScene? # The current subroot container
	self.subrootContainer = container
	---@type Node? # Where the tree begins searching
	self.startNode = container.subroot

	---@type "full" | "owned" # How to build the tree
	self.iterateMode = "full"

	---@type table # Array of elements in the tree
	self.tree = {}
	---@type integer # The number of Nodes in this tree; equal to `#tree / 3`
	self.treeLength = 0
	---@type boolean # [Default: `true`] If this SceneTreeViewer can make changes to the internal tree.
	---Only relevant if we're re-using the table somewhere else.
	self.shouldUpdateTree = true
	---@type boolean # [Default: `true`] Pressing a Node focuses on it
	self.focusPressedNode = true

	---@type number # Time since the last update
	self.timeSinceUpdate = 9
	---@type number # Time that needs to pass for the next update to occur
	self.interval = 1
	---@type number # How much we've scrolled
	self.scrollY = 0
	---@type number # The max we can scroll
	self.maxScroll = 0

	---@type Node? # What Node is focused?
	self.focusedNode = nil
	---@type integer # What is the index of the focused Node
	self.focusedIndex = 0
	---@type integer # What index is getting hovered over?
	self.hoveredIndex = 0

	---@type integer # The tree index the mouse is pressing down on
	self._pressedIndex = 0

	---@type Signal # Fired when a Node is pressed, with arguments (self, pressedNode, mouseButton, isTouch, pressCount)
	self.nodePressed = self:newSignal()
	---@type Signal # Fired when a Node is released, with arguments (self, releasedNode, mouseButton)
	self.nodeReleased = self:newSignal()
	---@type Signal # Fired when a Node is (un)focused, with (self, focusedNode, inTree)
	self.nodeFocused = self:newSignal()
end

---@type Node[]
local parents = {}
---@type integer[]
local childIndices = {}

---Similar to Node:emit(), but without tail calls
---@param start Node
---@param func fun(node: Node, depth: integer, ...)
local function cheapIterateAll(start, func, ...)
	parents[1] = start
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

---@param node Node
---@param depth integer
---@param tree table
---@param owner Node?
local function forEachNodeOwned(node, depth, tree, owner)
	if node._owner == owner or node == owner then
		local newIndex = #tree + 1
		tree[newIndex], tree[newIndex + 1], tree[newIndex + 2] =
			node, depth, node.name
	end
end

---@param node Node
---@param depth integer
---@param tree table
local function forEachNodeFull(node, depth, tree)
	local newIndex = #tree + 1
	tree[newIndex], tree[newIndex + 1], tree[newIndex + 2] =
		node, depth, node.name
end

---Updates the scene tree contents.
---Only called if `shouldUpdateTree` is `true`.
function SceneTreeViewer:updateNodes()
	local tree = self.tree
	local start = self.startNode

	tclear(tree)
	if not start then
		self.treeLength = 0
		return
	end

	local forEach = self.iterateMode == "owned" and forEachNodeOwned or forEachNodeFull

	cheapIterateAll(start, forEach, tree, start.children[1])
	local treeLength = floor(#tree * 0.3333334)
	self.treeLength = treeLength

	-- Delay tree updates based off the amount of nodes there are
	self.interval = max(1, min(treeLength * 0.04, 5))
	self.maxScroll = self:getMaxScroll()
	self.scrollY = min(self.maxScroll, self.scrollY)

	local pressedNode = self.focusedNode
	if pressedNode then
		if not pressedNode._inTree then
			-- Pressed node was removed from the scene tree
			self.focusedIndex = 0
			self.focusedNode = nil
			self.nodeFocused:fire(self, nil, false)
		else
			-- See if we can find it in the scene tree
			for i = 1, treeLength do
				if tree[i * 3 - 2] == pressedNode then
					-- Found it, change the index and exit
					self.focusedIndex = i
					return
				end
			end

			-- We couldn't find it
			self.focusedIndex = 0
			self.focusedNode = nil
			self.nodeFocused:fire(self, nil, false)
		end
	end
end

---Returns the pressed Node, if it's valid
---@return Node?
function SceneTreeViewer:getPressedNode()
	local pressed = self.focusedNode
	return (pressed and pressed._valid and pressed) or nil
end

---Returns how far we can scroll, with the current Control height and tree length
---@return integer
function SceneTreeViewer:getMaxScroll()
	local height = self._localContentRect.h
	local treeLength = self.treeLength
	return max(0, treeLength * buttonSize - height)
end

---Sets the start node, which is where the scene tree begins
---@param node Toolbox.EditableScene?
function SceneTreeViewer:setStartNode(node)
	if self.subrootContainer ~= node then
		self.subrootContainer = node
		self.startNode = node and node.subroot or nil
		self:updateNodes()
	end
end

---Returns the internal tree index of a Node.
---* If it doesn't belong to the tree/is `nil`, `nil` is returned
---* If it is in the tree, but isn't 'visible' in the viewer, `nil` is returned
---	* A Node can be invisible in "owned" mode
---* The internal index may be incorrect after a tree update
---@param node Node?
---@return integer? index
function SceneTreeViewer:getTreeIndexOfNode(node)
	if node then
		local tree = self.tree
		for i = 1, self.treeLength do
			local nodeIndex = i * 3 - 2
			if tree[nodeIndex] == node then
				return i
			end
		end
	end
end

---Returns the Node at the internal tree index.
---@param index integer?
---@return Node?
function SceneTreeViewer:getNodeFromTreeIndex(index)
	if index and index ~= 0 then
		return (index ~= 0 and self.tree[index * 3 - 2]) or nil
	end
end

---Attempts to focus a Node
---@param toSelect Node?
---@param index integer? # Index of the Node in the tree
function SceneTreeViewer:focusNode(toSelect, index)
	if toSelect ~= self.focusedNode then
		-- New (de)selection is different

		-- Find the index of a Node, if it wasn't passed
		index = index or self:getTreeIndexOfNode(toSelect)

		if not index then
			-- Still couldn't find it (outside of tree)
			-- Might be an object, inspect it
			self.focusedIndex = 0
			self.focusedNode = nil
			self.nodeFocused:fire(self, toSelect, false)
			return
		end

		-- Index is valid here, meaning it's in the tree
		self.focusedIndex = index
		self.focusedNode = toSelect
		self.nodeFocused:fire(self, toSelect, true)
	end
end

---Gets the tree index at the specific screen point
---@param self Toolbox.SceneTree
---@param mx integer
---@param my integer
local function getIndexAtPoint(self, mx, my)
	if not self:doesPointOverlap(mx, my) then
		return 0
	end

	local treeLength = self.treeLength
	local index = ceil((self.scrollY - self._localContentRect.y + my) / buttonSize)

	if index > 0 and index <= treeLength then
		return index
	else
		return 0
	end
end

function SceneTreeViewer:wheelmoved(_, y)
	self.scrollY = max(0, min(self.scrollY + y * SCROLL_SPEED, self.maxScroll))
	self.hoveredIndex = getIndexAtPoint(self, love.mouse.getPosition())
end

function SceneTreeViewer:mousemoved(mx, my)
	self.hoveredIndex = getIndexAtPoint(self, mx, my)
end

function SceneTreeViewer:mousepressed(mx, my, button, isTouch, pressCount)
	local index = getIndexAtPoint(self, mx, my)
	local pressedNode = self:getNodeFromTreeIndex(index)
	if index and pressedNode then
		self._pressedIndex = index
		self.nodePressed:fire(self, pressedNode, button, isTouch, pressCount)
		self:pushModal()
		return true
	end
end

function SceneTreeViewer:mousereleased(mx, my, button)
	local index = getIndexAtPoint(self, mx, my)
	if self._pressedIndex == index then
		local pressedNode = self:getNodeFromTreeIndex(index)

		if pressedNode then
			self.nodeReleased:fire(self, pressedNode, button)
			if button == 1 and self.focusPressedNode then
				self:focusNode(pressedNode, index)
			end
		end
	end
	self._pressedIndex = nil
	self:popModal()
end

function SceneTreeViewer:uiMouseExited()
	-- Unhover
	self.hoveredIndex = 0
end

function SceneTreeViewer:update(dt)
	local running = self.toolbox.subrootContext.running

	if self.shouldUpdateTree then
		if running then
			-- Running, tick until we should update
			self.timeSinceUpdate = self.timeSinceUpdate + dt
			if self.timeSinceUpdate > self.interval then
				self.timeSinceUpdate = 0
				self:updateNodes()
			end
		else
			-- Not running, update once
			if self.timeSinceUpdate > 0 then
				self.timeSinceUpdate = 0
				self:updateNodes()
			end
		end
	else
		-- Constantly update the tree length since we don't own this table
		self.treeLength = floor(#self.tree * 0.3333334)
	end
end

local selectedColor = {0.4, 0.4, 0.43}
local pressedColor = {0.15, 0.15, 0.2}
local normalColor = {0.2, 0.2, 0.24}

---@type {[integer]: number[]}
local nodeHighlights = {
	[-3] = nil,
	[-2] = nil,
	[-1] = nil
}
function SceneTreeViewer:draw()
	SceneTreeViewer.super.draw(self)

	local tree = self.tree

	local x, y, w, h = self._localContentRect:unpack()
	love.graphics.intersectScissor(x, y, w, h)

	love.graphics.setFont(font)
	local scrollY = self.scrollY

	-- The range we'll render buttons
	local lowerCull = floor(scrollY / buttonSize) + 1
	local upperCull = ceil((h + scrollY) / buttonSize)

	local hoveredIndex = self.hoveredIndex
	local focusedIndex = self.focusedIndex
	local pressedIndex = self._pressedIndex
	nodeHighlights[hoveredIndex] = selectedColor
	nodeHighlights[focusedIndex] = selectedColor
	if pressedIndex then
		nodeHighlights[hoveredIndex] = nil
		nodeHighlights[pressedIndex] = pressedColor
	end

	local yOffset = -scrollY + y + (lowerCull - 1) * buttonSize

	for nodeIndex = lowerCull, min(self.treeLength, upperCull) do
		local i = nodeIndex * 3 - 2

		local depth, name = tree[i + 1], tree[i + 2]
		local xOffset = 8 * (depth - 1)

		local rx, ry, rw, rh = x + xOffset, yOffset, w - xOffset, buttonSize
		love.graphics.setColor(nodeHighlights[nodeIndex] or normalColor)
		love.graphics.rectangle("fill", rx, ry, rw, rh)
		love.graphics.setColor(0.8, 0.8, 0.8)
		love.graphics.print(name, rx + labelXOffset, ry + labelYOffset)

		yOffset = yOffset + buttonSize
	end

	tclear(nodeHighlights)
end

return SceneTreeViewer
