---@type AdoreInit
local Adore = require ""

local Object = Adore.Resources("Object")
local Node = Adore.Nodes("Node")

---Contexts simply receive love events, and return `true` if they handled it.
---@class Context: Object
---@field super Context
---@overload fun(): Context
local Context = Object:extend()
Context.CLASS_NAME = "Context"

function Context:new()
	Context.super.new(self)

	---@type string # The name for this Context
	self.name = self.CLASS_NAME

	---@type number # Higher values make this `Context` receive events earlier.
	---* If pushed, and an existing `Context` has the same priority value, this `Context` will receive events earlier.
	---* If priority is changed while active, this `Context` will receive events earlier than an existing `Context` with the same priority.
	---* `CoreUIContext` has a priority of 1000.
	self._priority = 0
	---@type boolean # Whether this Context is in a stack currently
	self._inStack = false
	---@type boolean # Whether this Context should sink handled input
	self.sinkHandledInput = true
end

---@param stack Context[]
---@param context Context
local function push(stack, context)
	local pushIndex = 1
	local ownPriority = context._priority
	for i = #stack, 1, -1 do
		if stack[i]._priority <= ownPriority then
			pushIndex = i + 1
			break
		end
	end
	table.insert(stack, pushIndex, context)
end

---Adds this Context into the stack, if it isn't in the stack yet
function Context:push()
	if self._inStack then return end
	self._inStack = true
	local root = Node._root
	local stack = root._contextStack
	push(stack, self)
	self:pushed()
end

---Removes this Context from the stack, if it's there
function Context:pop()
	if not self._inStack then return end
	local root = Node._root
	local stack = root._contextStack

	for i = #stack, 1, -1 do
		if stack[i] == self then
			table.remove(stack, i)
			self._inStack = false
			self:popped()
			return
		end
	end

	-- Improperly removed
	error("This Context could not be found in the RootNode's ContextStack (removed outside of :pop())")
end

---Sets the priority of the Context.
---* If called while pushed, this Context will receive events earlier than Contexts with the same priority
---* If called without a parameter, this Context will get moved ahead similarly
---@param newValue number?
function Context:setPriority(newValue)
	if not newValue then newValue = self._priority end
	self._priority = newValue
	if self._inStack then
		self:pop()
		self:push()
	end
end

---@param key love.KeyConstant
---@param scancode love.Scancode
---@param isRepeat boolean
---@return boolean handled
function Context:keypressed(key, scancode, isRepeat)
	return false
end

---@param key love.KeyConstant
---@param scancode love.Scancode
---@return boolean handled
function Context:keyreleased(key, scancode)
	return false
end

---@param text string
---@return boolean handled
function Context:textinput(text)
	return false
end

---@param x integer
---@param y integer
---@param dx integer
---@param dy integer
---@param isTouch boolean
---@return boolean handled
function Context:mousemoved(x, y, dx, dy, isTouch)
	return false
end

---@param x integer
---@param y integer
---@param button integer
---@param isTouch boolean
---@param presses integer
---@return boolean handled
function Context:mousepressed(x, y, button, isTouch, presses)
	return false
end

---@param x integer
---@param y integer
---@param button integer
---@param isTouch boolean
---@param presses integer
---@return boolean handled
function Context:mousereleased(x, y, button, isTouch, presses)
	return false
end

---@param x integer
---@param y integer
---@return boolean handled
function Context:wheelmoved(x, y)
	return false
end

---@param joystick love.Joystick
---@param axis love.GamepadAxis
---@param value number
---@return boolean handled
function Context:gamepadaxis(joystick, axis, value)
	return false
end

---@param joystick love.Joystick
---@param button love.GamepadButton
---@return boolean handled
function Context:gamepadpressed(joystick, button)
	return false
end

---@param joystick love.Joystick
---@param button love.GamepadButton
---@return boolean handled
function Context:gamepadreleased(joystick, button)
	return false
end

---@param joystick love.Joystick
---@return boolean handled
function Context:joystickadded(joystick)
	return false
end

---@param joystick love.Joystick
---@param axis number
---@param value number
---@return boolean handled
function Context:joystickaxis(joystick, axis, value)
	return false
end

---@param joystick love.Joystick
---@param axis number
---@param direction love.JoystickHat
---@return boolean handled
function Context:joystickhat(joystick, axis, direction)
	return false
