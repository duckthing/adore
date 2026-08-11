---@type AdoreInit
local Adore = require ""
local Nodes = Adore.Nodes
local Common = Adore.Common

local Node = Nodes("Node")
local Physical2d = Nodes("Physical2d")
local Object = Adore.Resources("Object")
local Rect2 = Common("Rect2")
local Signal = Common("Signal")
local Shash = Adore.Libraries("Shash")
---@type LightModel
local LightModel = require "data.lightmodel"

local _, shaderAssets = Adore.Loader.getCollection("ShaderLoader")

local min, max, floor, ceil, huge =
	math.min, math.max, math.floor, math.ceil, math.huge
local tclear = Common("Structures").tableClear

---@class Viewport: Object
---@field super Object
---@overload fun(options: Viewport.Options?): Viewport
local Viewport = Object:extend()
Viewport.CLASS_NAME = "Viewport"

---@alias Viewport.Options.ScaleMode
---| "resize" # Resizes the canvas' dimensions, ignoring the target dimensions (default Love2D behavior)
---| "fraction" # Keeps the target dimensions, and draws a scaled canvas
---| "integer" # Keeps the target dimensions, and draws a scaled canvas while keeping the pixel scale an integer

---@alias Viewport.Options.Aspect
---| "ignore" # Stretches the canvas to fit the window's resolution, without preference
---| "keep" # Keeps the aspect ratio when stretching, leaving extra space in the window around the canvas

---@alias Viewport.Options.CanvasSettings
---| {type: love.TextureType?, format: love.PixelFormat?, readable: boolean?, msaa: integer?, mipmaps: love.MipmapMode?}

---@alias Viewport.Options.Lighting
---| {mode: LightModel.LightMode?, ambientLight: number[]?, lightPostProcessing: boolean?}

---@alias Viewport.PhysicsSpeedMultiplier
---| "never" # Always use the target step
---| "increase" # Increase the target step when the game speed is sped up
---| "decrease" # Decrease the target step when the game speed is slowed
---| "any" # Increase/decrease the target step with the game speed

---@class Viewport.Options
---@field windowWidth integer? # The width this Viewport is asked to fit into
---@field windowHeight integer? # The height this Viewport is asked to fit into
---@field targetWidth integer? # The initial width of the internal Canvas; ignored when using the "resize" scale mode
---@field targetHeight integer? # The initial height of the internal Canvas; ignored when using the "resize" scale mode
---@field pixelScale number?
---@field scaleMode Viewport.Options.ScaleMode?
---@field aspect Viewport.Options.Aspect?
---Whether there can be post-processing **at all**, and if internal objects for it should be created or released.
---Needs `applyPostProcessing` to actually do post-processing.
---@field allowPostProcessing boolean?
---@field applyPostProcessing boolean? # If post-processing is allowed, should it be applied right now?
---@field includeStencil boolean?
---@field canvasSettings Viewport.Options.CanvasSettings?
---@field lightingSettings Viewport.Options.Lighting?
---@field physicsWorld love.World? # Can only be set once; automatically set if `nil` inside a CanvasLayer
---@field ownsPhysicsWorld boolean? # Whether this love.World was created for this Viewport; if set incorrectly, the love.World may get updated multiple times each frame, or never
---@field shouldDrawPhysics boolean? # Whether we should draw the physics objects in the love.World that was set
---@field targetPhysicsStep number? # How often should we step; default is 1/60
---@field maxPhysicsSteps integer? # How many steps can happen in one frame; default is 3
---@field multiplyMaxSteps boolean? # Should the max physics step get multiplied by the game speed; default is true
---@field multiplyPhysicsSteps Viewport.PhysicsSpeedMultiplier? # Should the physics step amount get multiplied by the game speed; default is "decrease"

local DEFAULT_COLOR = {1, 1, 1}
---How many times to perform a deferred refresh.
---When a refresh is performed, a Control's theme may request another refresh.
---We can do this multiple times, but in case there's a loop, stop
---@type integer
local MAX_REFRESHES = 5

