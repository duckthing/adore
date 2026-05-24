---@type AdoreInit
local Adore = require ""
local Physical2d = Adore.Nodes("Physical2d")

---@class Area2d: Physical2d
---@field super Physical2d
---@overload fun(x: number?, y: number?): Area2d
local Area2d = Physical2d:extend()
Area2d.CLASS_NAME = "Area2d"
Area2d.defaultBodyType = "dynamic"

---@param x number
---@param y number
function Area2d:new(x, y)
	Area2d.super.new(self, x, y)

	---@type boolean # Whether we should ignore ancestors
	self.ignoreAncestors = false
	---@type boolean # Whether we should ignore descendents
	self.ignoreDescendents = false
	---@type boolean # Whether anything below our parent should get ignored
	self.ignoreDirectParent = false

	---@type Physical2d[] # An array of all Physical2d objects overlapping with this Area2d
	self.overlappingObjects = {}
	---@type Signal
	self.bodyEntered = self:newSignal()
	---@type Signal
	self.bodyLeft = self:newSignal()
end

function Area2d:_addShape(shape)
	local fixture = Area2d.super._addShape(self, shape)
	fixture:setSensor(true)
	return fixture
end

---@param this love.Fixture
---@param other love.Fixture
---@param otherObj any
---@param contact any
function Area2d:_checkIfContactIsValid(this, other, otherObj, contact)
	if self.ignoreDescendents and self:hasAncestor(otherObj) then
		-- We're ignoring descendents
		return false
	end

	if self.ignoreAncestors and otherObj:hasAncestor(self) then
		-- We're ignoring ancestors
		return false
	end

	if self.ignoreDirectParent and otherObj:hasAncestor(self.parent) then
		-- We're ignoring anything below our direct parent
		return false
	end

	-- All good
	return true
end

function Area2d:beginContact(this, other, contact)
	---@type Physical2d
	local otherObj = other:getBody():getUserData()
	if not otherObj then return end -- Everything should be a Physical2d

	local arr = self.overlappingObjects

	for i = 1, #arr do
		if arr[i] == otherObj then
			-- Found it, we don't need to insert it again
			return
		end
	end

	if not self:_checkIfContactIsValid(this, other, otherObj, contact) then
		return
	end

	arr[#arr+1] = otherObj
	self.bodyEntered:fire(otherObj)
end

function Area2d:endContact(this, other, contact)
	---@type Physical2d
	local otherObj = other:getBody():getUserData()
	if not otherObj then return end -- Everything should be a Physical2d

	local arr = self.overlappingObjects

	for i = 1, #arr do
		if arr[i] == otherObj then
			-- Found it, remove it from the list
			table.remove(arr, i)
			self.bodyLeft:fire(otherObj)
			return
		end
	end

	-- Ended contact with an object that was never here
end

function Area2d:forceDestroy(...)
	Area2d.super.forceDestroy(self, ...)
	self.bodyEntered:release()
	self.bodyLeft:release()

	self.bodyEntered = nil
	self.bodyLeft = nil
end

return Area2d
