---@type AdoreInit
local Adore = require ""
local Rect2 = Adore.Common("Rect2")
local Object = Adore.Resources("Object")
local ShaderLoader, shaderAssets = Adore.Loader.getCollection("ShaderLoader")

local SHADOW_MESH_SHADER, _ = ShaderLoader:get(("%s/shaders/screenshadowmesh.glsl"):format(
	(Adore.PATH):gsub("%.", "/")
))

---@class LightModel: Object
---@field super Object
---@overload fun(viewport: Viewport, lightMode: LightModel.LightMode, postProcessing: boolean): LightModel
local LightModel = Object:extend()
LightModel.CLASS_NAME = "LightModel"

---@alias LightModel.LightMode
---| "none" # No lighting will be applied
---| "screen" # Lighting is applied by darkening a Canvas and drawing lights onto it (no occlusion)
---| "screenshadow" # Same technique as "screen", but lights will be occluded

---@param viewport Viewport
---@param lightMode LightModel.LightMode
function LightModel:new(viewport, lightMode, postProcessing)
	LightModel.super.new(self)

	---@type Viewport
	self._viewport = viewport

	---@type LightModel.LightMode
	self._lightMode = lightMode
	---@type love.Canvas? # An extra Canvas the LightModel can use; required when adding post-processing to lights
	self._canvasA = nil

	---@type boolean # Whether post-processing should get applied to the lightmap
	self._postProcessing = postProcessing or false
	---@type AssetID[] # An array of shader AssetIDs that will get applied to the rendered Canvas
	self.shaderIDs = {}

	---@type love.Mesh # The mesh that contains the shadow information
	self._shadowMesh = love.graphics.newMesh({
		{"VertexPosition", "float", 3},
	}, 256, "strip", "dynamic")

	self:_viewportOptionsChanged()
end

function LightModel:_viewportOptionsChanged()
	-- TODO: Unused
	local viewport = self._viewport

	local canvas = self._canvasA
	if canvas then
		if not self._postProcessing then
			-- No more canvas required
			canvas:release()
			self._canvasA = nil
		else
			-- Check if the canvas changed
			local w, h = canvas:getDimensions()
			local requestedW, requestedH =
				viewport._canvasW,
				viewport._canvasH
			if viewport.remakeCanvases or w ~= requestedW or h ~= requestedH then
				canvas:release()
				self._canvasA = love.graphics.newCanvas(requestedW, requestedH, viewport._canvasSettings)
			end
		end
	else
		if self._postProcessing then
			self._canvasA = love.graphics.newCanvas(viewport._canvasW, viewport._canvasH, viewport._canvasSettings)
		end
	end
end

local lightModeScreenShadow
local lightModeScreen
do
---@type table # Used for setting up the stencil
local _canvasSetup = {}
---@type Light2d[] # An array of Light2ds, that are visible on screen but don't cast shadows; [1] is the length + 1
local _lightsNoShadows = {1}
---@type Light2d[] # An array of Light2ds, that are both visible AND cast shadows; [1] is the length + 1
local _lightsThatCastShadows = {1}
---An array of shadows, which goes {love.Transform, shouldFill, points, ...}; all shadows depend on the range of Light2ds; [1] is the length + 1
local _shadows = {1}

local forEachShadowLight
do
local major = love.getVersion()
if major == 11 then
	local posArr = {0, 0}

	-- Love 11.5, when there's no blending with the destination alpha
	---@param light Light2d
	---@param sMesh love.Mesh
	function forEachShadowLight(light, sMesh)
		-- Draw the shadow mask into the stencil
		-- TODO: Set scissor for light bounds
		if light._shadows then
			love.graphics.push("all")

			-- Send the position of the light
			local x, y = light._globalContentRect:getCenter()
			posArr[1], posArr[2] = x, y
			SHADOW_MESH_SHADER:send("LightPosition", posArr)

			-- Draw the shadow mesh to the stencil
			love.graphics.setShader(SHADOW_MESH_SHADER)
			love.graphics.setMeshCullMode("back")
			love.graphics.stencil(function()
				love.graphics.draw(sMesh)
			end, "replace", 1, false)
			love.graphics.setStencilTest("notequal", 1)
			love.graphics.setShader()
			love.graphics.setMeshCullMode("none")

			-- Draw the light
			light:_drawLight()
			love.graphics.pop()
		else
			love.graphics.setStencilTest()
			light:_drawLight()
		end
	end