---@param options Viewport.Options
function Viewport:new(options)
	Viewport.super.new(self)

	-- Fix canvas options
	if not options then
		options = {}
	end

	local windowW, windowH = 0, 0
	do
		-- Get the dimensions of the RootNode's Viewport (or the window, if the RootNode doesn't exist yet)
		-- The Viewport is always dependent on whatever it is above
		local root = Node._root
		if root and root._viewport then
			windowW, windowH = root._viewport:getDimensions()
		else
			windowW, windowH = love.graphics.getDimensions()
		end
	end


	---======== DRAW STACK
	---@type Viewport? # The Viewport that was active before :push() was called
	self._lastViewport = nil
	---@type Viewport? # The parent Viewport that contains this one.
	---When using CanvasLayers, the parent Viewport is usually the RootNode's Viewport
	self._parentViewport = nil


	---======== WINDOW SCALING
	---@type integer, integer # The current canvas dimensions
	self._canvasW, self._canvasH =
		options.targetWidth or windowW,
		options.targetHeight or windowH
	---@type integer, integer # The dimensions the viewport is asked to fit into
	self._windowW, self._windowH =
		options.windowWidth or self._canvasW,
		options.windowHeight or self._canvasH
	---@type number # New canvas dimensions will get divided by this number
	self._pixelScale = options.pixelScale or 1
	---@type Viewport.Options.ScaleMode
	self._scaleMode =
		options.scaleMode or "resize"
	---@type Viewport.Options.Aspect
	self._aspect = options.aspect or "keep"


	---======== CANVAS
	---@type love.Canvas
	self._mainCanvas = nil
	---@type love.Canvas?
	self._altCanvas = nil
	---@type love.Canvas?
	self._stencilCanvas = nil
	---@type boolean # If the stencil should be created; required for some uses (like shadows)
	self._includeStencil = options.includeStencil or false
	---@type boolean # If true, `_mainCanvas` has the resulting image. Otherwise, `_altCanvas` has it.
	self._mainIsFinal = true
	---@type boolean # Internal
	self._usingBufferLayer = false
	---@type Viewport.Options.CanvasSettings # What Love2D settings will be used when creating the canvas
	self._canvasSettings = options.canvasSettings or {}
	---@type boolean # Whether new Canvases should be created  (due to ex. different canvas settings)
	self.remakeCanvases = true
	---@type Rect2 # The bounding box that contains all visible content
	self._boundingBox = Rect2(0, 0, 0, 0)
	---@type love.Transform # The default Transform when drawing
	self._viewportTransform = love.math.newTransform()
	---@type Camera? # The Camera used to view around the scene
	self._activeCamera = nil


	---======== CONTROL
	self._controlShash = Shash.new()
	self._safeArea = Rect2(0, 0, 0, 0)
	---@type {[Control]: "self" | "children"} # A map of Controls which want to refresh their children
	self._deferredRefresh = {}
	---@type {[number]: {[Control]: "children" | "self"}} # Used internally, don't modify it
	self._depthArray = {}


	---======== SHADERS
	---Whether there can be post-processing **at all**, and if internal objects for it should be created or released.
	---Needs `applyPostProcessing` to actually do post-processing.
	---@type boolean
	self._allowPostProcessing = options.allowPostProcessing or false
	---@type boolean # If post-processing is allowed, should it be applied right now?
	self.applyPostProcessing = options.applyPostProcessing
	if self.applyPostProcessing == nil then
		self.applyPostProcessing = self._allowPostProcessing
	end
	---@type AssetID[] # An array of shader AssetIDs that will get applied to the rendered Canvas
	self.shaderIDs = {}


	---======== LIGHTING
	local lightSettings = options.lightingSettings
	---@type number[] # The ambient light of the world
	self._ambientLight = (lightSettings and lightSettings.ambientLight) or {1, 1, 1}
	---The Shash that is queried to get each Light2d in an area
	self._lightShash = Shash.new()
	---The Shash that is queried to get each ShadowCaster2d in an area
	self._shadowShash = Shash.new()
	---@type LightModel
	self._lightModel = LightModel(self, (lightSettings and lightSettings.mode) or "none", (lightSettings and lightSettings.lightPostProcessing))


	---======== PHYSICS
	self.physicsStepped = Signal.new(self)
	local world = options.physicsWorld
	local ownsIt = options.ownsPhysicsWorld

	if not world then
		ownsIt = false
		if Node._root and Node._root._viewport then
			world = Node._root._viewport._physicsWorld
		end
	elseif ownsIt == nil then
		-- Assume we own this world if it was provided
		ownsIt = true
	end

	---@type love.World? # The love.World that Physical2d nodes will get added to
	self._physicsWorld = world
	---@type boolean # Whether the love.World contained in this Viewport belongs to this Viewport (ex. not inherited).
	self._ownsWorld = ownsIt

	if world and ownsIt then
		Physical2d.addWorldList(world)
		world:setCallbacks(Physical2d.getWorldCallbacks())
	end

	---@type number # The value passed into the physics step.
	---Set to `0` to make stepping dynamic.
	---Default: `60 hz`, which is `1/60`
	self.targetPhysicsStep = options.targetPhysicsStep or 0.01666666666666667
	---@type integer # Max amount of steps we can do in one `:update()`.
	---Additional steps may look like 'jitter'/'skipping', but allow the simulation to catch up.
	---Set to `math.huge` to allow physics to catch up infinitely.
	---Default: `1`
	self.maxPhysicsSteps = options.maxPhysicsSteps or 1
	---@type Viewport.PhysicsSpeedMultiplier # Multiplies the step interval by the Root's game speed; this behaves strangely when increasing is allowed
	self.multiplyPhysicsSteps = options.multiplyPhysicsSteps or "decrease"
	---@type boolean # The requested step count is multipled and `ceil`ed by the Root's game speed if `true`.
	self.multiplyMaxSteps = options.multiplyMaxSteps
	if self.multiplyMaxSteps == nil then
		self.multiplyMaxSteps = true
	end
	---@type number # How behind is the stepping? A step will occur when this value is greated than the physics step.
	self._physicsStepRollover = 0

	---@type boolean # Whether we should draw the physics objects inside of love.World;
	---If post-processing is allowed, post-processing must be applied for it to happen
	self.shouldDrawPhysics = options.shouldDrawPhysics or false

	self:_onOptionsChanged()
