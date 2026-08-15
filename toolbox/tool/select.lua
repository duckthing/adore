local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local Node2d, Control = Nodes("Node2d"), Nodes("Control")
local min, max = math.min, math.max

---@type Toolbox.Tool
local Tool = require(ADORE_PATH..".toolbox.tool")

---@class Toolbox.Tool.Select: Toolbox.Tool
---@overload fun(): Toolbox.Tool.Select
local SelectTool = Tool:extend()

---@type Toolbox.EditableScene
SelectTool.srContainer = nil
---@type boolean # If this Tool is busy and should not be switched away from
SelectTool._busy = false

function SelectTool:new()
	SelectTool.super.new(self)
end

---Used to only select visible Controls below the current layer
---@param control Control
---@param desiredLayer CanvasLayer | RootNode
---@return boolean
local function isBelowCanvasLayer(control, desiredLayer)
	local result = control:hasAncestor(desiredLayer)
	return control:hasAncestor(desiredLayer) and control:isVisibleInTree()
end

function SelectTool:mousepressed(mx, my, button, isTouch, pressCount)
	if button == 1 then
		local srContainer = self.srContainer
		local subroot = assert(srContainer.subroot)
		local layers = subroot._canvasLayers

		local wx, wy = srContainer:toLocal(mx, my)
		local toSelect = nil
		for i = #layers, 1, -1 do
			local layer = layers[i]
			local viewport = layer._viewport
			local toolboxTransform = viewport._toolboxTransform
			local usedX, usedY = wx, wy

			if viewport._pixelScale then
				local factor = 1 / viewport._pixelScale
				usedX, usedY =
					usedX * factor,
					usedY * factor
			end

			local worldX, worldY = toolboxTransform:inverseTransformPoint(usedX, usedY)
			local highestControl = viewport:getControlAtPoint(worldX, worldY, isBelowCanvasLayer, layer)
			if highestControl then
				toSelect = highestControl
				break
			end
		end

		Tool.mainWindow.sceneTree:selectNode(toSelect)
		Tool.mainWindow.inspector:onNodeSelectionChanged(toSelect)
		return false
	else
		return SelectTool.super.mousepressed(self, mx, my, button, isTouch, pressCount)
	end
end

function SelectTool:mousereleased(mx, my, button)
	if button ~= 1 then
		return SelectTool.super.mousereleased(self, mx, my, button)
	end
	return false
end

return SelectTool
