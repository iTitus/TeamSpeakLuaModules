require("ts3init")
require("ts3defs")
require("ts3errors")

local MODULE_NAME = "autocreatejoinchannel"

function tableReverse(t)
  local revT = {}
  for k, v in pairs(t) do
    revT[v] = k
  end
  return revT
end

function sortedPairsByKeys(t, comp)
  local sortedKeys = {}
  for k, _ in pairs(t) do
    table.insert(sortedKeys, k)
  end
  table.sort(sortedKeys, comp)
  local i = 0
  local iter = function ()
    i = i + 1
    if sortedKeys[i] == nil then
      return nil
    else
      return sortedKeys[i], t[sortedKeys[i]]
    end
  end
  return iter
end

function sortedPairsByValues(t, comp)
  return sortedPairsByKeys(t, function(a, b)
    if comp ~= nil then
      return comp(t[a], t[b])
    else
      return t[a] < t[b]
    end
  end)
end

local ts3errorsReverse = tableReverse(ts3errors)
local serverChannels = {}

local function logMsg(msg)
  msg = "[" .. MODULE_NAME .. "] " .. tostring(msg)
  print(msg)
  ts3.printMessageToCurrentTab(msg)
end

logMsg("Loading " .. MODULE_NAME .. "...")

-- Run with "/lua run autocreatejoinchannel.logDefs"
local function logDefs(serverConnectionHandlerID)
  logMsg("Defs:")
  for name, category in sortedPairsByKeys(ts3defs) do
    for def, id in sortedPairsByValues(category) do
      logMsg(name .. "." .. def .. " = " .. id)
    end
  end
  
  logMsg(string.rep("#", 64))
  logMsg("Errors:")
  for error, id in sortedPairsByValues(ts3errors) do
    logMsg(error .. " = " .. id)
  end
end

-- Run with "/lua run autocreatejoinchannel.createOrJoinChannel"
local function createOrJoinChannel(serverConnectionHandlerID)
  local serverUID, error = ts3.getServerVariableAsString(serverConnectionHandlerID, ts3defs.VirtualServerProperties.VIRTUALSERVER_UNIQUE_IDENTIFIER)
  if error == ts3errors.ERROR_not_connected then
    logMsg("You are not connected to a Server: " .. ts3errorsReverse[error])
    return
  elseif error ~= ts3errors.ERROR_ok then
    logMsg("Failed to get Server UID: " .. ts3errorsReverse[error])
    return
  end
  
  local clientID, error = ts3.getClientID(serverConnectionHandlerID)
  if error ~= ts3errors.ERROR_ok then
    logMsg("Failed to get Client ID: " .. ts3errorsReverse[error])
    return
  end
  
  local data = serverChannels[serverUID]
  
  if data == nil then
    logMsg("There is no predefined Channel for this Server (Server UID: " .. serverUID .. "). Define one in the config file.")
    return
  end

  local channelName = data.name
  local channelPassword = data.password
  local channelTopic = data.topic
  local channelCodec = data.codec
  local channelCodecQuality = data.codecQuality
  local channelAutoJoin = data.autoJoin
  local channelAutoCreate = data.autoCreate
  
  local parentChannelPath = {"User Channels", ""}
  
  if channelAutoJoin == "0" and channelAutoCreate == "0" then
    logMsg("Your predefined Channel for this Server (Server UID: " .. serverUID .. ") is faulty: Auto joining and creating are both disabled. Cannot create or join Channel.")
    return
  end
  
  local joinMatchProperty = data.joinMatchProperty
  local joinMatchChannelProperty
  if channelAutoJoin == "1" then
    local error = false, req
    if joinMatchProperty == "name" then
      if channelName ~= nil and channelName ~= "" then
        joinMatchChannelProperty = ts3defs.ChannelProperties.CHANNEL_NAME
      else
        error = true
        req = joinMatchProperty
      end
    elseif joinMatchProperty == "topic" then
      if channelTopic ~= nil then
        joinMatchChannelProperty = ts3defs.ChannelProperties.CHANNEL_TOPIC
      else
        error = true
        req = joinMatchProperty
      end
    else
      error = true
    end
    
    if error then
      local msg = "Your predefined Channel for this Server (Server UID: " .. serverUID .. ") is faulty: Missing/Invalid required field"
      if req then
        msg = msg .. "s 'joinMatchProperty', '" .. req .. "'"
      else
        msg = msg .. " 'joinMatchProperty'"
      end
      logMsg(msg .. " for auto joining. Cannot create or join Channel.")
      return
    end
  end
  
  if channelAutoCreate == "1" and (channelName == nil or channelName == "" or channelCodec == nil or channelCodecQuality == nil) then
    logMsg("Your predefined Channel for this Server (Server UID: " .. serverUID .. ") is faulty: Missing/Invalid required field 'name', 'codec', 'quality' for auto joining. Cannot create or join Channel.")
    return
  end
  
  -- Try to find and join the channel
  
  if channelAutoJoin == "1" then
    local channelList, error = ts3.getChannelList(serverConnectionHandlerID)
    if error ~= ts3errors.ERROR_ok then
      logMsg("Failed to get Channel-List: " .. ts3errorsReverse[error])
      return
    end
    
    local channelID = 0
    for _, id in ipairs(channelList) do
      local matchValue = ts3.getChannelVariableAsString(serverConnectionHandlerID, id, joinMatchChannelProperty)
      if matchValue == channelMatchValue then
        channelID = id
        break
      end
    end

    if channelID ~= 0 then
      local error = ts3.requestClientMove(serverConnectionHandlerID, clientID, channelID, channelPassword)
      if error ~= ts3errors.ERROR_ok then
        logMsg("Failed to join Channel: " .. ts3errorsReverse[error])
      end
      return
    end
  end
  
  -- Create the channel
  
  if channelAutoCreate == "1" then
    local parentChannelID, error = ts3.getChannelIDFromChannelNames(serverConnectionHandlerID, parentChannelPath)
    if error ~= ts3errors.ERROR_ok then
      logMsg("Failed to get parent Channel ID: "  .. ts3errorsReverse[error])
      return
    end
    
    ts3.setChannelVariableAsString(serverConnectionHandlerID, 0, ts3defs.ChannelProperties.CHANNEL_NAME, channelName)
    if channelPassword ~= nil and channelPassword ~= "" then
      ts3.setChannelVariableAsString(serverConnectionHandlerID, 0, ts3defs.ChannelProperties.CHANNEL_PASSWORD, channelPassword)
    end
    if channelTopic ~= nil and channelTopic ~= "" then
      ts3.setChannelVariableAsString(serverConnectionHandlerID, 0, ts3defs.ChannelProperties.CHANNEL_TOPIC, channelTopic)
    end
    if channelCodec ~= nil and channelCodec ~= "" then
      ts3.setChannelVariableAsString(serverConnectionHandlerID, 0, ts3defs.ChannelProperties.CHANNEL_CODEC, channelCodec)
    end
    if channelCodec ~= nil and channelCodec ~= "" then
      ts3.setChannelVariableAsString(serverConnectionHandlerID, 0, ts3defs.ChannelProperties.CHANNEL_CODEC_QUALITY, channelCodecQuality)
    end
    
    local error = ts3.flushChannelCreation(serverConnectionHandlerID, parentChannelID)
    if error ~= ts3errors.ERROR_ok then
      logMsg("Failed to create channel: " .. ts3errorsReverse[error])
      return
    end
  end

