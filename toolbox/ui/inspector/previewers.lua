local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")

local Previewers = {
	any = require(ADORE_PATH..".toolbox.ui.inspector.previewer"),
	boolean = require(ADORE_PATH..".toolbox.ui.inspector.previewer.booleanpreviewer"),
	number = require(ADORE_PATH..".toolbox.ui.inspector.previewer.numberpreviewer"),
	integer = require(ADORE_PATH..".toolbox.ui.inspector.previewer.numberpreviewer"),
	string = require(ADORE_PATH..".toolbox.ui.inspector.previewer.stringpreviewer"),

	Vec2 = require(ADORE_PATH..".toolbox.ui.inspector.previewer.vec2previewer"),
	Color = require(ADORE_PATH..".toolbox.ui.inspector.previewer.colorpreviewer"),
	NodeRef = require(ADORE_PATH..".toolbox.ui.inspector.previewer.noderefpreviewer"),
	Object = require(ADORE_PATH..".toolbox.ui.inspector.previewer.noderefpreviewer"),
}

return Previewers
