local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local FormBuilder = Adore.Common("FormBuilder")
local LoveClasses = Adore.Common("LoveClasses")

---@type Previewer
local Previewer = require(ADORE_PATH..".toolbox.ui.inspector.previewer")
local WindowPopup = Nodes("WindowPopup")
local Label = Nodes("Label")
local Button = Nodes("Button")

---@class Previewer.LoveObject: Previewer
---@field property Property.LoveObject
local LObjectP = Previewer:extend()

function LObjectP:new(node, property, propertyName, inspector)
	LObjectP.super.new(self, node, property, propertyName)
	---@type Toolbox.Inspector
	self.inspector = inspector
end

function LObjectP:construct(object, property, propertyName)
	self.nameLabel = self:newNameLabel(object, property, propertyName)
	self.value = self:newValueLabel(object, property, propertyName)

	local nilButton = Button("x")
		:setAnchors(1, 0, 1, 1)
		:setOffsets(-20, 0, 0, 0)
	nilButton.clicked:connect(self, "makeNil")

	local newButton = Button("+")
		:setAnchors(1, 0, 1, 1)
		:setOffsets(-40, 0, -20, 0)
	newButton.clicked:connect(self, "showConstructPopup")

	self:addChild(self.nameLabel)
	self:addChild(self.value)
	self:addChild(newButton)
	self:addChild(nilButton)
end

---@param self Button
local function buttonCanDropData(self, posX, posY, data)
	if type(data) == "table" and data.type == "loveobject" then
		---@type Previewer.LoveObject
		local previewer = self.previewer

		---@type love.Object?
		local object = data.object
		if object and LoveClasses.doesClassInherit(previewer.property.baseClass, object) then
			return true
		end
	end
end

---@param self Button
local function buttonGetDragData(self)
	-- Return the contained love.Object
	---@type Previewer.LoveObject
	local previewer = self.previewer
	local object = previewer.property:get(previewer.object, previewer.propertyName)
	if not object then return end
	return
		{type = "loveobject", object = object},
		Label(("%s\n(Love2D Object)"):format(tostring(object)))
end

---@param self Button
local function buttonDropData(self, posX, posY, data)
	if type(data) == "table" and data.type == "loveobject" then
		---@type love.Object?
		local object = data.object
		if not object then return end
		---@type Previewer.LoveObject
		local previewer = self.previewer
		if object and LoveClasses.doesClassInherit(previewer.property.baseClass, object) then
			previewer:attemptSet(object)
			return true
		end
	end
end
function LObjectP:newValueLabel(object, property, propertyName, inspector)
	---@type Object
	local val = property:get(object, propertyName)
	local name = tostring(val)

	local button = Button(name)
		:setAnchors(1, 0, 1, 1)
		:setOffsets(-150, 0, -40, 0)
		:setClipText(true)
	button.clicked:connect(self, "onValueButtonClicked")
	button:setDisabled(val == nil)

	button.previewer = self
	button._canDropData = buttonCanDropData
	button._getDragData = buttonGetDragData
	button._dropData = buttonDropData

	return button
end

---When the value button is clicked, show the edit popup
function LObjectP:onValueButtonClicked()
	local object, property, propertyName =
		self.object, self.property, self.propertyName
	local val = property:get(object, propertyName)

	self:showEditPopup(val)
end

---Used for a Button connection; sets this property to `nil`
function LObjectP:makeNil()
	return self:attemptSet()
end

function LObjectP:onInput(node)
	local object, property, propertyName =
		self.object, self.property, self.propertyName
	property:set(object, propertyName, node)

	local val = property:get(object, propertyName)
	local name = tostring(val)

	self.value:setText(name)
		:setDisabled(val == nil)
end