end

do
local stencilOption = {format = "stencil8"}

---Returns `true` if the `love.Canvas` matches the `settings`
---@param canvas love.Canvas?
---@param settings Viewport.Options.CanvasSettings?
local function doSettingsMatch(canvas, settings)
	if settings then
		-- Canvas doesn't exist while settings do; return false
		if not canvas then return false end
		if settings.type and canvas:getTextureType() ~= settings.type then return false end
		if settings.format and canvas:getFormat() ~= settings.format then return false end
		if settings.readable ~= nil and canvas:isReadable() ~= settings.readable then return false end
		-- MSAA can't be checked as the system may not support the requested amount
		if settings.mipmaps and canvas:getMipmapCount() ~= settings.mipmaps then return false end
	elseif canvas then
		-- Canvas exists while settings do not; return false
		return false
	end
	-- Settings match
	return true
end

---Call this to create the new `love.Canvas` objects from the `Viewport` options.
---Called automatically in `RootNode:resize()` and `Viewport:fitInto()`.
function Viewport:_onOptionsChanged()
	do
		-- Target dimension might have changed
		local targetW, targetH = self._canvasW, self._canvasH
		local pixelScale = self._pixelScale
		local pixelFactor = 1 / pixelScale

		if self._scaleMode == "resize" then
			-- Resizing to fit the canvas to the window
			targetW, targetH =
				ceil(self._windowW * pixelFactor),
				ceil(self._windowH * pixelFactor)
			self._canvasW, self._canvasH = targetW, targetH
		end
		self._lightModel:_viewportOptionsChanged()

		if not self._allowPostProcessing and self._altCanvas then
			-- No more post-processing
			self._altCanvas:release()
			self._altCanvas = nil
		end

		local mainCanvas = self._mainCanvas
		local canvasSettings = self._canvasSettings
		local shouldRemake = self.remakeCanvases
			or not mainCanvas or mainCanvas:getWidth() ~= targetW or mainCanvas:getHeight() ~= targetH
			or not doSettingsMatch(mainCanvas, canvasSettings)
		if shouldRemake then
			-- Canvases should be remade
			self.remakeCanvases = false

			-- Update the camera transform
			if self._activeCamera then
				self._activeCamera:_updateCanvasTransform(targetW, targetH)
			end

			if mainCanvas then
				-- Release the main canvas, if it exists
				self._mainCanvas:release()
			end

			self._mainCanvas = love.graphics.newCanvas(targetW, targetH, canvasSettings)

			if self._altCanvas then
				-- Release the alternate canvas, if it exists
				self._altCanvas:release()
				self._altCanvas = nil
			end

			if self._stencilCanvas then
				-- Release the stencil canvas, if it exists
				self._stencilCanvas:release()
				self._stencilCanvas = nil
			end
		end

		if self._allowPostProcessing and not self._altCanvas then
			-- Post-processing is allowed, create the alt-canvas
			self._altCanvas = love.graphics.newCanvas(targetW, targetH, canvasSettings)
		end

		if self._includeStencil then
			-- Stencil canvas is allowed, create it
			self._stencilCanvas = love.graphics.newCanvas(targetW, targetH, stencilOption)
		end
	end
	self:_updateViewportTransform()
end
end

---Updates the Viewport's canvas size, position and scale to fit the window
function Viewport:_updateViewportTransform()
	-- Update the canvas positioning
	local aspect, scaleMode =
		self._aspect,
		self._scaleMode

	local windowW, windowH = self._windowW, self._windowH
	local canvasW, canvasH = self._canvasW, self._canvasH

	local scaleW, scaleH = 1, 1
	local offsetX, offsetY = 0, 0

	-- Resize scale mode does nothing when pixel scale is 1
	if scaleMode ~= "resize" or self._pixelScale ~= 1 then
		if aspect == "ignore" then
			scaleW, scaleH =
				windowW / canvasW,
				windowH / canvasH
		else
			-- Keep aspect
			local scale =
				min(
					windowW / canvasW,
					windowH / canvasH
				)

			scaleW, scaleH = scale, scale
		end

		if scaleMode == "integer" then
			scaleW, scaleH =
				max(floor(scaleW), 1),
				max(floor(scaleH), 1)
		end
		-- Fractional scale mode does nothing to the scale

		local scaledW, scaledH = canvasW * scaleW, canvasH * scaleH

		offsetX, offsetY =
			floor((windowW - scaledW) * 0.5),
			floor((windowH - scaledH) * 0.5)
	end

	self._canvasScaleW, self._canvasScaleH = scaleW, scaleH
	self._canvasOffsetX, self._canvasOffsetY = offsetX, offsetY
	self:getCanvasTransform()
