local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes

local Node2d = Nodes("Node2d")
local Control = Nodes("Control")

---@type Toolbox.Tool
local Tool = require(ADORE_PATH..".toolbox.tool")

---@class Toolbox.Tool.Scale: Toolbox.Tool
---@overload fun(): Toolbox.Tool.Scale
local ScaleTool = Tool:extend()

---@type Toolbox.EditableScene
ScaleTool.srContainer = nil
---@type boolean # If this Tool is busy and should not be switched away from
ScaleTool._busy = false

function ScaleTool:new()
	ScaleTool.super.new(self)
	self.scaling = false
	---@type number, number # The original scale
	self.startScaleX, self.startScaleY = 0, 0
	---@type number, number # The start layer mouse position
	self.startX, self.startY = 0, 0
	---@type number, number # The starting global position
	self.startGX, self.startGY = 0, 0
end

function ScaleTool:mousepressed(mx, my, button, isTouch, pressCount)
	if ScaleTool.super.mousepressed(self, mx, my, button, isTouch, pressCount) then return true end
	if button == 1 and not self.scaling then
		local mainWindow = Tool.mainWindow
		local focusedNode = mainWindow.sceneTree.focusedNode
		if not (focusedNode and focusedNode.parent) then return false end
		local viewport = focusedNode:getViewport()
		if not viewport then return false end
		if not (focusedNode:is(Node2d) or focusedNode:is(Control)) then return false end
		---@cast focusedNode Node2d | Control

		local srContainer = mainWindow:getSubrootContainer()
		self.startX, self.startY =
			Tool.containerToSubLayerPoint(viewport, srContainer:toLocal(mx, my))
		self.startScaleX, self.startScaleY = focusedNode._scale:unpack()
		self.startGX, self.startGY = focusedNode:getWorldPosition()
		self.scaling = true
		return true
	end
	return false
end

function ScaleTool:mousemoved(mx, my, dx, dy, isTouch)
	if ScaleTool.super.mousemoved(self, mx, my, dx, dy, isTouch) then return true end
	if self.scaling then
		local mainWindow = Tool.mainWindow
		local focusedNode = mainWindow.sceneTree.focusedNode
		if not (focusedNode and focusedNode.parent) then return false end
		local viewport = focusedNode:getViewport()
		if not viewport then return false end
		local srContainer = mainWindow:getSubrootContainer()
		---@cast focusedNode Node2d | Control

		local layerX, layerY = Tool.containerToSubLayerPoint(viewport, srContainer:toLocal(mx, my))
		local gx, gy = self.startGX, self.startGY
		local startX, startY = self.startX, self.startY
		local distX, distY = layerX - gx, layerY - gy
		local distStartX, distStartY = startX - gx, startY - gy

		focusedNode:setScale(
			(self.startScaleX * (distX / distStartX)),
			(self.startScaleY * (distY / distStartY))
		)
		return true
	end
	return false
end

function ScaleTool:mousereleased(mx, my, button)
	if ScaleTool.super.mousereleased(self, mx, my, button) then return true end
	if button == 1 and self.scaling then
		self.scaling = false
		return true
	end
	return false
end

return ScaleTool
