local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes

local Node2d = Nodes("Node2d")
local Light2d = Nodes("Light2d")
local CollisionShape = Nodes("CollisionShape")

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

---Used to select visible Controls below the current layer
---@param control Control
---@param desiredLayer CanvasLayer | RootNode
---@return boolean
local function controlBelongsToLayer(control, desiredLayer)
	return control:hasAncestor(desiredLayer) and control:isVisibleInTree()
end

---Returns `true` if this Node2d overlaps the point and has drawn contents
---@param node Node2d
---@param layer CanvasLayer | RootNode
---@param worldX integer
---@param worldY integer
---@return Node?
local function node2dOverlapsAndDrawn(node, layer, worldX, worldY)
	local gcr = node._globalContentRect
	if gcr and node:doesPointOverlap(worldX, worldY) then
		if (node.draw ~= Node2d.draw and not node:is(Light2d)) or node:is(CollisionShape) then
			return node
		end
	end
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

			-- Get the highest Control...
			local highestControl = viewport:getControlAtPoint(worldX, worldY, controlBelongsToLayer, layer)
			if highestControl then
				toSelect = highestControl
				break
			end

			-- ...or try to get the highest Node2d
			local deepestInLayer = layer:getNode2dAtPoint(worldX, worldY, node2dOverlapsAndDrawn)
			if deepestInLayer then
				toSelect = deepestInLayer
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
