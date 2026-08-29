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
local function controlBelongsToLayer(control, desiredLayer, gx, gy)
	return control:hasAncestor(desiredLayer) and control:isVisibleInTree() and control:doesPointOverlapClipped(gx, gy)
end

---Returns `true` if this Node2d overlaps the point and has drawn contents
---@param node Node2d
---@param desiredLayer CanvasLayer | RootNode
---@param worldX integer
---@param worldY integer
---@return Node?
local function node2dOverlapsAndDrawn(node, desiredLayer, worldX, worldY)
	local gcr = node._globalContentRect
	if gcr and node:doesPointOverlap(worldX, worldY) then
		if (node.draw ~= Node2d.draw and not node:is(Light2d)) or node:is(CollisionShape) then
			return node
		end
	end
end

function SelectTool:mousepressed(mx, my, button, isTouch, pressCount)
	if SelectTool.super.mousepressed(self, mx, my, button, isTouch, pressCount) then return true end
	if button == 1 then
		local srContainer = self.srContainer
		local subroot = assert(srContainer.subroot)
		local layers = subroot._canvasLayers

		local containerX, containerY = srContainer:toLocal(mx, my)
		local toSelect = nil
		for i = #layers, 1, -1 do
			local layer = layers[i]
			local viewport = layer._viewport
			local toolboxTransform = viewport._toolboxTransform

			local factor = 1 / viewport._pixelScale
			local usedX, usedY =
				containerX * factor,
				containerY * factor

			local worldX, worldY = toolboxTransform:inverseTransformPoint(usedX, usedY)

			-- Get the highest Control...
			local highestControl = viewport:getControlAtPoint(worldX, worldY, controlBelongsToLayer, layer, worldX, worldY)
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

		local mainWindow = Tool.mainWindow
		if toSelect and mainWindow.sceneTree.iterateMode == "owned" then
			-- If it's an instanced scene, the _owner property won't be equal to the scene root
			local sceneRoot = srContainer:getSceneRoot()
			---@cast toSelect Node
			if sceneRoot then
				-- Find the highest Node that is owned by the scene root
				while toSelect do
					if toSelect._owner == sceneRoot then
						break
					end

					toSelect = toSelect.parent
				end
			end
		end

		mainWindow.sceneTree:selectNode(toSelect)
		mainWindow.inspector:onNodeSelectionChanged(toSelect)
		return true
	end
	return false
end

return SelectTool
