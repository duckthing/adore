local Property = require "property"

---@class Property.NodeRef: Property
local NodeRef = Property:extend()
NodeRef.TYPE = "NodeRef"
NodeRef.IS_DEFERRED = "unique"

---@param class Node
---@param propertyName string
---@param baseClass string | Node | nil
---@param setter string?
function NodeRef:new(class, propertyName, baseClass, setter)
	NodeRef.super.new(self, class, propertyName)

	-- Convert the class object into its name, in case of passing the wrong parameter
	if type(baseClass) == "table" then baseClass = baseClass.CLASS_NAME end
	---@cast baseClass string?

	---@type string # The expected class name
	self.baseClass = baseClass or "Node"

	if setter then self:withSetter(setter) end
end

function NodeRef:newValue()
	return nil
end

---@param obj Object
---@param propertyName string
---@param node Node?
---@return NodePath?
function NodeRef:serialize(obj, propertyName, node)
	-- Can only save NodeRefs under Nodes; don't serialize
	---@cast obj Node
	if not (obj.IS_NODE and obj._valid) then return nil end

	-- Invalid/destroyed Node or wrong class; don't save
	if not (node and node.IS_NODE and node._valid and Property.ClassDB.doesClassInherit(self.baseClass, node.CLASS_NAME)) then
		return nil
	end

	return obj:getRelativePathToOther(node)
end

function NodeRef:deserialize(obj, propertyName, nodePath)
	-- Can only save NodeRefs under Nodes; don't deserialize
	---@cast obj Node
	if not (obj.IS_NODE and obj._valid) then return nil end

	local foundNode, err = obj:getNodeFromPath(nodePath, true, false)
	if foundNode and Property.ClassDB.doesClassInherit(self.baseClass, foundNode.CLASS_NAME) then
		self:set(obj, propertyName, nodePath)
	end
end

return NodeRef
