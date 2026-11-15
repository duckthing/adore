local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local FormBuilder = Adore.Common("FormBuilder")

local Previewer = require(ADORE_PATH..".toolbox.ui.inspector.previewer")
local Button = Nodes("Button")
local Label = Nodes("Label")
local VBox = Nodes("VBox")
local HBox = Nodes("HBox")
local WindowPopup = Nodes("WindowPopup")
local DropdownButton = Nodes("DropdownButton")
local LineEdit = Nodes("LineEdit")

---`caster` returns `true` and the new value if casting was successful
---@type PopupMenu.Item[]
---| {caster: fun(string: string): boolean, string|any}
local allowedTypes = {
	{label = "string", caster = function(string)
		return true, string
	end},
	{label = "number", caster = function(string)
		local num = tonumber(string)
		if num then return true, num end
		return false, "Could not cast into a number"
	end},
	{label = "boolean", caster = function(string)
		string = string:lower()
		if string == "true" or string == "1" then
			return true, true
		elseif string == "false" or string == "f" or string == "0" then
			return true, false
		end
		return false, "Could not cast into a boolean"
	end},
	{label = "nil", caster = function() return true, nil end},
}

---@class Previewer.Table: Previewer
---@field property Property.Table
local TableP = Previewer:extend()

function TableP:new(node, property, propertyName, inspector)
	TableP.super.new(self, node, property, propertyName)
	---@type Toolbox.Inspector
	self.inspector = inspector
end

function TableP:construct(object, property, propertyName)
	self.nameLabel = self:newNameLabel(object, property, propertyName)
	local value = self:newValueLabel(object, property, propertyName)
	self.value = value
	self:setValueText(value, property:get(object, propertyName))

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
	if type(data) == "table" and data.type == "table" then
		---@type Previewer.Table
		local previewer = self.previewer

		---@type table?
		local t = data.table
		if type(t) == "table" then
			return true
		end
	end
end

---@param self Button
local function buttonGetDragData(self)
	-- Return the contained Object
	---@type Previewer.Table
	local previewer = self.previewer
	local t = previewer.property:get(previewer.object, previewer.propertyName)
	if type(t) ~= "table" then return end
	return
		{type = "table", table = t},
		Label(("%s (table)"):format(tostring(t)))
end

---@param self Button
local function buttonDropData(self, posX, posY, data)
	if type(data) == "table" and data.type == "table" then
		---@type table?
		local t = data.table
		if type(t) ~= "table" then return end
		---@type Previewer.Table
		local previewer = self.previewer
		if t then
			previewer:attemptSet(t)
			return true
		end
	end
end

function TableP:newValueLabel(object, property, propertyName, inspector)
	local button = Button()
		:setAnchors(1, 0, 1, 1)
		:setOffsets(-150, 0, -20, 0)
		:setClipText(true)
	button.clicked:connect(self, "editTable")

	button.previewer = self
	button._canDropData = buttonCanDropData
	button._getDragData = buttonGetDragData
	button._dropData = buttonDropData

	return button
end

---Used for a Button connection; sets this property to `nil`
function TableP:makeNil()
	local object, property, propertyName =
		self.object, self.property, self.propertyName
	---@type table?
	local t = property:get(object, propertyName)
	if t then
		return self:attemptSet()
	end
end

---Sets the text on the value button
---@param valueButton Button
---@param t table?
function TableP:setValueText(valueButton, t)
	if t then
		-- Table exists
		if next(t) ~= nil then
			-- Has an element
			valueButton:setText("{...}")
		else
			-- Has no elements
			valueButton:setText("{}")
		end
	else
		-- Table doesn't exist
		valueButton:setText("nil\nClick to create")
	end
end

function TableP:onInput(newTable)
	local object, property, propertyName =
		self.object, self.property, self.propertyName
	property:set(object, propertyName, newTable)
	self:setValueText(self.value, property:get(object, propertyName))
end

