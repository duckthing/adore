local PKG_NAME = ...
local ADORE_PATH = PKG_NAME:match("^(.*)%.toolbox")
---@type AdoreInit
local Adore = require(ADORE_PATH)
local Nodes = Adore.Nodes
local Node = Nodes("Node")
local Label = Nodes("Label")
local Button = Nodes("Button")
local WindowPopup = Nodes("WindowPopup")
local VBox = Nodes("VBox")
local FormBuilder = Adore.Common("FormBuilder")

---@class Toolbox.SignalPanel: VBox
---@field super VBox
---@overload fun(toolbox: Toolbox, sceneTree: Toolbox.SceneTree): Toolbox.SignalPanel
local SignalPanel = Nodes("VBox"):extend()
SignalPanel.CLASS_NAME = "SignalPanel"

local newSignalVBox

local FontLoader = Adore.Loader.getCollection("FontLoader")
local BOLD_FONT = FontLoader:get("")
local BOLD_SIZE = 16

local function getAddr(t)
	local mt = getmetatable(t)
	setmetatable(t, nil)
	local addr = tostring(t):match("(0x.*)")
	setmetatable(t, mt)
	return addr
end

---@param toolbox Toolbox
---@param sceneTree Toolbox.SceneTree
function SignalPanel:new(toolbox, sceneTree)
	SignalPanel.super.new(self)
	self.name = "Signals"

	self.toolbox = toolbox
	self.sceneTree = sceneTree
	---@type Node? # The selected Node
	self.selected = nil
	---@type "full" | "owned" # See SceneTree.iterateMode
	self.iterateMode = "full"

	local nameLabel = Label()
	self.nameLabel = nameLabel
	nameLabel
		:setAnchors(0, 0, 1, 0)
		:setOffsets(5, 0, 0, 40)
		:setAlign("left")
		:setJustify("center")
		:setFont(BOLD_FONT)
		:setFontSize(BOLD_SIZE)

	local vbox = Nodes("VBox")()
	self.vbox = vbox
	vbox:setAnchorsAndOffsets(
		0, 0, 1, 1,
		0, 36, 0, 0
	)
		:setMargin(4)
		:setClipChildren(true)

	self:addChild(nameLabel)
	self:addChild(vbox)

	self.sceneTree.nodeFocused:connect(self, "onNodeFocusChanged")
end

---Fired when a Node is (un)focused
---@param viewer Toolbox.SceneTree
---@param node Node?
---@param inTree boolean
function SignalPanel:onNodeFocusChanged(viewer, node, inTree)
	-- Node selection is the same
	if self.selected == node then return end

	local vbox = self.vbox
	vbox:clearChildren(true)
	if type(node) == "table" and type(node.is) == "function" and node:is(Node) and node._adoreSelectable then
		-- It's a selectable Node, continue
		self.selected = node
	else
		-- Not a Node or not selectable, stop
		self.selected = nil
		self.nameLabel:setText("")
		return
	end

	-- Node exists, create the properties
	local entry = node:getClassDBEntry()
	local lastClass = nil
	self.nameLabel:setText(("%s (%s)"):format(tostring(node), getAddr(node)))

	entry:forEachProperty(node, true, function(obj, property, propertyName, fromClass, ...)
		if not (property.TYPE == "Signal" and property.visible) then return end
		if fromClass ~= lastClass then
			-- Make the new class header
			lastClass = fromClass
			local header = Label(fromClass.CLASS_NAME)
				:setJustify("center")
				:setAlign("center")
				:setAnchors(0, 0, 1, 0)
				:setOffsets(0, 0, 0, 35)
				:setFont(BOLD_FONT)
				:setFontSize(BOLD_SIZE)
			vbox:addChild(header)
		end
		---@cast property Property.Signal
		vbox:addChild(newSignalVBox(obj, property, propertyName, self))
	end)
end


---@param self Button
local function buttonCanDropData(self, posX, posY, data)
	if type(data) == "table" and data.type == "node" and data.node then
		return true
	end
end

local showConnectPopup
---@param self Button
local function buttonDropData(self, posX, posY, data)
	if type(data) == "table" and data.type == "node" and data.node then
		showConnectPopup(self, data.node)
	end
end

local function printTutorial()
	print("Drag a Node from the scene tree to this signal to connect")
end

