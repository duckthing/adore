---@class Signal
---Signals are events that can be triggered when necessary. They are valid as long as the source `Node` is valid.
---Signal Connections are created by connecting a `Node` to a Signal, and are also only valid if the Signal's source
---`Node` and the Connection's source `Node` are valid.
---
---NOTE: If the Signal/Connection is not created under a `Node` (like an `Object`), it will not do validity checks.
---This can cause memory leaks.
---
---NOTE 2: Signals call *methods* on *objects*; they are essentially `obj.desiredMethod(obj, ...)`
local Signal = {}
Signal.CLASS_NAME = "Signal"
local SignalMT = {__index = Signal,
	---@param self Signal
	__tostring = function(self)
		-- As a Class
		if rawget(self, "CLASS_NAME") then return "Signal" end

		-- As a class instance
		return ("Signal [from %s, with %d connections]")
			:format(
			tostring(self._source),
			(self.connections and #self.connections) or 0
		)
	end
}

---@class Signal.Connection
local Connection = {}
Connection.CLASS_NAME = "Connection"
local ConnectionMT = {__index = Connection}

---@class Signal.SimpleConnection: Signal.Connection
local SConnection = {}
local SConnectionMT = {__index = SConnection}

local tremove = table.remove

---Creates a new Signal, and binds it to the Node `source`.
---All connections will get removed if `source` is destroyed.
---If the source is nil, it will not do validity checks, and can leak memory.
---@param source Node | Object | table
function Signal.new(source)
	---@class Signal
	local t = {
		_source = source,
		_sourceIsNode = (source and rawget(source, "name") and source.IS_NODE),
		_valid = true,
		---@type Signal.Connection[]?
		connections = nil,
	}
	return setmetatable(t, SignalMT)
end

---Connects a method on an Object to a Signal's `:fire()`.
---This will manage validation better with a `Node`.
---@param connectingFrom Object
---@param method string
---@param oneShot boolean? # [Default: `false`] oneShot makes the signal disconnect after firing
---@param persist boolean? # [Default: `false`] Allow saving this Connection
---@return Signal.Connection connection
function Signal:connect(connectingFrom, method, oneShot, persist)
	local connections = self.connections
	if not connections then
		-- Create the Signal.Connections array
		connections = {}
		self.connections = connections
	end

	if not connectingFrom[method] then
		-- Error if the method doesn't exist
		error(("Method '%s' does not exist on '%s' (type '%s')"):format(method, tostring(connectingFrom), connectingFrom.CLASS_NAME))
	end

	local connection = Connection.new(connectingFrom, method, oneShot or false, persist or false)
	connections[#connections+1] = connection
	return connection
end

---Connects a function to a Signal's `:fire()`; if the function returns `true`, it disconnects this.
---**Bad practice!** You won't get any of this:
---* Validation (automatic disconnections on invalid nodes)
---* Serialization (connected functions will not get saved into scenes)
---Use `:connect` instead.
---@param callable fun(...): boolean?
---@param oneShot boolean?
---@return Signal.SimpleConnection
function Signal:connectCallable(callable, oneShot)
	local connections = self.connections
	if not connections then
		-- Create the Signal.Connections array
		connections = {}
		self.connections = connections
	end

	local connection = SConnection.new(callable, oneShot or false)
	connections[#connections+1] = connection
	return connection
end

---Calls every Connection in this Signal, if they are valid.
---Calls from last to first, meaning the latest Connection made will be the earliest called. (Stack order).
---@param ... unknown
function Signal:fire(...)
	if not self:checkValidity() then return end

	local c = self.connections
	if not c then return end -- Array doesn't exist yet

	for i = #c, 1, -1 do
		local conn = c[i]
		if conn:isValid() then
			-- Valid; call it
			conn:call(...)
			if conn._oneShot then
				-- Disconnect one-shot signals
				conn:disconnect()
				tremove(c, i)
			end
		else
			-- Remove this connection
			conn:disconnect()
			tremove(c, i)
		end
	end
end

---Returns true if this Signal is valid. If it isn't, this Signal will destroy itself before returning.
---@return boolean valid
function Signal:checkValidity()
	-- * self._valid is true
	-- * If this Signal was created under a Node, the source Node is still valid
	local valid = self._valid and (not self._sourceIsNode or self._source._valid)

	if not valid then
		self:release()
	end

	return valid
end

---Disconnects any connections to this Signal.
function Signal:disconnectAll()
	local c = self.connections
	for i = #c, 1, -1 do
		c[i]:disconnect()
		c[i] = nil
	end
end

---Disconnects all connections to this Signal and invalidates the Signal.
function Signal:release()
	-- Remove everything
	local c = self.connections
	if c then
		for i = #c, 1, -1 do
			c[i]:disconnect()
			c[i] = nil
		end
	end
	self.connections = nil
	self._source = nil
	self._sourceIsNode = nil
end

---@param connectingFrom Node | Object | table
---@param method string
---@param oneShot boolean
---@param persist boolean
---@return Signal.Connection
---@private
function Connection.new(connectingFrom, method, oneShot, persist)
	-- Check if it has a "name" field; if it does, it's probably an INSTANCED Node.
	local isNode = connectingFrom.IS_NODE and rawget(connectingFrom, "name")
	---@class Signal.Connection
	local t = {
		_source = connectingFrom,
		_sourceIsNode = isNode,
		_valid = true,
		_oneShot = oneShot,
		_persist = persist,
		method = method,
	}
	return setmetatable(t, ConnectionMT)
end

---Calls the contained method
---@param ... unknown
function Connection:call(...)
	self._source[self.method](self._source, ...)
end

---Makes this Connection invalid, so that it won't be called when the parent Signal is triggered.
function Connection:disconnect()
	self._source = nil
	self._sourceIsNode = nil
	self._valid = nil
	self.method = nil
end

---Returns true if this Connection is valid
---@return boolean?
function Connection:isValid()
	return self._valid and (not self._sourceIsNode or self._source._valid)
end

---@param callable function
---@param oneShot boolean
---@return Signal.SimpleConnection
---@private
function SConnection.new(callable, oneShot)
	---@class Signal.SimpleConnection
	local t = {
		callable,
		oneShot = oneShot
	}
	return setmetatable(t, SConnectionMT)
end

function SConnection:call(...)
	local shouldDisconnect = self[1](...)
	if shouldDisconnect or self.oneShot then
		self:disconnect()
	end
end

function SConnection:disconnect()
	self[1] = nil
	self.oneShot = nil
end

function SConnection:isValid()
	return self[1] ~= nil
end

return Signal
