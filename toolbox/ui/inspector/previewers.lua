local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
local PREVIEWER_PATH = ADORE_PATH..".toolbox.ui.inspector.previewer"

local Previewers = {
	any = require(PREVIEWER_PATH),
	boolean = require(PREVIEWER_PATH..".booleanpreviewer"),
	number = require(PREVIEWER_PATH..".numberpreviewer"),
	integer = require(PREVIEWER_PATH..".numberpreviewer"),
	string = require(PREVIEWER_PATH..".stringpreviewer"),

	Vec2 = require(PREVIEWER_PATH..".vec2previewer"),
	Color = require(PREVIEWER_PATH..".colorpreviewer"),
	NodeRef = require(PREVIEWER_PATH..".noderefpreviewer"),
	Object = require(PREVIEWER_PATH..".noderefpreviewer"),
	Enum = require(PREVIEWER_PATH..".enumpreviewer"),
	AssetPath = require(PREVIEWER_PATH..".assetpathpreviewer"),
}

return Previewers
