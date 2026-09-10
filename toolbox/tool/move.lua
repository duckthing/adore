local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes

local Node2d = Nodes("Node2d")
local Control = Nodes("Control")

---@type Toolbox.Tool
local Tool = require(ADORE_PATH..".toolbox.tool")

---@class Toolbox.Tool.Move: Toolbox.Tool
---@overload fun(): Toolbox.Tool.Select
local MoveTool = Tool:extend()

---@type Toolbox.EditableScene
MoveTool.srContainer = nil
---@type boolean # If this Tool is busy and should not be switched away from
MoveTool._busy = false

function MoveTool:new()
	MoveTool.super.new(self)
	self.moving = false
	---@type "Node2d" | "Control"
	self.selectionType = "Node2d"
end

function MoveTool:mousepressed(mx, my, button, isTouch, pressCount)
	if MoveTool.super.mousepressed(self, mx, my, button, isTouch, pressCount) then return true end
	if button == 1 and not self.moving then
		local mainWindow = Tool.mainWindow
		local focusedNode = mainWindow.sceneTree.focusedNode
		if not (focusedNode and focusedNode.parent) then return false end

		if focusedNode:is(Node2d) then
			self.selectionType = "Node2d"
		elseif focusedNode:is(Control) then
			self.selectionType = "Control"
		else
			return false
		end

		self.moving = true
		return true
	end
	return false
end

function MoveTool:mousemoved(mx, my, dx, dy, isTouch)
	if MoveTool.super.mousemoved(self, mx, my, dx, dy, isTouch) then return true end
	if self.moving then
		local selectionType = self.selectionType
		local mainWindow = Tool.mainWindow
		local focusedNode = mainWindow.sceneTree.focusedNode
		if not (focusedNode and focusedNode.parent) then return false end
		local viewport = focusedNode:getViewport()
		if not viewport then return false end

		local scaledDX, scaledDY = Tool.containerToSubLayerChange(viewport, dx, dy)

		if selectionType == "Node2d" then
			---@cast focusedNode Node2d
			local gx, gy = focusedNode:getPosition(true)
			scaledDX, scaledDY = focusedNode:toLocal(gx + scaledDX, gy + scaledDY)
			local scale = focusedNode._scale
			focusedNode:translate(scaledDX * scale.x, scaledDY * scale.y)
		elseif selectionType == "Control" then
			---@cast focusedNode Control
			local gx, gy = focusedNode._globalContentRect.x, focusedNode._globalContentRect.y
			scaledDX, scaledDY = focusedNode:toLocal(gx + scaledDX, gy + scaledDY)
			local scale = focusedNode._scale
			focusedNode:translate(scaledDX * scale.x, scaledDY * scale.y)
		end
		return true
	end
	return false
end

function MoveTool:mousereleased(mx, my, button)
	if MoveTool.super.mousereleased(self, mx, my, button) then return true end
	if button == 1 and self.moving then
		self.moving = false
		return true
	end
	return false
end

return MoveTool