else
	local posArr = {0, 0}
	---@param light Light2d
	---@param sMesh love.Mesh
	function forEachShadowLight(light, sMesh)
		-- TODO: [Love12] For blend state; multiply source color by destination alpha
		-- Draw the shadow mask into the alpha channel
		local hasShadows = light._shadows
		if hasShadows then
			love.graphics.push("all")

			-- Reset the alpha
			local x, y = light:getPosition(true)
			posArr[1], posArr[2] = x, y
			SHADOW_MESH_SHADER:send("LightPosition", posArr)

			love.graphics.setColorMask(false, false, false, true)
			love.graphics.clear({0, 0, 0, 1})
			-- love.graphics.setBlendMode("replace", "premultiplied")
			love.graphics.setColor(1, 1, 1, 0)
			love.graphics.setShader(SHADOW_MESH_SHADER)
			love.graphics.draw(sMesh)

			love.graphics.pop()
		end

		-- Draw the light
		light:_drawLight()

		if hasShadows then
			love.graphics.setColorMask(false, false, false, true)
			love.graphics.setColorMask(true, true, true, true)
		end
	end
end

---@type Rect2 # The bounds of all lights that overlap with the screen; used for choosing which shadows to include
local lightRect = Rect2(0, 0, 0, 0)

local function lmssAddLightsToArr(light, withShadow, withoutShadow)
	if light:isVisibleInTree() then
		if light._shadows then
			-- Casts a shadow, put it into the lights with shadows array
			local count = withShadow[1] + 1
			withShadow[1] = count
			withShadow[count] = light
		else
			-- Doesn't cast a shadow, put it into the lights without shadows array
			local count = withoutShadow[1] + 1
			withoutShadow[1] = count
			withoutShadow[count] = light
		end
	end
end

local function lmssAddShadowsToArr(shadow, shadows)
	-- The array is structured like this:
	-- [1]: Last filled index (referred to as `i`, initialized to 2)
	-- [2]: Total vertices required
	-- [i + 1]: love.Transform | false # The Transform to apply; make `false` to do nothing to the points
	-- [i + 2]: boolean # (shouldFill)
	-- [i + 3]: number[] # The shadow's local points
	-- [3 * (i + 1)]: for each shadow
	if shadow:isVisibleInTree() then
		local fill, points = shadow.fillOccluder, shadow.points
		local i = shadows[1]
		shadows[i + 1] = (shadow.transformOccluder and shadow._globalTransform) or false
		shadows[i + 2] = fill
		shadows[i + 3] = points

		shadows[1] = i + 3
		shadows[2] = shadows[2] + #points * 2 + ((fill and 2) or 0) + 4
	end
end

