local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local FormBuilder = Adore.Common("FormBuilder")

---@type Previewer
local Previewer = require(ADORE_PATH..".toolbox.ui.inspector.previewer")
local WindowPopup = Nodes("WindowPopup")
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

	self:addChild(self.nameLabel)
	self:addChild(self.value)
	self:addChild(nilButton)
end

function LObjectP:newValueLabel(object, property, propertyName, inspector)
	---@type Object
	local val = property:get(object, propertyName)
	local name = tostring(val)

	local button = Button(name)
		:setAnchors(1, 0, 1, 1)
		:setOffsets(-150, 0, -20, 0)
	button.clicked:connect(self, "onValueButtonClicked")

	button.previewer = self

	return button
end

---When the value button is clicked, decide between a construct or edit popup
function LObjectP:onValueButtonClicked()
	local object, property, propertyName =
		self.object, self.property, self.propertyName
	local val = property:get(object, propertyName)

	if val == nil then
		-- No value; show the constructor popup
		self:showConstructPopup()
	else
		-- Existing value; edit with the editor popup
		self:showEditPopup(val)
	end
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
end

---@type {[string]: string} # Every Love object and the class they directly inherit from
local allLoveObjects = {
	Object = "Object",
	BezierCurve = "Object",
	Body = "Object",
	ByteData = "Data",
	Canvas = "Texture",
	ChainShape = "Shape",
	Channel = "Object",
	CircleShape = "Shape",
	CompressedData = "Data",
	CompressedImageData = "Data",
	Contact = "Object",
	Cursor = "Object",
	Data = "Object",
	Decoder = "Object",
	DistanceJoint = "Joint",
	Drawable = "Object",
	DroppedFile = "File",
	EdgeShape = "Shape",
	File = "Object",
	FileData = "Data",
	Fixture = "Object",
	Font = "Object",
	FrictionJoint = "Joint",
	GearJoint = "Joint",
	GlyphData = "Data",
	Image = "Texture",
	ImageData = "Data",
	Joint = "Object",
	Joystick = "Object",
	Mesh = "Drawable",
	MotorJoint = "Joint",
	MouseJoint = "Joint",
	ParticleSystem = "Drawable",
	PolygonShape = "Shape",
	PrismaticJoint = "Joint",
	PulleyJoint = "Joint",
	Quad = "Object",
	RandomGenerator = "Object",
	Rasterizer = "Object",
	RecordingDevice = "Object",
	RevoluteJoint = "Joint",
	RopeJoint = "Joint",
	Shader = "Object",
	Shape = "Object",
	SoundData = "Data",
	Source = "Object",
	SpriteBatch = "Drawable",
	Text = "Drawable",
	Texture = "Drawable",
	Thread = "Object",
	Transform = "Object",
	Video = "Drawable",
	VideoStream = "Object",
	WeldJoint = "Joint",
	WheelJoint = "Joint",
	World = "Object",
}

