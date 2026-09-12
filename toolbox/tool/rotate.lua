local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes

local Node2d = Nodes("Node2d")
local Control = Nodes("Control")

---@type Toolbox.Tool
local Tool = require(ADORE_PATH..".toolbox.tool")

---@class Toolbox.Tool.Rotate: Toolbox.Tool
---@overload fun(): Toolbox.Tool.Rotate
local RotateTool = Tool:extend()

---@type Toolbox.EditableScene
RotateTool.srContainer = nil
---@type boolean # If this Tool is busy and should not be switched away from
RotateTool._busy = false

function RotateTool:new()
	RotateTool.super.new(self)
	self.rotating = false
	---@type number
	self.startRotation = 0
end

function RotateTool:mousepressed(mx, my, button, isTouch, pressCount)
	if RotateTool.super.mousepressed(self, mx, my, button, isTouch, pressCount) then return true end
	if button == 1 and not self.rotating then
		local mainWindow = Tool.mainWindow
		local focusedNode = mainWindow.sceneTree.focusedNode
		if not (focusedNode and focusedNode.parent) then return false end
		local viewport = focusedNode:getViewport()
		if not viewport then return false end
		if not (focusedNode:is(Node2d) or focusedNode:is(Control)) then return false end
		---@cast focusedNode Node2d | Control

		local srContainer = mainWindow:getSubrootContainer()
		local layerX, layerY =
			Tool.containerToSubLayerPoint(viewport, srContainer:toLocal(mx, my))
		local gx, gy = focusedNode:getWorldPosition()
		self.startRotation = focusedNode:getRotation() - math.atan2(layerY - gy, layerX - gx)
		self.rotating = true
		return true
	end
	return false
end

function RotateTool:mousemoved(mx, my, dx, dy, isTouch)
	if RotateTool.super.mousemoved(self, mx, my, dx, dy, isTouch) then return true end
	if self.rotating then
		local mainWindow = Tool.mainWindow
		local focusedNode = mainWindow.sceneTree.focusedNode
		if not (focusedNode and focusedNode.parent) then return false end
		local viewport = focusedNode:getViewport()
		if not viewport then return false end
		local srContainer = mainWindow:getSubrootContainer()
		---@cast focusedNode Node2d | Control

		local layerX, layerY = Tool.containerToSubLayerPoint(viewport, srContainer:toLocal(mx, my))
		if focusedNode:is(Control) then
			---@cast focusedNode Control
			focusedNode:deferRefreshSelf()
			focusedNode:getViewport():performRefreshesUntilDone()
		end
		local gx, gy = focusedNode:getWorldPosition()
		local angle = math.atan2(layerY - gy, layerX - gx)
		focusedNode:setRotation(angle + self.startRotation)
		return true
	end
	return false
end

function RotateTool:mousereleased(mx, my, button)
	if RotateTool.super.mousereleased(self, mx, my, button) then return true end
	if button == 1 and self.rotating then
		self.rotating = false
		return true
	end
	return false
end

return RotateTool