---Calculates the light and puts it into the destination Canvas.
---@param self LightModel
---@param dst love.Canvas
function lightModeScreenShadow(self, dst)
	local viewport = self._viewport
	assert(viewport._stencilCanvas, "Stencil was not enabled in Viewport settings")
	local bounds = viewport._boundingBox

	-- Push the transform
	love.graphics.push("all")
	love.graphics.applyTransform(viewport._viewportTransform)

	-- Set the active canvas and stencil
	_canvasSetup[1], _canvasSetup.depthstencil = dst, viewport._stencilCanvas
	love.graphics.setCanvas(_canvasSetup)
	_canvasSetup[1], _canvasSetup.depthstencil = nil, nil

	-- Clear the lightmap with the ambient light color
	love.graphics.clear(viewport._ambientLight)

	local lightsWithShadows = _lightsThatCastShadows
	local lightsNoShadows = _lightsNoShadows
	lightsWithShadows[1] = 1
	lightsNoShadows[1] = 1

	---Put all lights into the array
	viewport._lightShash:each(bounds.x, bounds.y, bounds.w, bounds.h, lmssAddLightsToArr, lightsWithShadows, lightsNoShadows)

	-- Make a Rect2 that contains the viewport dimensions and expands towards the light origins
	lightRect:iCopyRect(viewport._boundingBox)
	for i = 2, lightsWithShadows[1] do
		-- TODO: Decide if the lightRect should get expands towards the middle point or furthest corner
		local light = lightsWithShadows[i]
		local lightBounds = light._globalContentRect
		lightRect:iExpandTowards(lightBounds:getCenter())
	end

	-- Put relevant shadow information into the array
	local shadows = _shadows
	shadows[1] = 2 -- last filled index
	shadows[2] = 0 -- required vertices
	viewport._shadowShash:each(lightRect.x, lightRect.y, lightRect.w, lightRect.h, lmssAddShadowsToArr, shadows)
	local requiredVertices = shadows[2]

	-- Resize the mesh if we have to
	local sMesh = self._shadowMesh
	if requiredVertices > sMesh:getVertexCount() then
		-- TODO: Add a cap to required vertices
		local newAmount = requiredVertices * 2
		print(
			("[Adore.LightModel] Requested %d shadow vertices, currently have %d; resized mesh to %d)")
			:format(requiredVertices, sMesh:getVertexCount(), newAmount)
		)
		sMesh:release()

		sMesh = love.graphics.newMesh({
			{"VertexPosition", "float", 3},
		}, newAmount, "strip", "dynamic")

		self._shadowMesh = sMesh
	end

	-- Put the shadow vertices into the array
	---@type integer # The current vertex we are editing
	local v = 1
	for i = shadows[1], 5, -3 do
		---@type love.Transform
		local transform = shadows[i - 2]
		---@type boolean
		local fill = shadows[i - 1]
		---@type number[]
		local points = shadows[i]

		shadows[i - 2] = nil
		shadows[i - 1] = nil
		shadows[i] = nil

		if #points % 2 ~= 0 then
			error("ShadowCaster2d's point array is not a multiple of 2")
		end

		if not transform then
			-- No transforming of the occluder points
			do
				-- Start points, duplicate points
				local x, y = points[1], points[2]
				sMesh:setVertexAttribute(v, 1, x, y, 0)
				sMesh:setVertexAttribute(v + 1, 1, x, y, 0)
				v = v + 2
			end

			for j = 1, #points, 2 do
				-- For each point
				local x, y = points[j], points[j + 1]
				sMesh:setVertexAttribute(v, 1, x, y, 0)
				sMesh:setVertexAttribute(v + 1, 1, x, y, 1)
				v = v + 2
			end

			if fill then
				-- Fill by adding the starting points again
				local x, y = points[1], points[2]
				sMesh:setVertexAttribute(v, 1, x, y, 0)
				sMesh:setVertexAttribute(v + 1, 1, x, y, 1)
				v = v + 2
			end

			do
				-- End points, duplicate points
				local endp = #points - 1
				local x, y = points[endp], points[endp + 1]
				sMesh:setVertexAttribute(v, 1, x, y, 0)
				sMesh:setVertexAttribute(v + 1, 1, x, y, 0)
				v = v + 2
			end
		else
			-- Apply the ShadowCaster's transform to all points
			do
				-- Start points, duplicate points
				local x, y = transform:transformPoint(points[1], points[2])
				sMesh:setVertexAttribute(v, 1, x, y, 0)
				sMesh:setVertexAttribute(v + 1, 1, x, y, 0)
				v = v + 2
			end

			for j = 1, #points, 2 do
				-- For each point
				local x, y = transform:transformPoint(points[j], points[j + 1])
				sMesh:setVertexAttribute(v, 1, x, y, 0)
				sMesh:setVertexAttribute(v + 1, 1, x, y, 1)
				v = v + 2
			end

			if fill then
				-- Fill by adding the starting points again
				local x, y = transform:transformPoint(points[1], points[2])
				sMesh:setVertexAttribute(v, 1, x, y, 0)
				sMesh:setVertexAttribute(v + 1, 1, x, y, 1)
				v = v + 2
			end

			do
				-- End points, duplicate points
				local endp = #points - 1
				local x, y = transform:transformPoint(points[endp], points[endp + 1])
				sMesh:setVertexAttribute(v, 1, x, y, 0)
				sMesh:setVertexAttribute(v + 1, 1, x, y, 0)
				v = v + 2
			end
		end
	end

	-- Anything that is `v` or later is not set
	-- ...so lets clear it by replacing those vertices with the last set vertex
	if v > 1 then
		local x, y = sMesh:getVertexAttribute(v - 1, 1)
		for i = v, sMesh:getVertexCount() do
			sMesh:setVertexAttribute(i, 1, x, y, 0)
		end

		-- Draw all the lights with the shadows
		for i = lightsWithShadows[1], 2, -1 do
			local light = lightsWithShadows[i]
			lightsWithShadows[i] = nil
			forEachShadowLight(light, sMesh)
		end
		love.graphics.setStencilTest()
	else
		-- Since there was no shadows, we don't need to draw the shadow mesh

		-- Draw all the lights with the shadows (but normally)
		for i = lightsWithShadows[1], 2, -1 do
			local light = lightsWithShadows[i]
			lightsWithShadows[i] = nil
			light:_drawLight()
		end
	end


	-- Draw all the lights without shadows
	for i = lightsNoShadows[1], 2, -1 do
		local light = lightsNoShadows[i]
		lightsNoShadows[i] = nil
		light:_drawLight()
	end

	love.graphics.pop()