end

---When auto-scaling the `Viewport`, calculates the required scale needed to fit into the given bounds
---@param w integer
---@param h integer
function Viewport:fitInto(w, h)
	self._windowW, self._windowH =
		w, h
	self:_onOptionsChanged()
end

---Queues a refresh for a `Control` for later. Usually performed at the end of `Viewport:update()`.
---The second parameter is whether we are queueing the `control` to refresh itself, or its children.
---It is okay to attempt to queue many times and in most places:
---* The `Viewport` reduces redundant requests
---  * This method reduces inserts if a parent was already queued
---  * The performed refreshes reduce any children that were queued
---* The `Viewport` will perform queued refreshes up to a max of `MAX_REFRESHES` (default: 5)
---  * Infinite loops will be detected and broken; will warn when reaching the limit
---  * You can call `:_setCanonRect` inside of a `DrawRequest` if you need to, safely
---* Performed refreshes are also simplified in `:performRefreshes()`
---  * If a child was queued, and then its parent was queued, it won't be detected here
---  * `:performRefreshes()` will detect and simplify this, though
---@param control Control # The `Control` to refresh
---@param itself boolean # Are we refreshing `control`, or its children? The default, `false`, is its children.
function Viewport:insertDeferRefresh(control, itself)
	local deferred = self._deferredRefresh

	---@type "self" | "children"
	local insertMode = (itself and "self") or "children"

	if control._topLevelNode == control then
		-- It's top-level, which can have the "self" insert mode
		-- If we're requsting "self" and currently have "children", move it up to "self"
		-- Otherwise, don't move downwards or remove it
		local existingMode = deferred[control]
		if (existingMode == "children" and insertMode == "self") or not existingMode then
			deferred[control] = insertMode
		end
		return
	end

	---@type Control
	local currNode = control
	while currNode do
		if not currNode._inTree then
			-- Not in the tree
			return
		end

		if deferred[currNode] then
			-- Already affected by something above
			return
		end

		if not currNode.INHERITS_CONTROL then
			-- `currNode` is not a Control (which means we should refresh any children that are Controls)
			if currNode == control then
				-- `control` is not a Control, so don't insert it
				return
			end
			-- It's top-level, insert it
			break
		end

		local parent = currNode.parent
		if parent then
			currNode = parent
		else
			return
		end
	end

	if insertMode == "self" then
		local parent = control.parent
		---@cast parent Node
		if parent.INHERITS_CONTROL then
			-- Simplify by marking the parent for a refresh
			deferred[parent] = "children"
		else
			-- Can't simplify as the parent isn't a Control
			deferred[control] = "self"
		end
	elseif insertMode == "children" then
		deferred[control] = "children"
	end
end

-- local appleCakeProfilePerformRefreshes

