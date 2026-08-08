local templates = {
normal = [[
local Adore = require "$ADOREPATH"
local Nodes = Adore.Nodes
local $BASE = Nodes("$BASE")

---@class $NEW: $BASE
---@field super $BASE
---@overload fun(): $NEW
local $NEW = $BASE:extend()
$NEW.CLASS_NAME = "$NEW"

function $NEW:new()
	$BASE.new(self)
	-- Define all of your fields here
	-- Fields that rely on scene structure should be set to nil
end

function $NEW:ready()
	$BASE.ready(self)
	-- Ran when added to the tree, somewhere underneath the root
	-- Set fields that rely on scene structure here
end

function $NEW:update(dt)
	$BASE.update(self, dt)
end

function $NEW:draw()
	$BASE.draw(self)
	-- Transformations are already applied; draw in local space
end

function $NEW._addDefinition(entry)
	-- Define properties for the editor and serializer to find
	-- entry:newNumber("speed")
end

return $NEW
]],

noComments = [[
local Adore = require "$ADOREPATH"
local Nodes = Adore.Nodes
local $BASE = Nodes("$BASE")

---@class $NEW: $BASE
---@field super $BASE
---@overload fun(): $NEW
local $NEW = $BASE:extend()
$NEW.CLASS_NAME = "$NEW"

function $NEW:new()
	$BASE.new(self)
end

function $NEW:ready()
	$BASE.ready(self)
end

function $NEW:update(dt)
	$BASE.update(self, dt)
end

function $NEW:draw()
	$BASE.draw(self)
end

function $NEW._addDefinition(entry)
end

return $NEW
]],


normalPhysical2d = [[
local Adore = require "$ADOREPATH"
local Nodes = Adore.Nodes
local $BASE = Nodes("$BASE")

---@class $NEW: $BASE
---@field super $BASE
---@overload fun(): $NEW
local $NEW = $BASE:extend()
$NEW.CLASS_NAME = "$NEW"

function $NEW:new()
	$BASE.new(self)
	-- Define all of your fields here
	-- Fields that rely on scene structure should be set to nil
end

function $NEW:ready()
	$BASE.ready(self)
	-- Ran when added to the tree, somewhere underneath the root
	-- Set fields that rely on scene structure here
end

function $NEW:update(dt)
	$BASE.update(self, dt)
	-- Visual updates only
	-- Don't apply forces here!
end

function $NEW:physicsUpdate(dt)
	$BASE.update(self, dt)
	-- Apply global forces to bodies here
	-- `dt` is mostly static, depending on `Viewport.multiplyPhysicsSteps`
	-- local body = self.body
	-- body:applyForce(10, 0)
end

function $NEW:draw()
	$BASE.draw(self)
	-- Transformations are already applied; draw in local space
end

function $NEW._addDefinition(entry)
	-- Define properties for the editor and serializer to find
	-- entry:newNumber("speed")
end

return $NEW
]],
noCommentsPhysical2d = [[
local Adore = require "$ADOREPATH"
local Nodes = Adore.Nodes
local $BASE = Nodes("$BASE")

---@class $NEW: $BASE
---@field super $BASE
---@overload fun(): $NEW
local $NEW = $BASE:extend()
$NEW.CLASS_NAME = "$NEW"

function $NEW:new()
	$BASE.new(self)
end

function $NEW:ready()
	$BASE.ready(self)
end

function $NEW:update(dt)
	$BASE.update(self, dt)
end

function $NEW:physicsUpdate(dt)
	$BASE.update(self, dt)
end

function $NEW:draw()
	$BASE.draw(self)
end

function $NEW._addDefinition(entry)
end

return $NEW
]],
}

return templates
