local Property = require "data.property"

---@class Property.Signal: Property
local Signal = Property:extend()
Signal.TYPE = "Signal"
Signal.DEFER_MODE = "unique"

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

---Returns `true` if this connection can be serialized
---@param conn Signal.Connection
---@return boolean
local function isConnectionSerializable(conn)
	return conn:isValid() and conn._persist and conn._sourceIsNode
end

---Serializes a connection into an array
---@param arr Signal.Serialized[]
---@param conn Signal.Connection
---@param node Node # The Node this Signal comes from
local function serializeConnection(arr, conn, node)
	if isConnectionSerializable(conn) then
		arr[#arr+1] = {
			-- Source is a Node
			---@diagnostic disable-next-line: param-type-mismatch, assign-type-mismatch
			path = node:getRelativePathToOther(conn._source),
			method = conn.method,
			oneShot = conn._oneShot,
		}
	end
end

function Signal:serialize(obj, propertyName, value)
	-- Can only save signals under Nodes that are persistent; don't save
	if not (obj.IS_NODE and obj._adorePersist) then return nil end
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
		serializeConnection(validConnections, connections[i], obj)
	end

	-- No valid connections; don't save
	if #validConnections == 0 then return nil end

	-- Do save
	return validConnections
end

---@param connections Signal.Serialized[]?
function Signal:deserialize(obj, propertyName, connections)
	-- Can only save Signals under Nodes; don't save
	if not obj.IS_NODE then return nil end
	---@cast obj Node

	---@type Signal
	local signal = obj[propertyName]
	do
		-- Make any already connected signals not show up in the signal panel
		local existingConns = signal.connections
		if existingConns then
			for i = 1, #existingConns do
				existingConns[i]._inherited = true
			end
		end
	end

	if not connections then return end

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
	return v.connections and #v.connections == 0 or false
end

---@param a Signal
---@param b Signal
---@return boolean
function Signal:areEqual(a, b)
	local aConnections = a.connections
	local bConnections = b.connections
	-- Check if the tables are the same
	if aConnections == bConnections then return true end
	-- Do `:serializeDiff` to continue comparing
	return false
end

---Returns `true` if the connections are similar
---@param signalA Signal
---@param connA Signal.Connection
---@param connB Property.Signal.Comparable
---@return boolean
local function doConnectionsMatch(signalA, connA, connB)
	if
		connA.method == connB.method
		and
		connA._oneShot == connB._oneShot
		and
		signalA._source:getRelativePathToOther(connA._source)
			== connB.sourcePath
	then
		return true
	end
	return false
end

local tremove = table.remove

---Returns the connections from A minus whatever overlapped with the connections from B
---@param signalA Signal
---@param comparable Signal.Connection[]
---@return Signal.Connection[]?
local function getSubtractedConnections(signalA, comparable)
	local node = signalA._source
	---@cast node Node
	local connA = signalA.connections
	if not (connA and comparable) then return connA end

	-- Create a copy of all serializable connections
	---@type Signal.Connection[]
	local conns = {}
	for i = 1, #connA do
		local conn = connA[i]
		if isConnectionSerializable(conn) then
			conns[i] = conn
		end
	end

	-- Remove any connections from `conns` that overlap with the ones here
	for i = #comparable, 1, -1 do
		-- Get a serializable connection from B...
		local comparableConn = comparable[i]
		for j = #conns, 1, -1 do
			-- Get a serializable connection from conns...
			local toCheck = conns[j]
			if doConnectionsMatch(signalA, toCheck, comparableConn) then
				-- Found a match, remove it
				tremove(conns, j)
			end
		end
	end

	-- Now serialize them
	local serializedConnections = {}
	for i = 1, #conns do
		serializeConnection(serializedConnections, conns[i], node)
	end

	return (#serializedConnections > 0 and serializedConnections) or nil
end

---@class Property.Signal.Comparable
local SignalComparable = {}
local SignalComparableMT = {__index = SignalComparable}
SignalComparable._persist = true
SignalComparable._sourceIsNode = true
function SignalComparable:isValid() return true end

function Signal:newComparable(obj, propertyName)
	if not (obj.IS_NODE and obj._adorePersist) then return end
	---@type Signal
	local signal = self:get(obj, propertyName)
	local connections = signal.connections
	if not connections then return end

	local comparableConnections = {}
	for i = 1, #connections do
		local conn = connections[i]
		if isConnectionSerializable(conn) then
			---@class Property.Signal.Comparable
			comparableConnections[#comparableConnections+1] = setmetatable({
				sourcePath = signal._source:getRelativePathToOther(conn._source),
				_oneShot = conn._oneShot,
				method = conn.method,
			}, SignalComparableMT)
		end
	end

	return comparableConnections
end

---@param signal Signal
---@param comparable Property.Signal.Comparable[]
---@return boolean
function Signal:isComparableEqual(signal, comparable)
	local obj = signal._source
	if not (obj.IS_NODE and obj._adorePersist) then return false end
	---@cast obj Node
	local connections = signal.connections
	if not connections then return false end

	for i = #comparable, 1, -1 do
		local comparableConn = comparable[i]
		for j = #connections, 1, -1 do
			local originalConn = connections[j]
			if isConnectionSerializable(originalConn) and not doConnectionsMatch(signal, originalConn, comparableConn) then
				return false
			end
		end
	end

	return true
end

---@param obj Object
---@param propertyName string
---@param value Signal
---@param resources any[]
---@param customDefault Signal
function Signal:serializeDiff(obj, propertyName, value, resources, customDefault)
	if not (obj.IS_NODE and obj._adorePersist) then return nil end
	---@cast obj Node

	---@type Signal
	local signal = value or obj[propertyName]

	-- Invalid Signal; don't save
	if not signal:checkValidity() then return nil end

	return getSubtractedConnections(signal, customDefault)
end

return Signal
