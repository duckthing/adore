---@type AdoreInit
local Adore = require ""
local Context = Adore.Resources("Context")
local min, max = math.min, math.max
local abs = math.abs
local sqrt = math.sqrt
local tclear = Adore.Common("Structures").tableClear

---GameContext is better suited for game input than ShortcutContext.
---The most recent input will be used for the value of an action; if a plugged-in gamepad is sending inputs on
---accident, you'll see it reflected.
---@class GameContext: Context
---@overload fun(options: GameContext.Options): GameContext
local GameContext = Context:extend()
GameContext.CLASS_NAME = "GameContext"

---@class GameContext.Options
---@field deadzone number? # The minimum distance from 0 for an action to be registered; default 0.15
---@field actions string[]? # Actions are represented by a value of 0..1, and are good for buttons
---@field pairs {[string]: string[]}? # Pairs are a map of pair names to an array of action names
---@field scancodes {[love.Scancode]: string}? # A map of keyboard scancodes to actions
---@field mouseButtons {[integer]: string}? # A map of mouse buttons to actions
---@field gamepadAxes {[string]: string}? # A map of gamepad axes to actions, plus their direction (ex. "leftx-", "leftx+")
---@field gamepadButtons {[love.GamepadButton]: string}? # A map of gamepad buttons to actions
---@field useScancode boolean? # Scancodes are keyboard layout independent, while keys are not (default: `true`)