end

---@param joystick love.Joystick
---@param button number
---@return boolean handled
function Context:joystickpressed(joystick, button)
	return false
end

---@param joystick love.Joystick
---@param button number
---@return boolean handled
function Context:joystickreleased(joystick, button)
	return false
end

---@param joystick love.Joystick
---@return boolean handled
function Context:joystickremoved(joystick)
	return false
end

---@param id lightuserdata
---@param x integer
---@param y integer
---@param dx integer
---@param dy integer
---@param pressure number
---@return boolean handled
function Context:touchmoved(id, x, y, dx, dy, pressure)
	return false
end

---@param id lightuserdata
---@param x integer
---@param y integer
---@param dx integer
---@param dy integer
---@param pressure number
---@return boolean handled
function Context:touchpressed(id, x, y, dx, dy, pressure)
	return false
end

---@param id lightuserdata
---@param x integer
---@param y integer
---@param dx integer
---@param dy integer
---@param pressure number
---@return boolean handled
function Context:touchreleased(id, x, y, dx, dy, pressure)
	return false
end

---@param dt number
---@return boolean handled
function Context:update(dt)
	return false
end

---Called after :update() has finished on the RootNode's children
---@return boolean handled
function Context:postUpdate()
	return false
end

---Called at the end of the RootNode's `:resize()`
---@param newW any
---@param newH any
function Context:resize(newW, newH)
	return false
end

---Called when love.mousefocus happens
---@param inWindow boolean
function Context:mousefocus(inWindow)
	return false
end

---Called when this Context is pushed onto the stack; should be overridden
function Context:pushed()
end

---Called when this Context is popped from the stack; should be overridden
function Context:popped()
end

local specialByte = ("%"):byte(1, 1)
local ContextRefMT = {
	__index = function(self, k)
		if k ~= "is" then
			-- Type isn't checked here, it's done via function value
			local realVal = rawget(self, k)
			if realVal ~= nil then return realVal end
			return rawget(self, "ref")[k]
		end
	end,
	__newindex = function(self, k, v)
		-- If the key starts with '%', we set the value on this Reference.
		-- Otherwise, set it in the original Context.
		---@cast k string
		if k:byte(1, 1) == specialByte then
			rawset(self, k:sub(2), v)
		else
			rawget(self, "ref")[k] = v
		end
	end,
	__tostring = function(self)
		return ("ContextRef [%s]"):format(tostring(rawget(self, "ref")))
	end
}

---An override for `:is()` that works for references
---@param self Context
---@param type Object
---@return unknown
local function _contextRefIs(self, type)
	local ref = rawget(self, "ref")
	return ref:is(type)
end

---@class ContextRef: Context

---Creates a ContextRef that points to this Context; it may be interacted with independently of the main Context.
---Primarily useful for:
---* Overriding values temporarily (via indexing with % as the prefix)
---  * `print(ref.name)` => `"Original Name"`
---  * `ref["%name"] = "Temporary Name"`
---  * `print(ref.name)` => `"Temporary Name"`
---  * `print(original.name)` => `"Original Name"`
---  * In the original Context, `name` is unchanged
---* Avoiding duplicating the same Context
---  * Popups support `Escape` to close
---    * However, if they all share the same Context, with multiple open popups, they will ALL get closed with one press
---  * Make a reference for each popup; they can now be closed individually
---@return ContextRef
function Context:newReference()
	return setmetatable({
		ref = self,
		isReference = true,
		is = _contextRefIs,
		_currentStack = "none"
	}, ContextRefMT)
end

function Context:__tostring()
	return ("%s (%s)"):format(self.name, self.CLASS_NAME)
end

---Things that this Context should handle
Context.HANDLERS = {
	keypressed = true,
	keyreleased = true,
	textinput = true,
	mousemoved = true,
	mousepressed = true,
	mousereleased = true,
	wheelmoved = true,
	gamepadaxis = true,
	gamepadpressed = true,
	gamepadreleased = true,
	joystickadded = true,
	joystickaxis = true,
	joystickhat = true,
	joystickpressed = true,
	joystickreleased = true,
	joystickremoved = true,
	touchmoved = true,
	touchpressed = true,
	touchreleased = true,

	update = true,
	postUpdate = true,
	resize = true,

	mousefocus = true,

	pushed = true,
	popped = true,
}

return Context
