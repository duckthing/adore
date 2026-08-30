local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local Loader = Adore.Loader
local FormBuilder = Adore.Common("FormBuilder")
local fzy = Adore.Libraries("fzy")

---@type Previewer
local Previewer = require(ADORE_PATH..".toolbox.ui.inspector.previewer")
local WindowPopup = Nodes("WindowPopup")
local Button = Nodes("Button")

---@class Previewer.AssetPath: Previewer
local AssetP = Previewer:extend()

function AssetP:new(...)
	AssetP.super.new(self, ...)
	self:setOffsets(0, 0, 0, 60)
end

function AssetP:newValueLabel(object, property, propertyName)
	---@cast property Property.AssetPath
	local collectionName = property.collectionName
	local Collection = Loader.getCollection(collectionName)
	local asset = property:get(self.object, propertyName)
	local assetPath = asset and Collection:getAssetPath(asset) or ""
	local button = Button(assetPath)
		:setAnchors(1, 0, 1, 1)
		:setOffsets(-130, 0, 0, 0)
		:setIconAlign("center")
		:setIconJustify("top")
		:setIconExpand(true)
	button.clicked:connect(self, "showPopup")

	if collectionName == "TextureLoader" then
		-- It's a TextureSource
		button:setIcon(asset)
	end

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
		-200, -66, 0, 66
	)
	window:getTitleLabel():setText(("Set '%s' (%s)"):format(propertyName, collectionName))

	---@type Form
	local form = {
		{type = "body", text = "Asset Path"},
		{id = "path", type = "textfield",
				value = Collection:getAssetPath(property:get(self.object, propertyName))},
		{id = "searchMatch", type = "body", text = "Search result..."},
	}

	local vbox, sheet = FormBuilder.build(form)
	---@cast vbox VBox
	vbox:setAnchorsAndOffsets(
			0, 0, 1, 1,
			10, 10, -10, 0
		)
		:setResizeToContent(true)
		:setMargin(4)

	---@type LineEdit
	local pathField = sheet:getElement("path")
	pathField:setUnfocusedPosition("right")
			:setSubmitOnFocusLost(false)
			.textSubmitted:connect(window, "submit")

	-- Search result label
	---@type Label
	local matchLabel = sheet:getElement("searchMatch")
	pathField.textChanged:connectCallable(function(_, text)
		local match = fzy.get_best_match(text, Previewer.Toolbox.getFilePaths())
		if match then
			matchLabel:setText(match)
		else
			matchLabel:setText("(no match)")
		end
	end)

	-- Connect events
	window:addAction("Cancel", "close")
	window:addAction("Set", "submit")
	window.submit = function(...)
		local enteredPath = pathField._submittedText
		local path = fzy.get_best_match(enteredPath, Previewer.Toolbox.getFilePaths()) or enteredPath
		if not path then
			return
		end

		local success, newAsset = pcall(Collection.get, Collection, path)
		if success then
			self:attemptSet(newAsset)
			window:close()
		else
			print(newAsset)
		end
	end

	window:addChild(vbox)
	self:addChild(window)
	window:popup()
	pathField:grabFocus(false)
end

function AssetP:onInput(item)
	local object, property, propertyName =
		self.object, self.property, self.propertyName
	---@cast property Property.Enum

	property:set(object, propertyName, item)
	---@type Button
	local valueButton = self.value

	---@cast property Property.AssetPath
	local collectionName = property.collectionName
	local Collection = Loader.getCollection(collectionName)
	local asset = property:get(object, propertyName)
	local assetPath = asset and Collection:getAssetPath(asset) or ""
	valueButton:setText(assetPath)

	if collectionName == "TextureLoader" then
		-- It's a TextureSource
		valueButton:setIcon(asset)
	end
end

return AssetP
