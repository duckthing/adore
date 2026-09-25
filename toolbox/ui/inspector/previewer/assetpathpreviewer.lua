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
local Label = Nodes("Label")
local Button = Nodes("Button")

---@class Previewer.AssetPath: Previewer
local AssetP = Previewer:extend()

function AssetP:new(...)
	AssetP.super.new(self, ...)
	self:setOffsets(0, 0, 0, 60)
end

function AssetP:construct(object, property, propertyName)
	self.nameLabel = self:newNameLabel(object, property, propertyName)
	self.value = self:newValueLabel(object, property, propertyName)

	local nilButton = Button("x")
		:setAnchors(1, 0, 1, 1)
		:setOffsets(-20, 0, 0, 0)
	nilButton.clicked:connect(self, "makeNil")

	self:addChild(self.nameLabel)
	self:addChild(self.value)
	self:addChild(nilButton)
end

---@param self Button
local function buttonCanDropData(self, posX, posY, data)
	if type(data) == "table" and type(data.path) == "string" then
		---@type Previewer.AssetPath
		local previewer = self.previewer
		---@type Property.AssetPath
		local property = previewer.property
		---@type string
		local path = data.path
		local assetCollection = Loader.getCollection(property.collectionName)
		return (pcall(assetCollection.get, assetCollection, path))
	end
end

---@param self Button
local function buttonGetDragData(self)
	-- Return the contained Node
	---@type Previewer.AssetPath
	local previewer = self.previewer
	---@type Property.AssetPath
	local property = previewer.property
	local object = property:get(previewer.object, previewer.propertyName)
	if not object then return end
	local assetCollection = Loader.getCollection(property.collectionName)
	local path = assetCollection:getAssetPath(object)
	if not path then return end
	return
		{type = "object", object = object, path = path},
		Label(("%s\n[%s]"):format(tostring(path), tostring(object)))
end

---@param self Button
local function buttonDropData(self, posX, posY, data)
	if type(data) == "table" and type(data.path) == "string" then
		---@type Previewer.AssetPath
		local previewer = self.previewer
		---@type Property.AssetPath
		local property = previewer.property
		---@type string
		local path = data.path
		local assetCollection = Loader.getCollection(property.collectionName)
		local success, objOrErr = pcall(assetCollection.get, assetCollection, path)
		if success then
			previewer:attemptSet(objOrErr)
		else
			print(objOrErr)
		end
	end
end

function AssetP:newValueLabel(object, property, propertyName)
	---@cast property Property.AssetPath
	local collectionName = property.collectionName
	local Collection = Loader.getCollection(collectionName)
	local asset = property:get(self.object, propertyName)
	local assetPath = asset and Collection:getAssetPath(asset) or "nil"
	local button = Button(assetPath)
		:setAnchors(1, 0, 1, 1)
		:setOffsets(-150, 0, -20, 0)
		:setIconAlign("center")
		:setIconJustify("top")
		:setIconExpand(true)
		:setClipText(true)
	button.clicked:connect(self, "showPopup")

	button.previewer = self
	button._canDropData = buttonCanDropData
	button._getDragData = buttonGetDragData
	button._dropData = buttonDropData

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
		elseif text ~= "" then
			-- Entered text isn't empty
			matchLabel:setText("(no match)")
		else
			-- It's empty
			matchLabel:setText("(nil)")
		end
	end)

	-- Connect events
	window:addAction("Cancel", "close")
	window:addAction("Set", "submit")
	window.submit = function(...)
		local enteredPath = pathField._submittedText
		local path
		if enteredPath ~= "" then
			-- Entered path isn't empty; search for the asset
			path = fzy.get_best_match(enteredPath, Previewer.Toolbox.getFilePaths()) or enteredPath
			if not path then
				return
			end
		end

		if path then
			local success, newAsset = pcall(Collection.get, Collection, path)
			if success then
				self:attemptSet(newAsset)
				window:close()
			else
				print(newAsset)
			end
		else
			self:attemptSet()
			window:close()
		end
	end

	window:addChild(vbox)
	self:addChild(window)
	window:popup()
	pathField:grabFocus(false)
end

---Used for a Button connection; sets this property to `nil`
function AssetP:makeNil()
	return self:attemptSet()
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
	local assetPath = asset and Collection:getAssetPath(asset) or "nil"
	valueButton:setText(assetPath)

	if collectionName == "TextureLoader" then
		-- It's a TextureSource
		valueButton:setIcon(asset)
	end
end

return AssetP