---@param sourceNode Node
---@param property Property.Signal
---@param propertyName string
---@param signalPanel Toolbox.SignalPanel
---@return VBox
function newSignalVBox(sourceNode, property, propertyName, signalPanel)
	local vbox = VBox()
		:setAnchors(0, 0, 1, 0)
		:setResizeToContent(true)
		:setAllowScrolling(false)
	local signalButton = Button(propertyName)
		:setAnchors(0, 0, 1, 0)
		:setTextAlign("left")
	signalButton.onClick = printTutorial
	---@type Signal
	local signal = property:get(sourceNode, propertyName)
	vbox:addChild(signalButton)

	signalButton._canDropData = buttonCanDropData
	signalButton._dropData = buttonDropData
	signalButton.object, signalButton.property, signalButton.propertyName, signalButton.signal, signalButton.signalPanel =
		sourceNode, property, propertyName, signal, signalPanel

	local connections = signal.connections
	local showingAll = signalPanel.iterateMode == "full"
	if connections then
		-- Hidden connections to show later
		local nonNode = 0
		local innerScene = 0

		for i = 1, #connections do
			local connection = connections[i]
			if connection.CLASS_NAME ~= "Connection" or not connection._sourceIsNode then
				-- It's a SimpleConnection or a connection to a non-Node
				nonNode = nonNode + 1
			elseif showingAll or (connection._persist and connection._inherited) then
				-- It's a connection that can't be saved or came from instantiating a scene
				innerScene = innerScene + 1
			elseif connection:isValid() then
				-- Valid connection
				local node, method = connection._source, connection.method
				---@cast node Node
				local button = Button(("%s :: %s()"):format(tostring(sourceNode:getRelativePathToOther(node)), method))
					:setAnchors(0, 0, 1, 0)
					:setOffsets(20, 0, 0, 20)
					:setTextAlign("left")
					:setVariant("flat")
				vbox:addChild(button)

				button.clicked:connectCallable(function ()
					connection:disconnect()
					button:queueDestroy(true)
				end)
			end
		end

		-- Show a label for connections to Nodes that can't be saved
		if innerScene > 0 then
			local label = Label(("+ %d connections inside link"):format(innerScene))
				:setAnchors(0, 0, 1, 0)
				:setOffsets(20, 0, 0, 20)
				:setFontSize(11)
				:setAlbedo(1, 1, 1, 0.6)
			vbox:addChild(label)
		end

		-- Show a label for connections that don't have data we can see
		if nonNode > 0 then
			local label = Label(("+ %d non-Node connections"):format(nonNode))
				:setAnchors(0, 0, 1, 0)
				:setOffsets(20, 0, 0, 20)
				:setFontSize(11)
				:setAlbedo(1, 1, 1, 0.6)
			vbox:addChild(label)
		end
	end

	return vbox
end

---Shows a dialog to connect methods
---@param node Node
function showConnectPopup(self, node)
	---@type Object, Property.Signal, string, Signal, Toolbox.SignalPanel
	local object, property, propertyName, signal, signalPanel =
		self.object, self.property, self.propertyName, self.signal, self.signalPanel

	local window = WindowPopup()
	window._destroyOnClose = true
	window:setAnchorsAndOffsets(
		0, 1, 0, 1,
		-200, -100, 0, 100
	)
	window:getTitleLabel():setText(("Connect %s.%s to %s"):format(tostring(self.object), propertyName, tostring(node)))

	---@type Form
	local form = {
		{type = "body", text = "Method Name"},
		{id = "methodName", type = "textfield"},
		{type = "body", text = "One-shot (yes/no)"},
		{id = "oneShot", type = "textfield", value = "no"},
	}

	local vbox, sheet = FormBuilder.build(form)
	---@cast vbox VBox
	vbox:setAnchorsAndOffsets(
			0, 0, 1, 1,
			10, 10, -10, 0
		)
		:setResizeToContent(true)
		:setMargin(4)

	---@type LineEdit
	local methodNameLE = sheet:getElement("methodName")
	methodNameLE.textSubmitted:connect(window, "submit")

	-- Connect events
	window:addAction("Cancel", "close")
	window:addAction("Connect", "submit")
	window.submit = function(...)
		local methodName = methodNameLE._submittedText
		if node[methodName] then
			signal:connect(node, methodName, sheet:getValue("oneShot") == "yes", true)
			signalPanel:onNodeFocusChanged()
			signalPanel:onNodeFocusChanged(nil, object, nil)
			window:close()
		else
			print(("Method '%s' doesn't exist"):format(methodName))
		end
	end

	window:addChild(vbox)
	self:addChild(window)
	window:popup()
end

return SignalPanel
