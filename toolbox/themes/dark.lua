local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
local Adore = require(ADORE_PATH)

local function onRequire()
	local Nodes = Adore.Nodes
	local Resources = Adore.Resources

	local Theme = Adore.Resources("Theme")

	local HBox = Nodes("HBox")

	local DrawRequest = Resources("DrawRequest")

	---@type Theme
	local dark = Theme(Resources("DefaultTheme")())

	-- HBox
	dark:setDrawable(HBox, "topbar", DrawRequest(
		function(_, control)
			local lcr = control._localContentRect
			love.graphics.setColor(0.3, 0.3, 0.34)
			love.graphics.rectangle("fill", lcr.x, lcr.y - 12, lcr.w, lcr.h + 12, 4)
		end
	))

	dark:setVariant(HBox, "topbar", {
		topbar = "topbar"
	})

	return dark
end

return onRequire