---Performs every deferred refresh that was requested. Done automatically after `:update()`.
---You can call it manually if you need the positions of each Control immediately.
---This operation is expensive.
function Viewport:performRefreshes()
	-- appleCakeProfilePerformRefreshes = AppleCake.profile("Viewport:performRefreshes", nil, appleCakeProfilePerformRefreshes)
	-- Simplify by unmarking any children if a parent will refresh anyways
	local depthArray = self._depthArray
	local shallowest = huge
	local deepest = -huge

	local requestedDeferred = self._deferredRefresh

	-- Start with sorting each marked Control by depth
	for control, mode in pairs(requestedDeferred) do
		local depth = control._depth
		local depthMap = depthArray[depth]
		if not depthMap then
			depthMap = {}
			depthArray[depth] = depthMap
		end

		depthMap[control] = mode

		if shallowest > depth then
			shallowest = depth
		end

		if deepest < depth then
			deepest = depth
		end
	end

	tclear(requestedDeferred)

	if shallowest == huge or deepest == -huge then
		-- Invalid
		return
	end

	-- From lowest to highest, unmark the Control if it has a parent that will get refreshed
	-- (Skip the highest, as it won't have parents to check)
	for depth = deepest + 1, shallowest, -1 do
		local depthMap = depthArray[depth]
		if depthMap then
			for control, mode in pairs(depthMap) do
				local currParent = control.parent

				-- Remove this Control if an ancestor is marked for a refresh
				for parentDepth = depth - 1, deepest + 1, -1 do
					local ancestorDepthMap = depthArray[parentDepth]
					if (ancestorDepthMap and ancestorDepthMap[currParent]) or not currParent then
						-- Ancestor is here, we have to remove ourselves
						-- (Or ancestor is nil and we have to skip it)
						depthMap[control] = nil
						break
					end

					-- Go to next ancestor
					currParent = currParent.parent
				end
			end
		end
	end

	-- Now we can refresh everything
	for depth = shallowest, deepest do
		local depthMap = depthArray[depth]
		if depthMap then
			for control, mode in pairs(depthMap) do
				if mode == "children" then
					control:forceRefresh()
				else
					control:forceRefreshSelf()
				end

				-- TODO: Unmark the current control when asked to refresh again?
				-- Some children might request `control` to refresh while mid-refresh; this line removes it
				-- I don't know if it should be done though
				-- requestedDeferred[control] = nil
			end

			tclear(depthMap)
		end
	end

	-- appleCakeProfilePerformRefreshes:stop()
end

-- Perform the deferred refreshes that Controls requested.
-- If requested `MAX_REFRESHES` times, it's probably an infinite loop.
function Viewport:performRefreshesUntilDone()
	for i = 1, MAX_REFRESHES do
		-- Break if there's nothing to do
		if not next(self._deferredRefresh) then
			break
		end

		self:performRefreshes()

		if i == MAX_REFRESHES then
			print(("[Adore.Viewport:update] Performed %d refreshes in one step; stopping"):format(MAX_REFRESHES))
			break
		end
	end
end

---Sets the target dimensions of the Viewport
---@param targetW integer
---@param targetH integer
function Viewport:setDimensions(targetW, targetH)
	self._canvasW, self._canvasH = targetW, targetH
	self:_onOptionsChanged()
end

---Must be overridden; returns the rect components of the safe area
---@return integer x
---@return integer y
---@return integer w
---@return integer h
function Viewport:getSafeArea()
	return 0, 0,
		self._canvasW, self._canvasH
end

-- local appleCakeProfilePush

---Pushes the Viewport to the draw stack so that anything new will get drawn to it
---@param shouldClear boolean? # Pass `true` to clear the buffer layer, in case there's something in it
function Viewport:push(shouldClear)
	-- appleCakeProfilePush = AppleCake.profile("Viewport:push", nil, appleCakeProfilePush)
	if shouldClear == nil then shouldClear = true end
	self._lastViewport = Node._activeViewport
	Node._activeViewport = self

	love.graphics.push("all")
	if shouldClear and self._usingBufferLayer and self._altCanvas then
		-- There's something in the buffer layer, clear it
		love.graphics.setCanvas(self._altCanvas)
		love.graphics.clear()
		self._usingBufferLayer = false
	end

	love.graphics.setCanvas(self._mainCanvas)
	if shouldClear then
		love.graphics.clear()
	end

	love.graphics.replaceTransform(self._viewportTransform)

	-- Calculate the Viewport bounds
	local bounds = self._boundingBox
	bounds.x, bounds.y = 0, 0
	bounds.w, bounds.h = self._mainCanvas:getDimensions()
	bounds:iInverseTransformBox(self._viewportTransform)
	-- appleCakeProfilePush:stop()
end

-- local appleCakeProfilePop

---Pops the Viewport's changes to the draw stack and applies post-processing
---@param postProcessing boolean? # Apply post-processing? Default is `true`, and requires post-processing to be allowed.
function Viewport:pop(postProcessing)
	-- appleCakeProfilePop = AppleCake.profile("Viewport:pop", nil, appleCakeProfilePop)
	if self._allowPostProcessing == false then
		postProcessing = false
	elseif postProcessing == nil then
		postProcessing = self._allowPostProcessing
	end

	love.graphics.pop()

	if postProcessing and self.applyPostProcessing and self._altCanvas then
		-- Applies all post-processing shaders
		love.graphics.push("all")
		love.graphics.setColor(1, 1, 1)

		local mainCanvas, altCanvas =
			self._mainCanvas,
			self._altCanvas
		---@cast altCanvas love.Canvas

		-- Draw onto B from A
		local a, b = mainCanvas, altCanvas

		if self._usingBufferLayer then
			-- We're using the buffer layer during a :push(), swap the Canvases
			-- (This means that B has the content)
			a, b = b, a
		end

		if self._lightModel:isRequested() then
			-- Calculate the lightmap and put it into b
			self._lightModel:putLightInto(b)

			-- Draw the lightmap on top of the contents
			love.graphics.setCanvas(a)
			love.graphics.setColor(1, 1, 1)
			love.graphics.setBlendMode("multiply", "premultiplied")
			love.graphics.draw(b)
			love.graphics.setColor(1, 1, 1)
		end

		-- Apply each shader to the rendered canvas
		love.graphics.setBlendMode("alpha", "premultiplied")
		local shaderIDs = self.shaderIDs
		for i = 1, #shaderIDs do
			love.graphics.setCanvas(b)
			love.graphics.clear()
			love.graphics.setShader(shaderAssets[shaderIDs[i]])
			love.graphics.draw(a)
			a, b = b, a
		end

		if self.shouldDrawPhysics then
			-- Do the debug physics drawing (after post-processing)
			love.graphics.setCanvas(b)
			love.graphics.clear()
			love.graphics.replaceTransform(self._viewportTransform)
			self:drawPhysics()
			love.graphics.setCanvas(a)
			love.graphics.origin()
			love.graphics.setBlendMode("alpha", "premultiplied")
			love.graphics.setColor(1, 1, 1)
			love.graphics.draw(b)
		end

		love.graphics.pop()
		self._mainIsFinal = a == mainCanvas
	else
		-- No post-processing, the main canvas includes the final image
		self._mainIsFinal = not self._usingBufferLayer

		if self.shouldDrawPhysics and (not postProcessing and not self.applyPostProcessing) then
			-- Do the debug physics drawing (when post-processing is disabled)
			love.graphics.push("all")
			love.graphics.replaceTransform(self._viewportTransform)
			love.graphics.setCanvas(self:getFinalCanvas())
			self:drawPhysics()
			love.graphics.pop()
		end
	end

	Node._activeViewport = self._lastViewport or Node._root._viewport
	self._lastViewport = nil
	-- appleCakeProfilePop:stop()
end

---Stops rendering on the current Canvas, switches to the other, renders the old contents on it with a specified color, then switches back.
---Requires post-processing to work correctly; otherwise, nothing will occur.
---@param color number[]?
---@param shader love.Shader?
function Viewport:applyToBuffer(color, shader)
	local main, alt = self._mainCanvas, self._altCanvas
	if not alt then return end

	self._usingBufferLayer = true -- always true, as we switch back to the main Canvas afterwards and keep all content on the other
	love.graphics.push("all")
	love.graphics.setCanvas(alt)
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.setColor(color or DEFAULT_COLOR)
	love.graphics.setShader(shader)
	love.graphics.draw(main)
	love.graphics.pop()

	love.graphics.clear()
end

---Draws the fitted Viewport, which includes some default transformations.
---If you don't want this, get the canvas and draw it directly.
---@param offsetX integer?
---@param offsetY integer?
function Viewport:drawFittedContents(offsetX, offsetY)
	offsetX, offsetY =
		offsetX or 0,
		offsetY or 0

	love.graphics.draw(self:getFinalCanvas(), self._canvasOffsetX + offsetX, self._canvasOffsetY + offsetY, 0, self._canvasScaleW, self._canvasScaleH)
end

local drawPhysicsForEachFixture
if ADORE_NODE2D_CULL then
	local tempRect2 = Rect2()
	---@param body love.Body
	---@param boundingBox Rect2
	function drawPhysicsForEachFixture(body, boundingBox)
		for _, fixture in ipairs(body:getFixtures()) do
			---@cast fixture love.Fixture
			local shape = fixture:getShape()
			tempRect2:iSetFromPoints(fixture:getBoundingBox(1))

			if tempRect2:overlapping(boundingBox) then
				if shape:typeOf("CircleShape") then
					local cx, cy = body:getWorldPoints(shape:getPoint())
					love.graphics.circle("line", cx, cy, shape:getRadius())
				elseif shape:typeOf("PolygonShape") then
					love.graphics.polygon("line", body:getWorldPoints(shape:getPoints()))
				else
					love.graphics.line(body:getWorldPoints(shape:getPoints()))
				end
			end
		end
	end
else
	---@param body love.Body
	function drawPhysicsForEachFixture(body)
		for _, fixture in ipairs(body:getFixtures()) do
			---@cast fixture love.Fixture
			local shape = fixture:getShape()

			if shape:typeOf("CircleShape") then
				local cx, cy = body:getWorldPoints(shape:getPoint())
				love.graphics.circle("line", cx, cy, shape:getRadius())
			elseif shape:typeOf("PolygonShape") then
				love.graphics.polygon("line", body:getWorldPoints(shape:getPoints()))
			else
				love.graphics.line(body:getWorldPoints(shape:getPoints()))
			end
		end
	end
end

-- local appleCakeProfileDrawPhysics

---Draws the physics objects contained in this Viewport's world
---@private
function Viewport:drawPhysics()
	-- appleCakeProfileDrawPhysics = AppleCake.profile("Viewport:drawPhysics", nil, appleCakeProfileDrawPhysics)
	local physicsWorld = self._physicsWorld
	if physicsWorld then
		love.graphics.setBlendMode("alpha", "alphamultiply")
		local boundingBox = self._boundingBox
		for _, body in ipairs(physicsWorld:getBodies()) do
			if body:isActive() then
				love.graphics.setColor(0, 1, 0, 0.7)
			else
				love.graphics.setColor(1, 0, 0, 0.7)
			end

			drawPhysicsForEachFixture(body, boundingBox)
		end
	end
	-- appleCakeProfileDrawPhysics:stop()
end

---@param world love.World
---@param signal Signal
---@param dt number
local function fireSignalWithWorld(world, signal, dt)
	world:update(dt)
	signal:fire(dt)
end

---@param signal Signal
---@param dt number
local function fireSignalOnly(_, signal, dt)
	signal:fire(dt)
end

-- local appleCakeProfileUpdate

---Updates the Viewport's physics world, if it has one and owns it
function Viewport:update(dt)
	-- appleCakeProfileUpdate = AppleCake.profile("Viewport:update", nil, appleCakeProfileUpdate)
	do
		-- Step the physics world
		local world = self._physicsWorld
		local physicsStepSignal = self.physicsStepped
		local targetStep = self.targetPhysicsStep

		local simFunc
		---@type Physical2d[]?
		local list

		if world and self._ownsWorld then
			simFunc = fireSignalWithWorld
			list = Physical2d.getWorldList(world)
		else
			simFunc = fireSignalOnly
		end

		if targetStep == 0 then
			-- Dynamic physics stepping
			if list then
				for i = 1, #list do
					list[i]:physicsUpdate(dt)
				end
			end

			simFunc(world, physicsStepSignal, dt)
		else
			-- Static delta-time stepping
			local gameSpeed = Node._root.gameSpeed
			local stepMode = self.multiplyPhysicsSteps

			if stepMode ~= "never" then
				if stepMode == "any" then
					targetStep = targetStep * gameSpeed
				elseif stepMode == "decrease" then
					if gameSpeed < 1 then
						targetStep = targetStep * gameSpeed
					end
				elseif stepMode == "increase" then
					if gameSpeed > 1 then
						targetStep = targetStep * gameSpeed
					end
				end
			end

			local remainingTime = self._physicsStepRollover + dt
			local maxSteps = self.maxPhysicsSteps

			if self.multiplyMaxSteps then
				maxSteps = ceil(maxSteps * gameSpeed)
			end

			local stepsRequested = floor(remainingTime / targetStep)
			if stepsRequested < 1 then
				-- Updating faster than the target step, rollover to next frame
				self._physicsStepRollover = remainingTime
			else
				-- We have to step at least once this frame;
				-- cap the steps needed to the max steps allowed
				for _ = 1, min(stepsRequested, maxSteps) do
					if list then
						for i = 1, #list do
							list[i]:physicsUpdate(targetStep)
						end
					end

					simFunc(world, physicsStepSignal, targetStep)
				end

				-- Rollover the remaining time to the next frame
				-- TODO: Should we only rollover if it's significant?
				self._physicsStepRollover = remainingTime - stepsRequested * targetStep
			end
		end
	end

	self:performRefreshesUntilDone()

	-- appleCakeProfileUpdate:stop()
end

---Returns the dimensions of the internal canvas
---@return integer width
---@return integer height
function Viewport:getDimensions()
	return self._canvasW, self._canvasH
end

---After drawing, gets the love.Canvas with the final post-processing applied to it.
function Viewport:getFinalCanvas()
	return (self._mainIsFinal and self._mainCanvas) or self._altCanvas
end

---Converts a point from the window (aka. the dimensions the viewport fits into) into the Viewport's dimensions.
---This will get floored.
---@param x integer
---@param y integer
---@return integer viewportX
---@return integer viewportY
function Viewport:windowToViewportPoint(x, y)
	-- TODO: Replace this with a better solution
	-- This line is required, otherwise the transform will be 1 frame late
	self:getCanvasTransform()
	return
		floor((x - self._canvasOffsetX) / self._canvasScaleW),
		floor((y - self._canvasOffsetY) / self._canvasScaleH)
end

---Converts a point from the Viewport contents into a point inside of the "window".
---This will get floored.
---@param x integer
---@param y integer
---@return integer windowX
---@return integer windowY
function Viewport:viewportToWindowPoint(x, y)
	-- This line is required, otherwise the transform will be 1 frame late
	self:getCanvasTransform()
	return
		floor(x * self._canvasScaleW + self._canvasOffsetX),
		floor(y * self._canvasScaleH + self._canvasOffsetY)
end

---Converts a viewport point into a world point. Useful for converting a mouse position into the world.
---@param x number
---@param y number
---@return number worldX
---@return number worldY
function Viewport:viewportToWorldPoint(x, y)
	return self:getCanvasTransform():inverseTransformPoint(x, y)
end

---Converts a world point into a viewport point. Useful for converting an object's position into a UI point.
---@param x number
---@param y number
---@return number screenX
---@return number screenY
function Viewport:worldToViewportPoint(x, y)
	return self:getCanvasTransform():transformPoint(x, y)
end

---Assuming this Viewport's window is scaled to the game window, returns the world point associated with the screen point
---@param x number
---@param y number
---@return integer worldX
---@return integer worldY
function Viewport:screenToViewportPoint(x, y)
	local parent = self._parentViewport
	if parent then
		return self:getCanvasTransform():inverseTransformPoint(self:windowToViewportPoint(parent:screenToViewportPoint(x, y)))
	else
		return self:getCanvasTransform():inverseTransformPoint(self:windowToViewportPoint(x, y))
	end
end

---Assuming this Viewport's window is scaled to the game window, returns the world point associated with the screen point
---@param x number
---@param y number
---@return integer screenX
---@return integer screenY
function Viewport:viewportToScreenPoint(x, y)
	local parent = self._parentViewport
	if parent then
		return self:getCanvasTransform():transformPoint(self:windowToViewportPoint(parent:viewportToScreenPoint(x, y)))
	else
		return self:getCanvasTransform():transformPoint(self:windowToViewportPoint(x, y))
	end
end

---Gets the `love.Transform` used for graphics transformations, which is usually based off the camera
---@return love.Transform transform
function Viewport:getCanvasTransform()
	if self._activeCamera then
		-- TODO: Optimize so it only gets set if the transform changed
		self._viewportTransform:setMatrix(self._activeCamera:getCanvasTransform():getMatrix())
	end
	return self._viewportTransform
end

---Assuming this Viewport's window is scaled to the game window, returns the mouse position in the Viewport bounds
---@return integer viewportX
---@return integer viewportY
function Viewport:getViewportMousePosition()
	-- TODO: Not implemented
	return self:screenToViewportPoint(Node._root:getMousePosition())
end

---Assuming this Viewport's window is scaled to the game window, returns the mouse position in the Viewport world
---@return integer worldX
---@return integer worldY
function Viewport:getWorldMousePosition()
	return self:screenToViewportPoint(Node._root:getMousePosition())
end

---Releases all resources inside of the Viewport
function Viewport:release()
	self._mainCanvas:release()
	self._mainCanvas = nil
	if self._altCanvas then
		self._altCanvas:release()
		self._altCanvas = nil
	end
	if self._stencilCanvas then
		self._stencilCanvas:release()
		self._stencilCanvas = nil
	end
	self._parentViewport = nil

	local world = self._physicsWorld
	if world and self._ownsWorld then
		-- Destroy the love.World if this Viewport owns it
		self._physicsWorld = nil
		Physical2d.removeWorldList(world)
		world:destroy()
		world:release()
	end

	self.physicsStepped:release()
end

---Sets the love.World from a deserialized object
---@param world love.World
function Viewport:_setPhysicsWorld(world)
	self._physicsWorld = world
	Physical2d.addWorldList(world)
	world:setCallbacks(Physical2d.getWorldCallbacks())
	self:_onOptionsChanged()
end

---Called when deserializing LightModel
---@param lightModel LightModel
function Viewport:_setLightModel(lightModel)
	self._lightModel = lightModel
	self:_onOptionsChanged()
	lightModel:_viewportOptionsChanged()
end

function Viewport._addDefinition(entry)
	entry:newInteger("_canvasW", 1, 1, nil, nil, "%_onOptionsChanged")
	entry:newInteger("_canvasH", 1, 1, nil, nil, "%_onOptionsChanged")
	entry:newInteger("_windowW", 1, 1, nil, nil, "%_onOptionsChanged")
	entry:newInteger("_windowH", 1, 1, nil, nil, "%_onOptionsChanged")
	entry:newNumber("_pixelScale", 0, 0, nil, nil, "%_onOptionsChanged")
	local scaleMap = {
		resize = true,
		fraction = true,
		integer = true,
	}
	entry:newEnum("_scaleMode", scaleMap, "resize", "%_onOptionsChanged")
	local aspectMap = {
		ignore = true,
		keep = true,
	}
	entry:newEnum("_aspect", aspectMap, "keep", "%_onOptionsChanged")
	entry:newBoolean("_includeStencil", false, "%_onOptionsChanged")
	entry:newTable("_canvasSettings", nil, "%_onOptionsChanged")
	entry:newNodeRef("_activeCamera", "Camera", "%_onOptionsChanged")
	entry:newBoolean("_allowPostProcessing", false, "%_onOptionsChanged")
	entry:newBoolean("applyPostProcessing", nil, "%_onOptionsChanged")
	entry:newColor("_ambientLight", nil, nil, "%_onOptionsChanged")
	entry:newObject("_lightModel", "LightModel", "_setLightModel")
	entry:newLoveObject("_physicsWorld", "World", "_setPhysicsWorld")
	entry:newBoolean("_ownsWorld", false)
	entry:newNumber("targetPhysicsStep", nil, 0, nil, nil, "%_onOptionsChanged")
	entry:newNumber("maxPhysicsSteps", 1, 1, nil, nil, "%_onOptionsChanged")
	local physicsMultiplierMap = {
		never = true,
		increase = true,
		decrease = true,
		any = true,
	}
	entry:newEnum("multiplyPhysicsSteps", physicsMultiplierMap, "decrease", "%_onOptionsChanged")
	entry:newBoolean("shouldDrawPhysics", false, "%_onOptionsChanged")
	-- TODO: Should this be removed? It should be managed outside of the Viewport anyways.
	entry:newObject("_parentViewport", "Viewport")
end

return Viewport