end

---@param light Light2d
---@param lightArr Light2d[]
local function lmsForEachLight(light, lightArr)
	-- 0th index is the length
	local count = lightArr[1] + 1
	lightArr[1] = count
	lightArr[count] = light
end

---Calculates the light and puts it into the destination Canvas.
---@param self LightModel
---@param dst love.Canvas
function lightModeScreen(self, dst)
	local viewport = self._viewport
	local bounds = viewport._boundingBox

	-- Push the transform
	love.graphics.push("all")
	love.graphics.applyTransform(viewport._viewportTransform)
	love.graphics.setCanvas(dst)

	-- Clear the lightmap with the ambient light color
	love.graphics.clear(viewport._ambientLight)

	-- Clear all lights
	local lights = _lightsNoShadows
	lights[1] = 1

	---Put all lights into the array
	viewport._lightShash:each(bounds.x, bounds.y, bounds.w, bounds.h, lmsForEachLight, lights)

	-- Draw all the lights without shadows
	for i = lights[1], 2, -1 do
		local light = lights[i]
		lights[i] = nil
		light:_drawLight()
	end

	love.graphics.pop()
end
end
end

local modeToFunction = {
	screen = lightModeScreen,
	screenshadow = lightModeScreenShadow,
}

---Calculates the lightmap and puts it into `dst`
---@param dst love.Canvas
function LightModel:putLightInto(dst)
	local lightMode = self._lightMode
	if lightMode ~= "none" then
		-- Do lighting
		modeToFunction[lightMode](self, dst)

		local shaderIDs = self.shaderIDs
		if self._postProcessing and #shaderIDs > 0 then
			-- Apply post-processing to the lightmap
			local altCanvas = self._canvasA
			---@cast altCanvas love.Canvas
			local a, b = dst, altCanvas

			love.graphics.push("all")
			love.graphics.origin()
			love.graphics.setBlendMode("alpha", "premultiplied")
			for i = 1, #shaderIDs do
				love.graphics.setCanvas(b)
				love.graphics.clear()
				love.graphics.setShader(shaderAssets[shaderIDs[i]])
				love.graphics.draw(a)
				a, b = b, a
			end

			if a ~= dst then
				-- `dst` should have the lightmap
				-- So we draw the contents of the alt Canvas into the destination
				-- and then clear the alt Canvas
				love.graphics.setCanvas(dst)
				love.graphics.draw(altCanvas)
				love.graphics.setCanvas(altCanvas)
				love.graphics.clear()
			end
			love.graphics.pop()
		end
	end
end

---Returns `true` if this LightModel should be ran
---@return boolean shouldRun
function LightModel:isRequested()
	return self._lightMode ~= "none"
end

function LightModel._addDefinition(entry)
	entry:newObject("_viewport", "Viewport", "%_viewportOptionsChanged")
	entry:newString("_lightMode", "none", nil, nil, "%_viewportOptionsChanged")
	entry:newBoolean("_postProcessing", false, "%_viewportOptionsChanged")
end

return LightModel
