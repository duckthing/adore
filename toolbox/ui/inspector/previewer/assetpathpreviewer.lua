local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local Loader = Adore.Loader
local Previewer = require(ADORE_PATH..".toolbox.ui.inspector.previewer")

local VBox = Nodes("VBox")
local Label = Nodes("Label")
local LineEdit = Nodes("LineEdit")
local WindowPopup = Nodes("WindowPopup")
local Button = Nodes("Button")

---@class Previewer.AssetPath: Previewer
local AssetP = Previewer:extend()

function AssetP:newValueLabel(object, property, propertyName)
	local val = property:get(object, propertyName)
	local button = Button(tostring(val))
		:setAnchors(1, 0, 1, 1)
		:setOffsets(0, 0, -130, 0)
	button.clicked:connect(self, "showPopup")

	return button
end

function AssetP:showPopup()
	local property = self.property
	---@cast property Property.AssetPath
	local propertyName = self.propertyName
	local collectionName = property.collectionName
	local Collection = Loader.getCollection(collectionName)
	---@cast Collection Adore.AssetCollection

	local window = WindowPopup()
	window._destroyOnClose = true
	window:setAnchorsAndOffsets(
		0, 1, 0, 1,
		-180, -56, 0, 56
	)
	window:getTitleLabel():setText(("Set '%s' (%s)"):format(propertyName, collectionName))

	local vbox = VBox()
	vbox:setAnchorsAndOffsets(
			0, 0, 1, 1,
			10, 10, -10, 0
		)
		:setResizeToContent(true)
		:setMargin(4)

	-- Create the fields
	-- == Path Label
	vbox:addChild(Label("Asset Path"):setAnchors(0, 0, 1, 0))

	-- == Asset LineEdit
	local pathField = LineEdit(Collection:getAssetPath(property:get(self.object, propertyName)))
		:setAnchorsAndOffsets(
			0, 0, 1, 0,
			0, 0, 0, 22
		)
		:setUnfocusedPosition("right")
	vbox:addChild(pathField)

	-- Connect events
	window:addAction("Cancel").clicked:connect(window, "close")
	local setButton = window:addAction("Set")
	setButton.clicked:connectCallable(function(...)
		local success, newAsset = pcall(Collection.get, Collection, pathField._text)
		if success then
			self:attemptSet(newAsset)
			window:close()
		else
			print(newAsset)
		end
	end)

	window:addChild(vbox)
	self:addChild(window)
	window:popup()
end

function AssetP:onInput(item)
	local object, property, propertyName =
		self.object, self.property, self.propertyName
	---@cast property Property.Enum

	property:set(object, propertyName, item)
	self.value:setText(tostring(item))
end

return AssetP
