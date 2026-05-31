---@type AdoreInit
local Adore = require ""
local Node = Adore.Nodes("Node")
local Viewport = Adore.Resources("Viewport")
local min, max = math.min, math.max

---A `CanvasLayer` provides a different `Viewport` to render on that is independent from the current `Viewport`.
---Putting UI on a different layer can make it render independently from the game world.
---A separate physics world and update step is also possible through `Viewport` options.
---
---The rendering logic in Adore is similar to this:
---* At the beginning of `love.draw`, the `RootNode` sets its own `Viewport` as active.
---* All draw commands will go into that `Viewport`.
---* Upon reaching a `CanvasLayer`, the active `Viewport` switches to its own while drawing its children.
---@class CanvasLayer: Node
---@field super Node
---@overload fun(viewportOptions: (Viewport.Options | Viewport)?): CanvasLayer
local CanvasLayer = Node:extend()
CanvasLayer.CLASS_NAME = "CanvasLayer"

do
	-- Mark this class as something that changes a Viewport
	local arr = Node.OVERRIDES_VIEWPORT
	arr[#arr+1] = CanvasLayer
end

---@param viewportOptions (Viewport.Options | Viewport)?
function CanvasLayer:new(viewportOptions)
	CanvasLayer.super.new(self)

	---@type number[] # The color that the drawn contents will be; requires post-processing to be allowed, but not applied
	self.albedo = {1, 1, 1, 1}
	---@type integer # Where the layer is drawn. By default, the Root draws at 1, so do lower if you want to draw behind, or greater to draw after.
	self._layerIndex = 2
	---@type boolean # Whether this CanvasLayer should be affected by the parent's post-processing, such as the parent's lighting
	self._applyParentProcessing = false
	---@type integer? # The shader to use when drawing the CanvasLayer onto the root Viewport; use the contained Viewport if you want more than 1 shader
	---Ignores any post-processing settings.
	self.appliedShaderID = nil
	--TODO: Move CanvasLayer's applied shader into the Viewport?

	---@type boolean # Does this CanvasLayer own its Viewport?
	self._ownsViewport = false
	---@type Viewport # The viewport. Will default to the Root's viewport.
	self._viewport = nil

	self:withViewportOptions(viewportOptions)
end

local function sortLayers(a, b)
	return a._layerIndex < b._layerIndex
end

---Sets the layer index of this CanvasLayer.
---Higher indices will render later than other CanvasLayers, which makes it appear closer to the top.
---@param index any
function CanvasLayer:setIndex(index)
	if index ~= self._layerIndex then
		self._layerIndex = index
		if self._inTree then
			table.sort(self:getRoot()._canvasLayers, sortLayers)
		end
	end
end

---Returns `true` if this CanvasLayer owns the Viewport.
---By default, CanvasLayers will refer to the RootNode's Viewport.
---@return boolean
function CanvasLayer:ownsViewport()
	return self._ownsViewport
end

---Creates a Viewport that this CanvasLayer will use. Children will get drawn to this Viewport first, and then drawn
---to the previously used Viewport.
---Can be used to draw the world and UI at different resolutions.
---@param viewportOptions (Viewport.Options | Viewport)?
function CanvasLayer:withViewportOptions(viewportOptions)
	-- Destroy the old Viewport, if it exists
	do
		local oldViewport = self._viewport
		if oldViewport and not self:ownsViewport() then
			oldViewport:release()
		end
	end

	if viewportOptions then
		if viewportOptions.CLASS_NAME and viewportOptions:is(Viewport) then
			-- This Viewport was created already; we don't own it
			---@cast viewportOptions Viewport

			self._viewport = viewportOptions
			self._ownsViewport = false
		else
			-- Viewport options were passed instead; create a new one
			---@cast viewportOptions Viewport.Options

			self._viewport = Viewport(viewportOptions)
			self._ownsViewport = true
			-- Parent viewport will always be the Root when using a CanvasLayer
			self._viewport._parentViewport = Node._root._viewport


			---Returns the safe area of the Viewport when inside a CanvasLayer
			---@param viewport Viewport
			local function viewportGetSafeArea(viewport)
				local gx, gy, gw, gh = self:getRoot():getViewport():getSafeArea()
				local x, y = viewport:windowToViewportPoint(gx, gy)
				local w, h = viewport:windowToViewportPoint(gx + gw, gy + gh)

				return
					max(0, x),
					max(0, y),
					min(w, viewport._canvasW),
					min(h, viewport._canvasH)
			end
			self._viewport.getSafeArea = viewportGetSafeArea
		end
	else
		-- Use the root's Viewport when there isn't any options passed
		self._ownsViewport = false
		self._viewport = Node._root._viewport
	end

	self:shallowEmit("_eAncestorViewportChanged", self._viewport)
end

---Destroys the Viewport contained inside of this CanvasLayer
function CanvasLayer:removeViewport()
	local viewport = self._viewport
	if not self:ownsViewport() then return end

	viewport:release()
	self._viewport = nil
	self:shallowEmit("_eAncestorViewportChanged", self:getTreeViewport())
end

function CanvasLayer:_eAncestorViewportChanged(newViewport)
	-- Don't continue emitting past here; the ancestor Viewport is irrelevant past this CanvasLayer
	local ownViewport = self._viewport
	if ownViewport then
		if not ownViewport._ownsWorld then
			if newViewport then
				ownViewport._physicsWorld = newViewport._physicsWorld
			else
				ownViewport._physicsWorld = nil
			end
		end
	end
end

-- Prevents drawing
function CanvasLayer:_intDraw() end

-- local appleCakeProfileDrawLayer

function CanvasLayer:drawLayer()
	-- appleCakeProfileDrawLayer = AppleCake.profile("CanvasLayer:drawLayer", nil, appleCakeProfileDrawLayer)
	local viewport = self._viewport
	if not self:ownsViewport() then
		self:_beforeDraw()
		self:_drawChildren()
		self:_afterDraw()
	else
		-- viewport:fitInto(love.graphics.getCanvas():getDimensions())
		viewport:push()
		-- These lines are commented, since the Viewport applies its own transform
		-- self:_beforeDraw()
		self:_drawChildren()
		-- self:_afterDraw()
		viewport:pop()
		viewport:drawFittedContents(0, 0)
	end
	-- appleCakeProfileDrawLayer:stop()
end

-- local appleCakeProfileDrawChildren

function CanvasLayer:_drawChildren()
	-- appleCakeProfileDrawChildren = AppleCake.profile("CanvasLayer:_drawChildren")
	CanvasLayer.super._drawChildren(self)
	-- appleCakeProfileDrawChildren:stop()
end

function CanvasLayer:onAddedToTree()
	CanvasLayer.super.onAddedToTree(self)
	local layers = self:getRoot()._canvasLayers
	-- Add it to layers that will be drawn
	layers[#layers+1] = self
	table.sort(layers, sortLayers)
end

function CanvasLayer:onRemovedFromTree()
	CanvasLayer.super.onRemovedFromTree(self)
	local layers = self:getRoot()._canvasLayers
	-- Find the index of this
	local found = 0
	for i = 1, #layers do
		if layers[i] == self then
			found = i
			break
		end
	end

	-- Remove it from drawn layers, if found
	if found ~= 0 then
		table.remove(layers, found)
	end
end

---In a CanvasLayer, this will return either the Viewport inside this CanvasLayer, or the parent Viewport
---@return Viewport?
function CanvasLayer:getViewport()
	return self._viewport or CanvasLayer.super.getViewport(self)
end

---Used for deserialization
---@param newViewport Viewport
function CanvasLayer:_setViewport(newViewport)
	self._viewport = newViewport
	self:shallowEmit("_eAncestorViewportChanged", self._viewport)
end

function CanvasLayer:update(dt)
	local viewport = self._viewport
	if viewport then
		self._viewport:update(dt)
	end
end

function CanvasLayer:forceDestroy(...)
	CanvasLayer.super.forceDestroy(self, ...)
	if self._viewport and self:ownsViewport() then
		self._viewport:release()
	end
end

function CanvasLayer._addDefinition(entry)
	entry:newInteger("_layerIndex", 2, nil, nil, nil, "setIndex")
	entry:newObject("_viewport", "Viewport", "_setViewport")
	entry:newBoolean("_ownsViewport", false)
end
CanvasLayer:getClassDBEntry()

return CanvasLayer