---(Re)builds the key-pair labels
---@param pairVBox VBox
---@param t table
local function buildPairs(pairVBox, t)
	for k, v in pairs(t) do
		local hbox = HBox()
			:setAnchorsAndOffsets(
				0, 0, 1, 0,
				0, 0, 0, 20
			)

		local keyTypeLabel = Label(type(k))
			:setAnchorsAndOffsets(
				0, 0, 0, 1,
				0, 0, 60, 0
			)
		local keyLabel = Label(tostring(k))
			:setAnchorsAndOffsets(
				0, 0, 0.5, 1,
				60, 0, 0, 0
			)

		local valueTypeLabel = Label(type(v))
			:setAnchorsAndOffsets(
				0.5, 0, 0.5, 1,
				0, 0, 60, 0
			)
		local valueLabel = Label(tostring(v))
			:setAnchorsAndOffsets(
				0.5, 0, 1, 1,
				60, 0, 0, 0
			)

		hbox:addChild(keyTypeLabel)
		hbox:addChild(keyLabel)
		hbox:addChild(valueTypeLabel)
		hbox:addChild(valueLabel)
		pairVBox:addChild(hbox)
	end
end

---Shows a dialog to edit this table
function TableP:editTable()
	local object, property, propertyName =
		self.object, self.property, self.propertyName

	local t = property:get(self.object, propertyName)
	if not t then
		-- Create a default table
		self:attemptSet({})
		return
	end

	local window = WindowPopup()
	window._destroyOnClose = true
	window._resizeWithParent = false
	window:setAnchorsAndOffsets(
		0, 1, 0, 1,
		-300, -200, 300, 200
	)
	window:getTitleLabel():setText(("Edit '%s' (table)"):format(propertyName))
	window:addAction("Close", "close")

	-- The contents of the table
	local pairVBox = VBox()
		:setAnchorsAndOffsets(
			0, 0, 1, 1,
			0, 30, 0, 0
		)

	-- Insert the key-value pairs
	buildPairs(pairVBox, t)

	-- Build the "edit HBox" which allows editing table contents
	local editHBox = HBox()
		:setAnchorsAndOffsets(
			0, 0, 1, 0,
			0, 0, 0, 20
		)
	do
		local keyTypeDropdown = DropdownButton(nil, allowedTypes)
			:setAnchorsAndOffsets(
				0, 0, 0, 1,
				0, 0, 60, 0
			)
		local keyLE = LineEdit()
			:setPlaceholderText("Key...")
			:setAnchorsAndOffsets(
				0, 0, 0.5, 1,
				60, 0, 0, 0
			)

		local valueTypeDropdown = DropdownButton(nil, allowedTypes)
			:setAnchorsAndOffsets(
				0.5, 0, 0.5, 1,
				0, 0, 60, 0
			)
		local valueLE = LineEdit()
			:setPlaceholderText("Value...")
			:setSubmitOnFocusLost(false)
			:setAnchorsAndOffsets(
				0.5, 0, 1, 1,
				60, 0, -40, 0
			)

		local setButton = Button("Set")
			:setAnchorsAndOffsets(
				1, 0, 1, 1,
				-40, 0, 0, 0
			)
		setButton.clicked:connect(valueLE, "submit")

		editHBox:addChild(keyTypeDropdown)
		editHBox:addChild(keyLE)
		editHBox:addChild(valueTypeDropdown)
		editHBox:addChild(valueLE)
		editHBox:addChild(setButton)

		---@param le LineEdit
		---@param submittedText string
		valueLE.textSubmitted:connectCallable(function(le, submittedText)
			local keyItem = keyTypeDropdown:getSelectedItem()
			local success, errOrVal = keyItem.caster(keyLE._submittedText)
			local key, value

			if success then
				key = errOrVal
			else
				-- Errored casting to the type
				print(errOrVal)
				return
			end

			local valueItem = valueTypeDropdown:getSelectedItem()
			success, errOrVal = valueItem.caster(submittedText)

			if success then
				value = errOrVal
			else
				-- Errored casting to the type
				print(errOrVal)
				return
			end

			t = property:get(object, propertyName)
			t[key] = value
			pairVBox:clearChildren(true)
			buildPairs(pairVBox, t)
		end)
	end

	window:addChild(editHBox)
	window:addChild(pairVBox)

	self:addChild(window)
	window:popupCentered()
end

return TableP
