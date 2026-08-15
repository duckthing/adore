local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local min, max = math.min, math.max

---@class Toolbox.Tool: SimpleObject
---@field super Toolbox.Tool
---@field mousemoved fun(self, mx: integer, my: integer, globalDx: integer, globalDy: integer, isTouch: boolean): boolean? handled
---@field mousepressed fun(self, mx: integer, my: integer, button: integer, isTouch: boolean, pressCount: integer): boolean? handled
---@field mousereleased fun(self, mx: integer, my: integer, button: integer): boolean? handled
---@field wheelmoved fun(self, wx: integer, wy: integer): boolean? handled
---@overload fun(): Toolbox.Tool
local Tool = Adore.Libraries("SimpleObject"):extend()

---@type Toolbox.EditableScene
Tool.srContainer = nil
---@type Toolbox.MainWindow
Tool.mainWindow = nil
---@type boolean # If this Tool is busy and should not be switched away from
Tool._busy = false

function Tool:new()
	Tool.super.new(self)
	self.panning = false
end

---Returns `true` if this Tool is busy and should not be switched away from
---@return boolean
function Tool:isBusy()
	return Tool._busy or self.panning
end

function Tool:mousepressed(mx, my, button, isTouch, pressCount)
	if button == 3 then
		-- Start panning
		self.panning = true
		return true
	end
	return false
end

function Tool:mousemoved(mx, my, dx, dy, isTouch)
	if self.panning then
		-- Pan with the mouse
		local camera = Tool.srContainer.camera
		local speed = -camera._zoom.x
		camera:translate(dx * speed, dy * speed)
		return true
	end
	return false
end

function Tool:mousereleased(mx, my, button)
	if button == 3 and self.panning then
		-- Stop panning
		self.panning = false
		return true
	end
	return false
end

function Tool:wheelmoved(wx, wy)
	-- Do zooming
	if wx == 0 then
		local camera = self.srContainer.camera
		local zoom = camera._zoom
		local newZoomValue = zoom.x
		if wy > 0 then
			newZoomValue = newZoomValue * 0.8
		elseif wy < 0 then
			newZoomValue = newZoomValue * 1.2
		end
		newZoomValue = max(0.02, min(newZoomValue, 1000))
		camera:setZoom(newZoomValue, newZoomValue)
		return true
	end
	return false
end

return Tool
