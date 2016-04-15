require("ts3init")
require("ts3defs")
require("ts3errors")

local MODULE_NAME = "AutoCreateChannel"
local MODULE_ID = "autocreatechannel"

local serverChannels = {}

local function logMsg(msg)
	msg = "[" .. MODULE_NAME .. "] " .. msg
	print(msg)
	ts3.printMessageToCurrentTab(msg)
end

local function onMenuItemEvent(serverConnectionHandlerID, menuType, menuItemID, selectedItemID)
	
	local serverUID, error = ts3.getServerVariableAsString(serverConnectionHandlerID, ts3defs.VirtualServerProperties.VIRTUALSERVER_UNIQUE_IDENTIFIER)
	if error == ts3errors.ERROR_not_connected then
		logMsg("You are not connected to a server: " .. error)
		return
	elseif error ~= ts3errors.ERROR_ok then
		logMsg("Failed to get Server UID: " .. error)
		return
	end
	
	local clientID, error = ts3.getClientID(serverConnectionHandlerID)
	if error ~= ts3errors.ERROR_ok then
		logMsg("Failed to get Client ID: " .. error)
		return
	end
	
		local data = serverChannels[serverUID]
	
	if data == nil then
		logMsg("There is no predefined channel for this server (Server UID: <" .. serverUID .. ">). Define one in the config file.")
		return
	end

	local channelName = data["name"]
	local channelPassword = data["password"]
	local channelCodec  = data["codec"]
	local channelCodecQuality = data["codecQuality"]
	
	local parentChannelPath = {"User Channels", ""}
	local channelPath = {"User Channels", channelName, ""}
	
	if channelName == nil or channelName == "" or channelCodec == nil or channelCodecQuality == nil then
		logMsg("Your predefined channel for this server (Server UID: <" .. serverUID .. ">) is faulty. Cannot create channel.")
		return
	end
	
	local channelID, error = ts3.getChannelIDFromChannelNames(serverConnectionHandlerID, channelPath)
	if error ~= ts3errors.ERROR_ok then
		logMsg("Failed to get Channel ID: " .. error)
		return
	end

	if channelID ~= 0 then
		local error = ts3.requestClientMove(serverConnectionHandlerID, clientID, channelID, channelPassword)
		if error ~= ts3errors.ERROR_ok then
			logMsg("Failed to join channel: " .. error)
		end
		return
	end
	
	local parentChannelID, error = ts3.getChannelIDFromChannelNames(serverConnectionHandlerID, parentChannelPath)
	if error ~= ts3errors.ERROR_ok then
		logMsg("Falied to get parent Channel ID: "  .. error)
		return
	end
	
	ts3.setChannelVariableAsString(serverConnectionHandlerID, 0, ts3defs.ChannelProperties.CHANNEL_NAME, channelName)
	if channelPassword ~= nil and channelPassword ~= "" then
		ts3.setChannelVariableAsString(serverConnectionHandlerID, 0, ts3defs.ChannelProperties.CHANNEL_PASSWORD, channelPassword)
	end
	ts3.setChannelVariableAsString(serverConnectionHandlerID, 0, ts3defs.ChannelProperties.CHANNEL_CODEC, channelCodec)
	ts3.setChannelVariableAsString(serverConnectionHandlerID, 0, ts3defs.ChannelProperties.CHANNEL_CODEC_QUALITY, channelCodecQuality)
	
	local error = ts3.flushChannelCreation(serverConnectionHandlerID, parentChannelID)
	if error ~= ts3errors.ERROR_ok then
		logMsg("Failed to create channel: " .. error)
		return
	end
	
end

local function createMenus(moduleMenuItemID)
	return {
		{ ts3defs.PluginMenuType.PLUGIN_MENU_TYPE_GLOBAL,  0,  "Create predefined channel",  "" }
	}
end

local function loadServerChannels()

	local serverFileName = "plugins/lua_plugin/" .. MODULE_ID .. "/servers.txt"
	for serverUID in io.lines(serverFileName) do
		if serverUID ~= nil and serverUID ~= "" then
			serverChannels[serverUID] = {}
		end
	end
	
	for serverUID, dataTable in pairs(serverChannels) do
		local channelFileName = "plugins/lua_plugin/" .. MODULE_ID .. "/" .. serverUID .. ".txt"
		for line in io.lines(channelFileName) do
			if line ~= nil and line ~= "" then
				local i = string.find(line, "=")
				if i ~= nil then
					local key = string.sub(line, 1, i - 1)
					local value = string.sub(line, i + 1)
					if key ~= nil and key ~= "" then
						dataTable[key] = value
					end
				end
			end
		end
	end
	
end

loadServerChannels()

local registeredEvents = {
	createMenus = createMenus,
	onMenuItemEvent = onMenuItemEvent
}

ts3RegisterModule(MODULE_ID, registeredEvents)
