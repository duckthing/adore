local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local FormBuilder = Adore.Common("FormBuilder")

local Previewer = require(ADORE_PATH..".toolbox.ui.inspector.previewer")
local Button = Nodes("Button")
local WindowPopup = Nodes("WindowPopup")

---@class Previewer.Object: Previewer
---@field property Property.Object
local ObjectP = Previewer:extend()

function ObjectP:new(node, property, propertyName, inspector)
	ObjectP.super.new(self, node, property, propertyName)
	---@type Toolbox.Inspector
	self.inspector = inspector
end

function ObjectP:construct(object, property, propertyName)
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

function ObjectP:newValueLabel(object, property, propertyName, inspector)
	---@type Object
	local val = property:get(object, propertyName)
	local name = tostring(val)
	local selectable = val and val._adoreSelectable
	if not selectable and val ~= nil then name = ("%s [INTERNAL]"):format(name) end
	local button = Button(name)
		:setAnchors(1, 0, 1, 1)
		:setOffsets(-150, 0, -40, 0)
		:setClipText(true)
	button.clicked:connect(self, "focusNode")
	button:setDisabled(not selectable)

	button.previewer = self

	return button
end

-- Focuses on the set Node
function ObjectP:focusNode()
	local object, property, propertyName =
		self.object, self.property, self.propertyName
	local val = property:get(object, propertyName)
	if val then
		self.inspector.sceneTree:focusNode(val)
	end
end

---Used for a Button connection; sets this property to `nil`
function ObjectP:makeNil()
	local object, property, propertyName =
		self.object, self.property, self.propertyName
	---@type Object?
	local val = property:get(object, propertyName)
	if val and val._adoreSelectable then
		-- Only set to nil when the value isn't internal
		return self:attemptSet()
	end
end

function ObjectP:onInput(node)
	local object, property, propertyName =
		self.object, self.property, self.propertyName
	property:set(object, propertyName, node)

	local val = property:get(object, propertyName)
	local name = tostring(val)
	local selectable = val and val._adoreSelectable
	if not selectable and val ~= nil then name = ("%s [INTERNAL]"):format(name) end
	self.value:setText(name)
		:setDisabled(not selectable)
end

---@alias Previewer.Object.Constructor
---| PopupMenu.Item | {class: string, form: Form, submit: (fun(sheet: Form.Sheet): Object?)}

---@type Previewer.Object.Constructor[]
local constructors = {
	{
		label = "Viewport",
		class = "Viewport",
		form = {
		},
		submit = function(sheet)
			---@type Toolbox
			local Toolbox = require(ADORE_PATH..".toolbox")
			local srContainer = Toolbox.mainWindow:getSubrootContainer()
			if not srContainer then return nil end

			local Viewport = Adore.Resources("Viewport")
			local parentViewport = srContainer.subroot._viewport
			local newViewport = Viewport()
			newViewport._parentViewport = parentViewport

			newViewport.getSafeArea = function()
				-- Use the overridden dimensions when using free-cam
				if srContainer.cameraActive then
					return 0, 0, srContainer.overrideW, srContainer.overrideH
				else
					return parentViewport:getSafeArea()
				end
			end
			return newViewport
		end
	},
}

---Gets a list of constructor Forms for the given classes
---@param classes string[]
---@return Previewer.Object.Constructor[]
local function getConstructorList(classes)
	---@type Previewer.LoveObject.Constructor[]
	local forms = {}

	---@type {[string]: true} # included[constructor[i].form] = true
	local included = {}
	for i = 1, #classes do included[classes[i]] = true end

	for i = 1, #constructors do
		local constructor = constructors[i]
		if included[constructor.class] then
			forms[#forms+1] = constructor
		end
	end

	return forms
end

---Shows a dialog to edit this Object
function ObjectP:showConstructPopup()
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
	local menuItems = getConstructorList(Adore.getClassDescendants(baseClass))

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
		---@cast item Previewer.LoveObject.Constructor
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
		---@type Previewer.Object.Constructor?
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

return ObjectP
