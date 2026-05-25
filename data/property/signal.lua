local Property = require "data.property"

---@class Property.Signal: Property
local Signal = Property:extend()
Signal.TYPE = "Signal"
Signal.IS_DEFERRED = "unique"

function Signal:new(class, property)
	Signal.super.new(self, class, property)
end

function Signal:newValue()
	return nil
end

function Signal:isValid(val)
	return type(val) == "table"
end

---@class Signal.Serialized
---@field path NodePath # Relative NodePath from the original source
---@field method string
---@field oneShot boolean?

function Signal:serialize(obj, propertyName, value)
	-- Can only save signals under Nodes; don't save
	if not obj.IS_NODE then return nil end
	---@cast obj Node

	---@type Signal
	local signal = value or obj[propertyName]

	-- Invalid Signal; don't save
	if not signal:checkValidity() then return nil end

	---@type Signal.Serialized[]
	local validConnections = {}
	local connections = signal.connections

	-- No connections; don't save
	if not connections then return nil end

	for i = 1, #connections do
		local conn = connections[i]
		if conn:isValid() and conn._persist and conn._sourceIsNode then
			validConnections[#validConnections+1] = {
				-- Source is a Node
				---@diagnostic disable-next-line: param-type-mismatch, assign-type-mismatch
				path = obj:getRelativePathToOther(conn._source),
				method = conn.method,
				oneShot = conn._oneShot,
			}
		end
	end

	-- No valid connections; don't save
	if #validConnections == 0 then return nil end

	-- Do save
	return validConnections
end

---@param connections Signal.Serialized[]?
function Signal:deserialize(obj, propertyName, connections)
	if not connections then return end

	-- Can only save Signals under Nodes; don't save
	if not obj.IS_NODE then return nil end
	---@cast obj Node

	---@type Signal
	local signal = obj[propertyName]
	for i = 1, #connections do
		local conn = connections[i]
		local node = obj:getNodeFromPath(conn.path, true)
		if node then
			signal:connect(node, conn.method, conn.oneShot, true)
		end
	end
end

---@param v Signal
---@return boolean
function Signal:isDefault(v)
	return #v.connections == 0
end

return Signal
