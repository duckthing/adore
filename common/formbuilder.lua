---@type AdoreInit
local Adore = require ""
local Nodes = Adore.Nodes

local Control = Nodes("Control")
local VBox = Nodes("VBox")
local Label = Nodes("Label")
local LineEdit = Nodes("LineEdit")
local DropdownButton = Nodes("DropdownButton")

---@alias FormBuilder.Build fun(form: Form): Control, Form.Sheet

---@alias Form Form.Item[]

---@alias Form.ItemTypes
---| "header"
---| "body"
---| "separator"
---| "textfield"
---| "dropdown"
---| string

---@alias Form.Item
---| {id: any, type: Form.ItemTypes}
---| {id: any, type: "header", text: string?}
---| {id: any, type: "body", text: string?}
---| {id: any, type: "separator"}
---| {id: any, type: "textfield", value: string?, placeholder: string?}
---| {id: any, type: "dropdown", value: any?, items: PopupMenu.Item[]}

---@class FormBuilder
local FormBuilder = {}

---@class Form.Sheet
local FormSheet = {}
local FormSheetMT = {__index = FormSheet}

---Gets the element associated with the id
---@param id any
---@return Control? value
function FormSheet:getElement(id)
	return self.idToElement[id]
end

---Gets the value associated with the id
---@param id any
---@return any value
function FormSheet:getValue(id)
	local element = self.idToElement[id]
	if not element then return end
	local elementType = self.idToType[id]
	if elementType == "textfield" then
		---@cast element LineEdit
		return element._submittedText
	elseif elementType == "dropdown" then
		---@cast element DropdownButton
		return element._selectedItem
	end
end

---@type {[string]: fun(item: Form.Item): Control?}
local builders = {
	header = function(item)
		local label = Label(item.text)
			:setAnchors(0, 0, 1, 0)
			:setFontSize(24)
			:setJustify("center")
		return label
	end,
	body = function(item)
		local label = Label(item.text)
			:setAnchors(0, 0, 1, 0)
		return label
	end,
	separator = function(item)
		local separator = Control()
			:setAnchorsAndOffsets(
				0, 1, 0, 0,
				0, 0, 8, 0
			)
		return separator
	end,
	textfield = function(item)
		local field = LineEdit(item.value)
			:setAnchorsAndOffsets(
				0, 0, 1, 0,
				0, 0, 0, 22
			)
		if item.placeholder then field:setPlaceholderText(item.placeholder) end
		return field
	end,
	dropdown = function(item)
		local dropdown = DropdownButton(item.text, item.items)
			:setAnchorsAndOffsets(
				0, 0, 1, 0,
				0, 0, 0, 20
			)
		return dropdown
	end
}

---@type FormBuilder.Build
function FormBuilder.build(form)
	local vbox = VBox()
		:setAnchors(0, 0, 1, 1)
		:setResizeToContent(true)

	---@type {[any]: Control} # Maps an id to the element associated with it
	local idToElement = {}
	---@type {[any]: Form.ItemTypes} # Maps an id to the type of field
	local idToType = {}

	---@class Form.Sheet
	local sheet = setmetatable({
		---@type Control # The container Control that has every created element
		control = vbox,
		idToElement = idToElement,
		idToType = idToType,
	}, FormSheetMT)

	for i = 1, #form do
		local item = form[i]
		local itemType = item.type
		---@type Control?
		local element = builders[itemType](item)
		vbox:addChild(element)

		local id = item.id
		if id then
			idToElement[id] = element
			idToType[id] = itemType
		end
	end

	return vbox, sheet
end

return FormBuilder
