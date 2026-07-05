local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local floor, ceil = math.floor, math.ceil
local min, max = math.min, math.max

local tclear
local tnew
do
	local Structures = Adore.Common("Structures")
	tclear, tnew =
		Structures.tableClear, Structures.tableNew
end

---@class Toolbox.SceneTree: Control
---@overload fun(toolbox: Toolbox): Toolbox.SceneTree
local SceneTreeViewer = Nodes("Control"):extend()
SceneTreeViewer.CLASS_NAME = "SceneTreeViewer"

local font = love.graphics.getFont()
local fontHeight = font:getHeight()

local SCROLL_SPEED = -50
local buttonSize = 12
local labelYOffset = (buttonSize - fontHeight) * 0.5
local labelXOffset = 2

---@param toolbox Toolbox
function SceneTreeViewer:new(toolbox)
	SceneTreeViewer.super.new(self)

	self.toolbox = toolbox

	self.tree = tnew(32, 1)
	self.tree.length = 0

	---@type number # Time since the last update
	self.timeSinceUpdate = 9
	---@type number # Time that needs to pass for the next update to occur
	self.interval = 1
	---@type number # How much we've scrolled
	self.scrollY = 0
	---@type number # The max we can scroll
	self.maxScroll = 0

	---@type Node? # What Node is pressed?
	self.pressedNode = nil
	---@type integer # What is the index of the pressed Node
	self.pressedIndex = 0
	---@type integer # What index is getting hovered over?
	self.hoveredIndex = 0

	---@type Signal # Fired when a new Node is (de)selected
	self.nodeSelected = self:newSignal()
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
local function forEachNode(node, depth, tree)
	local newIndex = #tree + 1
	tree[newIndex], tree[newIndex + 1], tree[newIndex + 2] =
		node, depth, node.name
	tree.length = tree.length + 1
end

function SceneTreeViewer:updateNodes()
	local tree = self.tree
	local start = self.toolbox.subRoot

	local pressedNode = self.pressedNode

	tclear(tree)
	tree.length = 0

	cheapIterateAll(start, forEachNode, tree)
	-- Delay tree updates based off the amount of nodes there are
	self.interval = max(1, min(tree.length * 0.04, 5))
	self.maxScroll = self:getMaxScroll()
	self.scrollY = min(self.maxScroll, self.scrollY)

	if pressedNode then
		if not pressedNode._inTree then
			-- Pressed node was removed from the scene tree
			self.pressedIndex = 0
			self.pressedNode = nil
			self.nodeSelected:fire(nil)
		else
			-- See if we can find it in the scene tree
			for i = 1, tree.length do
				if tree[i * 3 - 2] == pressedNode then
					-- Found it, change the index and exit
					self.pressedIndex = i
					return
				end
			end

			-- We couldn't find it
			self.pressedIndex = 0
			self.pressedNode = nil
			self.nodeSelected:fire(nil)
		end
	end
end

function SceneTreeViewer:onSubrootPushed()
end

function SceneTreeViewer:onSubrootPopped()
end

function SceneTreeViewer:getMaxScroll()
	local height = self._localContentRect.h
	local treeLength = self.tree.length
	return max(0, treeLength * buttonSize - height)
end

---Attempts to select a Node
---@param toSelect Node?
---@param index integer? # Index of the Node in the tree
function SceneTreeViewer:selectNode(toSelect, index)
	if toSelect ~= self.pressedNode then
		-- New (de)selection is different

		if not index then
			-- Find the index, if it wasn't passed
			local tree = self.tree
			for i = 1, tree.length do
				local nodeIndex = i * 3 - 2
				if tree[nodeIndex] == toSelect then
					index = i
					break
				end
			end

			if not index then
				-- Still couldn't find it
				-- Might be an object, inspect it
				self.pressedIndex = 0
				self.pressedNode = nil
				self.nodeSelected:fire(toSelect)
				return
			end
		end
		self.pressedIndex = index

		self.pressedNode = toSelect
		self.nodeSelected:fire(toSelect)
	end
end

function SceneTreeViewer:update(dt)
	local running = self.toolbox.subrootContext.running

	if running then
		self.timeSinceUpdate = self.timeSinceUpdate + dt
		if self.timeSinceUpdate > self.interval then
			self.timeSinceUpdate = 0
			self:updateNodes()
		end
	else
		if self.timeSinceUpdate > 0 then
			self.timeSinceUpdate = 0
			self:updateNodes()
		end
	end
end

---Gets the tree index at the specific screen point
---@param self Toolbox.SceneTree
---@param mx integer
---@param my integer
local function getIndexAtPoint(self, mx, my)
	local tree = self.tree
	local treeLength = tree.length
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

function SceneTreeViewer:mousepressed(mx, my, button)
	local index = getIndexAtPoint(self, mx, my)
	if button == 1 then
		local toSelect = (index ~= 0 and self.tree[index * 3 - 2]) or nil
		self:selectNode(toSelect, index)
	elseif button == 3 then
		-- Middle click to remove Nodes
		---@type Node
		local hoveredNode = self.tree[index * 3 - 2]
		if hoveredNode and hoveredNode._valid and hoveredNode.parent then
			if hoveredNode == self.pressedNode then
				-- If we're removing the selected node, remove it here too
				self.pressedIndex = 0
				self.pressedNode = nil
				self.nodeSelected:fire(nil)
			end

			local toolbox = self.toolbox
			toolbox:pushSubroot()
			hoveredNode.parent:removeChild(hoveredNode, true)
			toolbox:popSubroot()
			self.timeSinceUpdate = self.interval + 1
		end
	end
end

function SceneTreeViewer:uiMouseExited()
	self.hoveredIndex = 0
end

local shouldHighlight = {
	[-2] = true,
	[-1] = true
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
	local pressedIndex = self.pressedIndex
	shouldHighlight[hoveredIndex] = true
	shouldHighlight[pressedIndex] = true

	local yOffset = -scrollY + y + (lowerCull - 1) * buttonSize

	for nodeIndex = lowerCull, min(tree.length, upperCull) do
		local i = nodeIndex * 3 - 2

		local node, depth, name = tree[i], tree[i + 1], tree[i + 2]
		local xOffset = 8 * (depth - 1)

		local rx, ry, rw, rh = x + xOffset, yOffset, w - xOffset, buttonSize
		if shouldHighlight[nodeIndex] then
			love.graphics.setColor(0.4, 0.4, 0.43)
		else
			love.graphics.setColor(0.2, 0.2, 0.24)
		end
		love.graphics.rectangle("fill", rx, ry, rw, rh)
		love.graphics.setColor(0.8, 0.8, 0.8)
		love.graphics.print(name, rx + labelXOffset, ry + labelYOffset)

		yOffset = yOffset + buttonSize
	end

	tclear(shouldHighlight)
end

return SceneTreeViewer
