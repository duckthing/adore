---@diagnostic disable: assign-type-mismatch
local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.nodes")

local LazyRequire = require(ADORE_PATH..".lazyrequire")

local Nodes
do
---@enum (key) Adore.Nodes
local nodePaths = {
	---@type Node
	Node = "nodes.node",
		---@type AudioPlayer
		AudioPlayer = "nodes.audioplayer",
		---@type AnimationNode
		AnimationNode = "nodes.animationnode",
		---@type TimerNode
		TimerNode = "nodes.timernode",
		---@type GameScript
		GameScript = "nodes.gamescript",
		---@type Node2d
		Node2d = "nodes.node2d",
			---@type Camera
			Camera = "nodes.node2d.camera",
			---@type DebugRectangle
			DebugRectangle = "nodes.node2d.debugrectangle",
			---@type Physical2d
			Physical2d = "nodes.node2d.physical2d",
				---@type RigidBody
				RigidBody = "nodes.node2d.physical2d.rigidbody",
				---@type StaticBody
				StaticBody = "nodes.node2d.physical2d.staticbody",
				---@type Area2d
				Area2d = "nodes.node2d.physical2d.area2d",
				---@type KinematicBody
				KinematicBody = "nodes.node2d.physical2d.kinematicbody",
			---@type CollisionShape
			CollisionShape = "nodes.node2d.collisionshape",
			---@type Raycast2d
			Raycast2d = "nodes.node2d.raycast2d",
				---@type SpringArm2d
				SpringArm2d = "nodes.node2d.springarm2d",
			---@type YSort
			YSort = "nodes.node2d.ysort",
			---@type Sprite
			Sprite = "nodes.node2d.sprite",
			---@type AudioListener2d
			AudioListener2d = "nodes.node2d.audiolistener2d",
			---@type AudioPlayer2d
			AudioPlayer2d = "nodes.node2d.audioplayer2d",
			---@type Light2d
			Light2d = "nodes.node2d.light2d",
				---@type CircleLight2d
				CircleLight2d = "nodes.node2d.light2d.circlelight2d",
				---@type PointLight2d
				PointLight2d = "nodes.node2d.light2d.pointlight2d",
			---@type ShadowCaster2d
			ShadowCaster2d = "nodes.node2d.shadowcaster2d",
			---@type Particles2d
			Particles2d = "nodes.node2d.particles2d",
		---@type Control
		Control = "nodes.control",
			---@type ColorRect
			ColorRect = "nodes.control.colorrect",
			---@type BaseButton
			BaseButton = "nodes.control.basebutton",
				---@type Button
				Button = "nodes.control.basebutton.button",
				---@type TextureButton
				TextureButton = "nodes.control.basebutton.texturebutton",
			---@type VBox
			VBox = "nodes.control.vbox",
			---@type HBox
			HBox = "nodes.control.hbox",
			---@type MarginBox
			MarginBox = "nodes.control.marginbox",
			---@type Label
			Label = "nodes.control.label",
			---@type LineEdit
			LineEdit = "nodes.control.lineedit",
			---@type TextureRect
			TextureRect = "nodes.control.texturerect",
			---@type ViewportContainer
			ViewportContainer = "nodes.control.viewportcontainer",
			---@type NinePatchRect
			NinePatchRect = "nodes.control.ninepatchrect",
			---@type TabBar
			TabBar = "nodes.control.tabbar",
			---@type TabContainer
			TabContainer = "nodes.control.tabcontainer",
		---@type CanvasLayer
		CanvasLayer = "nodes.canvaslayer",

	---@type RootNode # DO NOT USE!
	RootNode = "nodes.rootnode",
}
Nodes = LazyRequire(nodePaths)
end

return Nodes