---Shows a dialog to edit this LoveObject
function LObjectP:showConstructPopup()
	local property, propertyName =
		self.property, self.propertyName
	local baseClass = property.baseClass

	local window = WindowPopup()
	window._destroyOnClose = true
	window:setAnchorsAndOffsets(
		0, 1, 0, 1,
		-200, -100, 0, 100
	)
	window:getTitleLabel():setText(("Set '%s' (%s)"):format(propertyName, baseClass))

	--- All classes that match the provided base class
	local menuItems = LoveClasses.getConstructorFormList(LoveClasses.getClassDescendants(baseClass))

	---@type Form
	local form = {
		{type = "body", text = "Object Type"},
		{id = "className", type = "dropdown", items = menuItems},
	}

	local vbox, sheet = FormBuilder.build(form)
	---@cast vbox VBox
	vbox:setAnchorsAndOffsets(
			0, 0, 1, 1,
			10, 10, -10, 0
		)
		:setResizeToContent(true)
		:setMargin(4)

	---@type VBox?, Form.Sheet?
	local otherVBox, otherSheet

	-- Add to the sheet when something is selected
	---@type DropdownButton
	local dropdown = sheet:getElement("className")
	dropdown:getPopupMenu().itemSelected:connectCallable(function(_, _, item)
		---@cast item LoveClasses.Constructor
		if otherVBox then
			-- Remove the old sheet
			otherVBox:unparent()
			otherVBox:queueDestroy(true)
		end

		---@type VBox, Form.Sheet
		otherVBox, otherSheet = FormBuilder.build(item.form)
		otherVBox:setAnchorsAndOffsets(
				0, 0, 1, 1,
				0, 10, 0, 0
			)
			:setResizeToContent(true)
			:setMargin(4)
		vbox:addChild(otherVBox)
	end)

	-- Build the sheet with the current selection
	if dropdown:getSelectedItem() then
		---@type VBox, Form.Sheet
		otherVBox, otherSheet = FormBuilder.build(dropdown:getSelectedItem().form)
		otherVBox:setAnchorsAndOffsets(
				0, 0, 1, 1,
				0, 10, 0, 0
			)
			:setResizeToContent(true)
			:setMargin(4)
		vbox:addChild(otherVBox)
	end

	-- Connect events
	window:addAction("Cancel", "close")
	window:addAction("Set", "submit")
	window.submit = function(...)
		---@type LoveClasses.Constructor?
		local item = dropdown:getSelectedItem()
		if not item or not otherSheet then return end

		local toolbox = Previewer.Toolbox
		local srContainer = toolbox:getSubrootContainer()
		if not srContainer then return end

		srContainer:pushSubroot()
		local result = item.submit(otherSheet)
		if result then
			self:attemptSet(result)
		end
		srContainer:popSubroot()

		if result then
			window:close()
		end
	end

	window:addChild(vbox)
	self:addChild(window)
	window:popup()
end

---Shows a dialog to edit this love.Object
---@param val love.Object
function LObjectP:showEditPopup(val)
	if not val then return end

	local object, property, propertyName =
		self.object, self.property, self.propertyName
	local baseClass = val:type()

	local window = WindowPopup()
	window._destroyOnClose = true
	window:setAnchorsAndOffsets(
		0, 1, 0, 1,
		-200, -100, 0, 100
	)
	window:getTitleLabel():setText(("Edit '%s' (%s)"):format(propertyName, baseClass))

	-- All classes that match the provided base class
	local menuItems = LoveClasses.getEditFormList(LoveClasses.getClassAncestors(baseClass))

	---@type Form
	local form = {
		{type = "body", text = "Object Type"},
		{id = "className", type = "dropdown", items = menuItems},
	}

	local vbox, sheet = FormBuilder.build(form)
	---@cast vbox VBox
	vbox:setAnchorsAndOffsets(
			0, 0, 1, 1,
			10, 10, -10, 0
		)
		:setResizeToContent(true)
		:setMargin(4)

	---@type VBox?, Form.Sheet?
	local otherVBox, otherSheet

	-- Add to the sheet when something is selected
	---@type DropdownButton
	local dropdown = sheet:getElement("className")
	dropdown:getPopupMenu().itemSelected:connectCallable(function(_, _, item)
		---@cast item LoveClasses.EditForm
		if otherVBox then
			-- Remove the old sheet
			otherVBox:unparent()
			otherVBox:queueDestroy(true)
		end

		---@type VBox, Form.Sheet
		otherVBox, otherSheet = FormBuilder.build(item.form)
		otherVBox:setAnchorsAndOffsets(
				0, 0, 1, 1,
				0, 10, 0, 0
			)
			:setResizeToContent(true)
			:setMargin(4)

		if item.fill then
			-- Update the fields with the current values
			item.fill(otherSheet, val)
		end

		vbox:addChild(otherVBox)
	end)

	-- Build the sheet with the current selection
	if dropdown:getSelectedItem() then
		---@type LoveClasses.EditForm
		local editForm = dropdown:getSelectedItem()
		---@type VBox, Form.Sheet
		otherVBox, otherSheet = FormBuilder.build(editForm.form)
		otherVBox:setAnchorsAndOffsets(
				0, 0, 1, 1,
				0, 10, 0, 0
			)
			:setResizeToContent(true)
			:setMargin(4)

		if editForm.fill then
			-- Update the fields with the current values
			editForm.fill(otherSheet, val)
		end

		vbox:addChild(otherVBox)
	end

	-- Connect events
	window:addAction("Cancel", "close")
	window:addAction("Set", "submit")
	window.submit = function(...)
		---@type LoveClasses.EditForm?
		local item = dropdown:getSelectedItem()
		if not item or not otherSheet then return end

		local toolbox = Previewer.Toolbox
		local srContainer = toolbox:getSubrootContainer()
		if not srContainer then return end

		srContainer:pushSubroot()
		local result = item.submit(otherSheet, val)
		if result then
			property:poke(object, propertyName)
		end
		srContainer:popSubroot()

		if result then
			window:close()
		end
	end

	window:addChild(vbox)
	self:addChild(window)
	window:popup()
end

return LObjectP
