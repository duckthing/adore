---@diagnostic disable: assign-type-mismatch
local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.data")

local LazyRequire = require(ADORE_PATH..".lazyrequire")

local Resources
do
---@enum (key) Adore.Resources
local resourcePaths = {
	---@type Object
	Object = "data.object",
	---@type Theme
	Theme = "data.theme",
		---@type DefaultTheme
		DefaultTheme = "data.defaulttheme",
	---@type DrawRequest
	DrawRequest = "data.drawrequest",
		---@type DrawRequest.Box
		["DrawRequest.Box"] = "data.drawrequest.drawbox",
		---@type DrawRequest.RoundedBox
		["DrawRequest.RoundedBox"] = "data.drawrequest.drawroundedbox",
		---@type DrawRequest.DebugBox
		["DrawRequest.DebugBox"] = "data.drawrequest.drawdebugbox",
		---@type DrawRequest.Label
		["DrawRequest.Label"] = "data.drawrequest.drawlabel",
		---@type DrawRequest.TextureRect
		["DrawRequest.TextureRect"] = "data.drawrequest.drawtexture",
		---@type DrawRequest.BaseButton
		["DrawRequest.BaseButton"] = "data.drawrequest.drawbasebutton",
		---@type DrawRequest.Button
		["DrawRequest.Button"] = "data.drawrequest.drawbutton",
		---@type DrawRequest.TextureButton
		["DrawRequest.TextureButton"] = "data.drawrequest.drawtexturebutton",
		---@type DrawRequest.LineEdit
		["DrawRequest.LineEdit"] = "data.drawrequest.drawlineedit",
		---@type DrawRequest.DRStack
		["DrawRequest.DRStack"] = "data.drawrequest.drstack",
		---@type DrawRequest.NinePatch
		["DrawRequest.NinePatch"] = "data.drawrequest.drawninepatch",
		---@type DrawRequest.NinePatchRect
		["DrawRequest.NinePatchRect"] = "data.drawrequest.drawninepatchrect",
		---@type DrawRequest.TabBar
		["DrawRequest.TabBar"] = "data.drawrequest.drawtabbar",
		---@type DrawRequest.TabContainer
		["DrawRequest.TabContainer"] = "data.drawrequest.drawtabcontainer",
		---@type DrawRequest.PopupMenu
		["DrawRequest.PopupMenu"] = "data.drawrequest.drawpopupmenu",
		---@type DrawRequest.WindowPopup
		["DrawRequest.WindowPopup"] = "data.drawrequest.drawwindowpopup",
	---@type SceneFactory
	SceneFactory = "data.scenefactory",
		---@type PackedScene
		PackedScene = "data.packedscene",
		---@type TableScene
		TableScene = "data.tablescene",
	---@type Context
	Context = "data.context",
		---@type ShortcutContext
		ShortcutContext = "data.context.shortcutcontext",
		---@type GameContext
		GameContext = "data.context.gamecontext",
		---@type CoreUIContext
		CoreUIContext = "data.context.coreuicontext",
		---@type MainLoopContext
		MainLoopContext = "data.context.mainloopcontext",
	---@type Viewport
	Viewport = "data.viewport",
	---@type LightModel
	LightModel = "data.lightmodel",
	---@type Tween
	Tween = "data.tween",
	---@type Animation
	Animation = "data.animation",
	---@type Animation.Library
	["Animation.Library"] = "data.animation.animationlibrary",
	---@type NinePatch
	NinePatch = "data.ninepatch",
}
Resources = LazyRequire(resourcePaths)
end

return Resources