---Gets a list of all classes that inherit from a base class
---@param baseClass string
---@param arr string[]? # Existing matched classes
---@return string[]
local function getMatchedClasses(baseClass, arr)
	-- Insert the base class, if it's found
	if not arr and not allLoveObjects[baseClass] then return {} end
	arr = arr or {baseClass}

	for class, inheritsFrom in pairs(allLoveObjects) do
		-- Inherits from base class, and is not equal to itself (Object loop)
		if inheritsFrom == baseClass and class ~= baseClass then
			arr[#arr+1] = class
			getMatchedClasses(class, arr)
		end
	end

	return arr
end

---@alias Previewer.LoveObject.Constructor
---| PopupMenu.Item | {class: string, form: Form, submit: (fun(sheet: Form.Sheet): love.Object?)}

---@type Previewer.LoveObject.Constructor[]
local constructors = {
	{
		label = "Box (PolygonShape)",
		class = "PolygonShape",
		form = {
			{type = "body", text = "Width"},
			{id = "width", type = "textfield", value = "10"},
			{type = "body", text = "Height"},
			{id = "height", type = "textfield", value = "10"},
		},
		submit = function(sheet)
			local width, height =
				sheet:getValue("width"), sheet:getValue("height")
			return love.physics.newRectangleShape(width, height)
		end
	},
	{
		label = "CircleShape",
		class = "CircleShape",
		form = {
			{type = "body", text = "Radius"},
			{id = "radius", type = "textfield", value = "10"},
		},
		submit = function(sheet)
			local radius = sheet:getValue("radius")
			return love.physics.newCircleShape(radius)
		end
	},
}

---Gets a list of constructor Forms for the given classes
---@param classes string[]
---@return Previewer.LoveObject.Constructor[]
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

---Shows a dialog to edit this LoveObject
function LObjectP:showConstructPopup()
	local object, property, propertyName =
		self.object, self.property, self.propertyName
	---@type love.Object?
	local existingVal = property:get(object, propertyName)
	local baseClass = property.baseClass

	local window = WindowPopup()
	window._destroyOnClose = true
	window:setAnchorsAndOffsets(
		0, 1, 0, 1,
		-200, -100, 0, 100
	)
	window:getTitleLabel():setText(("Set '%s' (%s)"):format(propertyName, baseClass))

	--- All classes that match the provided base class
	local menuItems = getConstructorList(getMatchedClasses(baseClass))

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
		---@type Previewer.LoveObject.Constructor?
		local item = dropdown:getSelectedItem()
		if not item or not otherSheet then return end
		local result = item.submit(otherSheet)
		if result then
			self:attemptSet(result)
			window:close()
		end
	end

	window:addChild(vbox)
	self:addChild(window)
	window:popup()
end

---@alias Previewer.LoveObject.EditForm
---| PopupMenu.Item
---| {class: string, form: Form, submit: (fun(sheet: Form.Sheet, obj: love.Object): boolean)}
---| {fill: (fun(sheet: Form.Sheet, obj: love.Object))?}

---@type Previewer.LoveObject.EditForm[]
local editForms = {
	{
		label = "CircleShape",
		class = "CircleShape",
		form = {
			{type = "body", text = "Radius"},
			{id = "radius", type = "textfield", value = "10"},
		},
		fill = function(sheet, obj)
			---@cast obj love.CircleShape
			local radiusField = sheet:getElement("radius")
			---@cast radiusField LineEdit
			radiusField:setText(tostring(obj:getRadius()))
		end,
		submit = function(sheet, obj)
			---@cast obj love.CircleShape
			local oldRadius = obj:getRadius()
			obj:setRadius(tonumber(sheet:getValue("radius")) or oldRadius)
			return true
		end
	},
	{
		label = "Box2D World",
		class = "World",
		form = {
			{type = "body", text = "Gravity X"},
			{id = "gx", type = "textfield", value = "0"},
			{type = "body", text = "Gravity Y"},
			{id = "gy", type = "textfield", value = "0"},
		},
		fill = function(sheet, obj)
			---@cast obj love.World
			local gxField, gyField = sheet:getElement("gx"), sheet:getElement("gy")
			---@cast gxField LineEdit
			---@cast gyField LineEdit
			local gx, gy = obj:getGravity()
			gxField:setText(tostring(gx))
			gyField:setText(tostring(gy))
		end,
		submit = function(sheet, obj)
			---@cast obj love.World
			local gx, gy = sheet:getValue("gx"), sheet:getValue("gy")
			local oldGX, oldGY = obj:getGravity()
			obj:setGravity(tonumber(gx) or oldGX, tonumber(gy) or oldGY)
			return true
		end
	},
}

---Gets a list of edit Forms for the given classes
---@param classes string[]
---@return Previewer.LoveObject.EditForm[]
local function getEditFormList(classes)
	---@type Previewer.LoveObject.EditForm[]
	local forms = {}

	---@type {[string]: true} # included[editForms[i].form] = true
	local included = {}
	for i = 1, #classes do included[classes[i]] = true end

	for i = 1, #editForms do
		local editForm = editForms[i]
		if included[editForm.class] then
			forms[#forms+1] = editForm
		end
	end

	return forms
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
	local menuItems = getEditFormList(getMatchedClasses(baseClass))

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
		---@cast item Previewer.LoveObject.EditForm
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
		---@type Previewer.LoveObject.EditForm
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
		---@type Previewer.LoveObject.EditForm?
		local item = dropdown:getSelectedItem()
		if not item or not otherSheet then return end
		local result = item.submit(otherSheet, val)
		if result then
			property:poke(object, propertyName)
			window:close()
		end
	end

	window:addChild(vbox)
	self:addChild(window)
	window:popup()
end

return LObjectP
