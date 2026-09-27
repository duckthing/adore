---Helper for dealing with Love2d Objects
---@class LoveClasses
local LoveClasses = {}

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

---Gets a list of all classes that inherit from a base class.
---It's "below" this class.
---@param baseClass string
---@param arr string[]? # Existing matched classes
---@return string[] descendants
local function getClassDescendants(baseClass, arr)
	-- Insert the base class, if it's found
	if not arr and not allLoveObjects[baseClass] then return {} end
	arr = arr or {baseClass}

	for class, inheritsFrom in pairs(allLoveObjects) do
		-- Inherits from base class, and is not equal to itself (Object loop)
		if inheritsFrom == baseClass and class ~= baseClass then
			arr[#arr+1] = class
			getClassDescendants(class, arr)
		end
	end

	return arr
end

---Gets a list of the super classes from the given class, including the current class
---@param className string
---@return string[]
local function getClassAncestors(className)
	local arr = {className}

	local currClass = className
	while currClass ~= "Object" do
		local inherited = allLoveObjects[currClass]
		if not inherited then break end
		arr[#arr+1] = inherited
		currClass = inherited
	end

	return arr
end

---@alias LoveClasses.Constructor
---| PopupMenu.Item | {class: string, form: Form, submit: (fun(sheet: Form.Sheet): love.Object?)}

---@type LoveClasses.Constructor[]
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
	{
		label = "Box2D World",
		class = "World",
		form = {
			{type = "body", text = "Gravity X"},
			{id = "gx", type = "textfield", value = "0"},
			{type = "body", text = "Gravity Y"},
			{id = "gy", type = "textfield", value = "0"},
		},
		submit = function(sheet)
			local gx, gy = tonumber(sheet:getValue("gx")), tonumber(sheet:getValue("gy"))
			return love.physics.newWorld(gx or 0, gy or 0)
		end
	},
}

---Gets a list of constructor Forms for the given classes
---@param classes string[]
---@return LoveClasses.Constructor[]
local function getConstructorList(classes)
	---@type LoveClasses.Constructor[]
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

---@alias LoveClasses.EditForm
---| PopupMenu.Item
---| {class: string, form: Form, submit: (fun(sheet: Form.Sheet, obj: love.Object): boolean)}
---| {fill: (fun(sheet: Form.Sheet, obj: love.Object))?}

---@type LoveClasses.EditForm[]
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
			local gx, gy = tonumber(sheet:getValue("gx")), tonumber(sheet:getValue("gy"))
			local oldGX, oldGY = obj:getGravity()
			obj:setGravity(gx or oldGX, gy or oldGY)
			return true
		end
	},
}

---Gets a list of edit Forms for the given classes
---@param classes string[]
---@return LoveClasses.EditForm[]
local function getEditFormList(classes)
	---@type LoveClasses.EditForm[]
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

---Returns `true` if `inheritingClass` inherits from or matches `baseClass`
---`inheritingClass:is(baseClass) or baseClass == inheritingClass`
---@param baseClass string | love.Object
---@param inheritingClass string | love.Object
---@return boolean inherits
function LoveClasses.doesClassInherit(baseClass, inheritingClass)
	-- Converts from class object to class name
	if type(baseClass) == "userdata" then baseClass = baseClass:type() end
	if type(inheritingClass) == "userdata" then inheritingClass = inheritingClass:type() end

	if baseClass == inheritingClass then return true end
	local currClass = inheritingClass
	while currClass ~= "Object" do
		currClass = allLoveObjects[currClass]
		if not currClass then return false end
		if baseClass == currClass then
			return true
		end
	end

	return false
end

LoveClasses.SUPER_CLASSES = allLoveObjects
LoveClasses.getClassDescendants = getClassDescendants
LoveClasses.getClassAncestors = getClassAncestors
LoveClasses.constructorForms = constructors
LoveClasses.getConstructorFormList = getConstructorList
LoveClasses.editForms = editForms
LoveClasses.getEditFormList = getEditFormList

return LoveClasses