end

local function onConnectStatusChangeEvent(serverConnectionHandlerID, status, errorNumber)
  if status ~= ts3defs.ConnectStatus.STATUS_CONNECTION_ESTABLISHED then
    return
  end
  
  createOrJoinChannel(serverConnectionHandlerID)
end

local function onMenuItemEvent(serverConnectionHandlerID, menuType, menuItemID, selectedItemID)
  createOrJoinChannel(serverConnectionHandlerID)
end

local function createMenus(moduleMenuItemID)
  return {
    { ts3defs.PluginMenuType.PLUGIN_MENU_TYPE_GLOBAL,  0,  "Create or join predefined Channel",  "" }
  }
end

local function loadServerChannels()
  local serverFileName = "config/" .. MODULE_NAME .. "/servers.txt"
  logMsg("Loading Server Config from <AppPath>/" .. serverFileName)
  local file, msg, id = io.open(serverFileName)
  if file then
    for serverUID in file:lines() do
      if serverUID ~= nil and serverUID ~= "" then
        serverChannels[serverUID] = {}
      end
    end
    file:close()
  else
    logMsg("Could not load Server Config: " .. tostring(msg) .. " " .. tostring(id))
  end
  
  for serverUID, dataTable in pairs(serverChannels) do
    local channelFileName = "config/" .. MODULE_NAME .. "/" .. serverUID .. ".txt"
    logMsg("Loading Channel Config from <AppPath>/" .. channelFileName)
    local file, msg, id = io.open(channelFileName)
    if file then
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
      file:close()
    else
      logMsg("Could not load Channel Config: " .. tostring(msg))
    end
  end
end

loadServerChannels()

autocreatejoinchannel = {
  logDefs = logDefs,
  createOrJoinChannel = createOrJoinChannel
}

local registeredEvents = {
  onConnectStatusChangeEvent = onConnectStatusChangeEvent,
  createMenus = createMenus,
  onMenuItemEvent = onMenuItemEvent
}

ts3RegisterModule(MODULE_NAME, registeredEvents)
logMsg("Successfully loaded " .. MODULE_NAME)