---@param options GameContext.Options
function GameContext:new(options)
	GameContext.super.new(self)

	---@type {[string]: number} # A map of actions, 0..1, that can be combined together
	self.actionValues = {}
	---@type {[string]: string[]} # A map of pair names to an array of action names, that can be combined
	self.pairs = options.pairs or {}

	---The following are reset each :postUpdate()
	---@type {[string]: boolean} # Whether an action was pressed this update; cleared after every update
	self.actionPressed = {}
	---@type {[string]: boolean} # Whether an action was pressed this update; cleared after every update
	self.actionReleased = {}

	---@type {[love.Scancode]: string} # A map of keyboard scancodes to actions
	self.scancodes = options.scancodes or {}
	---@type {[integer]: string} # A map of mouse buttons to actions
	self.mouseButtons = options.mouseButtons or {}
	---@type {[string]: string} # A map of gamepad axes and their direction to actions (ex. leftx-, leftx+)
	self.gamepadAxes = options.gamepadAxes or {}
	---@type {[love.GamepadButton]: string} # A map of gamepad buttons to actions
	self.gamepadButtons = options.gamepadButtons or {}

	---@type number # Action values must be *greater than* the deadzone to be pressed; anything *less than or equal* is released
	self.deadzone = options.deadzone or 0.15
	---@type boolean # Should all values get released when popped from the stack?
	self.releaseWhenPopped = true

	---@type boolean # Whether scancodes (layout-independent) are used (default: `true`)
	self.useScancode = options.useScancode
	if self.useScancode == nil then self.useScancode = true end

	-- Add the action values
	local actions = options.actions
	if actions then
		for i = 1, #actions do
			self.actionValues[actions[i]] = 0
		end
	end

	-- Validate that the action maps go to a real action
	for i = 1, 4 do
		local tableName
		if i == 1 then tableName = "scancodes"
		elseif i == 2 then tableName = "gamepadAxes"
		elseif i == 3 then tableName = "mouseButtons"
		else tableName = "gamepadButtons" end

		-- self.scancodes, self.mouseButtons, self.gamepadAxes, self.gamepadButtons
		local map = self[tableName]
		for _, actionName in pairs(map) do
			if not self.actionValues[actionName] then
				error(("Action '%s' from '%s' doesn't exist"):format(actionName, tableName))
			end
		end
	end

	-- Verify all gamepad axes have a positive or negative direction
	if next(self.gamepadAxes) then
		local axes = self.gamepadAxes
		for axis, actionName in pairs(axes) do
			local lastChar = axis:sub(#axis)
			if lastChar ~= "-" and lastChar ~= "+" then
				-- No direction specified
				error(("Gamepad axis '%s' for action '%s' is missing a direction (should add '+' or '-' to end of axis)"):format(axis, actionName))
			end
		end
	end
end

---Sets the value (0..1) of an action, with :isJustPressed/Released() considered.
---Use this for input that can't be done through Love's callbacks (ex. touchscreen joysticks).
---@param actionName string
---@param value number
function GameContext:setValue(actionName, value)
	local oldValue = self.actionValues[actionName]
	if not oldValue then
		error(("'%s' is not an action inside of %s"):format(actionName, self))
	end

	local deadzone = self.deadzone
	value = max(0, min(value, 1))
	self.actionValues[actionName] = value

	local oldPressed, newPressed =
		oldValue > deadzone,
		value > deadzone

	if oldPressed ~= newPressed then
		if oldPressed then
			-- Just released
			self.actionReleased[actionName] = true
		else
			-- Just pressed
			self.actionPressed[actionName] = true
		end
	end
end

---Returns `true` if the action is pressed (aka. past the deadzone)
---@param actionName string
---@return boolean down
function GameContext:isDown(actionName)
	return self.actionValues[actionName] > self.deadzone
end

---Returns `true` if the action is not pressed (aka. equal to or less than the deadzone)
---@param actionName string
---@return boolean
function GameContext:isUp(actionName)
	return self.actionValues[actionName] <= self.deadzone
end

---From a pair that has a length of 4, returns the X/Y values of the actions they correspond to.
---Goes from {-X, +X, -Y, +Y}
---@param pairName string
---@return number x
---@return number y
function GameContext:getVector(pairName)
	local pair = self.pairs[pairName]
	if not pair then
		error(("Pair '%s' does not exist"):format(pairName))
	end
	local actions = self.actionValues
	local x, y =
		actions[pair[2]] - actions[pair[1]],
		actions[pair[4]] - actions[pair[3]]

	if x ~= 0 and y ~= 0 then
		local length2 = x*x + y*y
		if length2 > 1 then
			-- Normalize X/Y if their length is over 1
			local factor = 1 / sqrt(length2)
			x, y =
				x * factor,
				y * factor
		elseif length2 < self.deadzone then
			-- Less than the deadzone; do not receive
			x, y = 0, 0
		end
	end

	return x, y
end

---From a pair that has a length of 2, returns the values of the actions they correspond to.
---Goes from {negativeAction, positiveAction}
---@param pairName string
---@return number
function GameContext:getAxis(pairName)
	local pair = self.pairs[pairName]
	if not pair then
		error(("Pair '%s' does not exist"):format(pairName))
	end
	local actions = self.actionValues
	local axis = actions[pair[2]] - actions[pair[1]]

	if abs(axis) < self.deadzone then
		return 0
	else
		return min(axis, 1)
	end
end

---Returns `true` if the action was pressed this frame
---@param actionName string
---@param sink boolean? # Pass `true` to remove the pressed state
---@return boolean justReleased
function GameContext:isJustPressed(actionName, sink)
	local pressed = self.actionPressed[actionName]
	if sink and pressed then
		self.actionPressed[actionName] = nil
	end
	return pressed
end

---Returns `true` if the action was released this frame
---@param actionName string
---@param sink boolean? # Pass `true` to remove the released state
---@return boolean
function GameContext:isJustReleased(actionName, sink)
	local released = self.actionReleased[actionName]
	if sink and released then
		self.actionReleased[actionName] = nil
	end
	return released
end


--===== HANDLERS

function GameContext:keypressed(key, scancode, isRepeat)
	if isRepeat then return false end

	local button = (self.useScancode and scancode) or key

	local actionName = self.scancodes[button]
	if not actionName then return false end

	self.actionPressed[actionName] = true
	self.actionValues[actionName] = 1
	return self.sinkHandledInput
end

function GameContext:keyreleased(key, scancode)
	local button = (self.useScancode and scancode) or key

	local actionName = self.scancodes[button]
	if not actionName then return false end

	self.actionValues[actionName] = 0
	self.actionReleased[actionName] = true
	return self.sinkHandledInput
end

function GameContext:mousepressed(_, _, button, isTouch)
	if isTouch then return false end

	local actionName = self.mouseButtons[button]
	if not actionName then return false end

	self.actionValues[actionName] = 1
	self.actionPressed[actionName] = true
	return self.sinkHandledInput
end

function GameContext:mousereleased(_, _, button, isTouch)
	if isTouch then return false end

	local actionName = self.mouseButtons[button]
	if not actionName then return false end

	self.actionValues[actionName] = 0
	self.actionReleased[actionName] = true
	return self.sinkHandledInput
end

function GameContext:gamepadaxis(joystick, axis, value)
	-- We check the + and - directions on this axis for actions if they exist:
	-- * The correct direction gets set to abs(value)
	-- * The opposite direction gets set to 0

	local thisDir, oppositeDir = "", ""

	if value > 0 then
		thisDir, oppositeDir =
			("%s+"):format(axis),
			("%s-"):format(axis)
	else
		thisDir, oppositeDir =
			("%s-"):format(axis),
			("%s+"):format(axis)
	end

	value = abs(value)
	if value <= self.deadzone then
		value = 0
	end

	local handled = false
	for i = 1, 2 do
		local currDir = (i == 1 and thisDir) or oppositeDir
		local currActionName = self.gamepadAxes[currDir]
		if currActionName then
			-- The action for this direction exists
			if i == 1 then
				-- Correct direction (considered handled)
				self:setValue(currActionName, value)
				handled = true
			else
				-- Opposite direction; gets set to 0
				self:setValue(currActionName, 0)
			end
		end
	end

	return handled and self.sinkHandledInput
end

function GameContext:gamepadpressed(joystick, button)
	local actionName = self.gamepadButtons[button]
	if not actionName then return false end

	self.actionValues[actionName] = 1
	self.actionPressed[actionName] = true
	return self.sinkHandledInput
end

function GameContext:gamepadreleased(joystick, button)
	local actionName = self.gamepadButtons[button]
	if not actionName then return false end

	self.actionValues[actionName] = 0
	self.actionReleased[actionName] = true
	return self.sinkHandledInput
end

function GameContext:postUpdate()
	-- Clear the actionPressed and actionReleased tables
	tclear(self.actionPressed)
	tclear(self.actionReleased)
end

function GameContext:popped()
	-- Set all actions to 0 when popped
	if self.releaseWhenPopped then
		for actionName, v in pairs(self.actionValues) do
			if v ~= 0 then
				self:setValue(actionName, v)
			end
		end
	end
end

GameContext.HANDLERS = {
	keypressed = true,
	keyreleased = true,

	-- mousemoved = true,
	mousepressed = true,
	mousereleased = true,
	-- wheelmoved = true,

	-- It's a good idea to rely on the gamepad helpers instead of joysticks directly
	gamepadaxis = true,
	gamepadpressed = true,
	gamepadreleased = true,
	-- joystickadded = true,
	-- joystickremoved = true,

	postUpdate = true,

	pushed = true,
	popped = true,
}

return GameContext
