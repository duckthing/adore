local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
local Adore = require(ADORE_PATH)

local function onRequire()
	local Nodes = Adore.Nodes
	local Resources = Adore.Resources

	local Theme = Adore.Resources("Theme")

	local Control = Nodes("Control")
	local HBox = Nodes("HBox")

	local DrawRequest = Resources("DrawRequest")

	---@type Theme
	local dark = Theme(Resources("DefaultTheme")())

	-- Topbar on HBox
	dark:setDrawable(HBox, "topbar", DrawRequest(
		function(_, control)
			local lcr = control._localContentRect
			love.graphics.setColor(0.15, 0.15, 0.2)
			love.graphics.rectangle("fill", lcr.x, lcr.y, lcr.w, lcr.h, 4)
		end
	))

	dark:setVariant(HBox, "topbar", {
		normal = "topbar"
	})

	-- Panel on all Controls
	dark:setDrawable(Control, "panel", DrawRequest(
		function(_, control)
			local lcr = control._localContentRect
			love.graphics.setColor(0.15, 0.15, 0.2)
			love.graphics.rectangle("fill", lcr.x - 4, lcr.y - 4, lcr.w + 8, lcr.h + 8, 4)
		end
	))

	dark:setVariant(Control, "panel", {
		normal = "panel"
	})

	return dark
end

return onRequire
