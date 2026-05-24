---@type AdoreInit
local Adore = require ""
local Context = Adore.Resources("Context")

---A ShortcutContext handles (usually a combination of) button presses and triggers actions.
---For example, an "undo" action can be repeatedly triggered by holding down the corresponding keybind.
---This should be used for application-like behavior, not for games.
---@class ShortcutContext: Context
---@overload fun(actions: ShortcutContext.ActionMap, pressedKeybinds: ShortcutContext.Keybinds?, releasedKeybinds: ShortcutContext.Keybinds?, pressedGamepadBinds: ShortcutContext.GamepadBinds?, releasedGamepadBinds: ShortcutContext.GamepadBinds?): ShortcutContext
local ShortcutContext = Context:extend()
ShortcutContext.CLASS_NAME = "ShortcutContext"
ShortcutContext.HANDLERS = {
	-- The following are processed like normal
	keypressed = true, keyreleased = true, gamepadpressed = true, gamepadreleased = true,
	-- `textinput` is cancelled when a shortcut is triggered, though
	textinput = true, postUpdate = true,
}

---@alias ShortcutContext.Action fun(context: ShortcutContext, isRepeat: boolean?): boolean?
---@alias ShortcutContext.ActionName string
---@alias ShortcutContext.ActionMap {[ShortcutContext.ActionName]: ShortcutContext.Action}

---@class ShortcutContext.Keybinds
---@field normal {[love.Scancode]: ShortcutContext.ActionName}?
---@field alt {[love.Scancode]: ShortcutContext.ActionName}?
---@field ctrl {[love.Scancode]: ShortcutContext.ActionName}?
---@field shift {[love.Scancode]: ShortcutContext.ActionName}?
---@field altctrl {[love.Scancode]: ShortcutContext.ActionName}?
---@field altshift {[love.Scancode]: ShortcutContext.ActionName}?
---@field ctrlshift {[love.Scancode]: ShortcutContext.ActionName}?
---@field altctrlshift {[love.Scancode]: ShortcutContext.ActionName}?

---@alias ShortcutContext.GamepadBinds {[love.GamepadButton]: ShortcutContext.ActionName}?

---Returns the keyboard modifier being held down
---@return "normal" | "alt" | "ctrl" | "shift" | "altctrl" | "altshift" | "ctrlshift" | "altctrlshift"
local function getModifier()
	local alt = love.keyboard.isDown("lalt", "ralt")
	local ctrl = love.keyboard.isDown("lctrl", "lctrl")
	local shift = love.keyboard.isDown("lshift", "rshift")

	if alt then
		if ctrl then
			if shift then
				return "altctrlshift"
			end
			return "altctrl"
		elseif shift then
			return "altshift"
		end
		return "alt"
	elseif ctrl then
		if shift then
			return "ctrlshift"
		end
		return "ctrl"
	elseif shift then
		return "shift"
	end
	return "normal"
end

---@param actions ShortcutContext.ActionMap
---@param pressedKeybinds ShortcutContext.Keybinds?
---@param releasedKeybinds ShortcutContext.Keybinds?
---@param pressedGamepadBinds ShortcutContext.GamepadBinds?
---@param releasedGamepadBinds ShortcutContext.GamepadBinds?
function ShortcutContext:new(actions, pressedKeybinds, releasedKeybinds, pressedGamepadBinds, releasedGamepadBinds)
	ShortcutContext.super.new(self)

	self.actions = actions
	self.pressedKeybinds = pressedKeybinds
	self.releasedKeybinds = releasedKeybinds
	self.pressedGamepadBinds = pressedGamepadBinds
	self.releasedGamepadBinds = releasedGamepadBinds

	---@type boolean # Should OS key repeats count? Call `love.keyboard.setKeyRepeat(true)` if you want this to work with repeats.
	self.allowRepeats = true
	---@type boolean # If a keyboard shortcut is triggered, should text input be sunk? Requires `sinkHandledInput`
	self.sinkTextInput = true
	---@type boolean # Whether scancodes (layout-independent) are used (default: `false`)
	self.useScancode = false

	---@type boolean # If we processed a shortcut through a key press this update
	self._justProcessedKeyPress = false
end

---Triggers an action inside of a `ShortcutContext`
---@param actionName string
function ShortcutContext:trigger(actionName)
	local action = self.actions[actionName]
	if action then
		action(self, nil)
	else
		error(("Action '%s' is not found inside of %s"):format(actionName, tostring(self)))
	end
end

function ShortcutContext:keypressed(key, scancode, isRepeat)
	if isRepeat and not self.allowRepeats then return false end
	if not self.pressedKeybinds then return false end
	local modifier = getModifier()

	local modifierTable = self.pressedKeybinds[modifier]
	if modifierTable then
		local button = (self.useScancode and scancode) or key
		local actionName = modifierTable[button]
		if actionName then
			local action = self.actions[actionName]
			if action then
				local success = action(self, isRepeat)
				self._justProcessedKeyPress = success or false
				return success and self.sinkHandledInput
			end
		end
	end
	return false
end

function ShortcutContext:keyreleased(key, scancode)
	if not self.releasedKeybinds then return false end
	local modifier = getModifier()

	local modifierTable = self.releasedKeybinds[modifier]
	if modifierTable then
		local button = (self.useScancode and scancode) or key
		local actionName = modifierTable[button]
		if actionName then
			local action = self.actions[actionName]
			if action then
				return action(self, nil) and self.sinkHandledInput
			end
		end
	end
	return false
end

function ShortcutContext:gamepadpressed(joystick, button)
	if not self.pressedGamepadBinds then return false end

	local actionName = self.pressedGamepadBinds[button]
	if actionName then
		local action = self.actions[actionName]
		if action then
			return action(self, nil) and self.sinkHandledInput
		end
	end
	return false
end

function ShortcutContext:gamepadreleased(joystick, button)
	if not self.releasedGamepadBinds then return false end

	local actionName = self.releasedGamepadBinds[button]
	if actionName then
		local action = self.actions[actionName]
		if action then
			return action(self, nil) and self.sinkHandledInput
		end
	end
	return false
end

function ShortcutContext:textinput()
	if self._justProcessedKeyPress and self.sinkTextInput then
		-- Sink it
		return self.sinkHandledInput
	end
end

function ShortcutContext:postUpdate()
	self._justProcessedKeyPress = false
end

return ShortcutContext
