-- ============================================================
-- 911 Call Plugin - Server Main
-- Command registration and call session management
-- ============================================================

local CallSessions = {}  -- Tracks active call sessions per player

--- Safely load config file
local function LoadConfig()
    local configPath = 'config/settings.lua'
    local resourcePath = GetResourcePath('binarybeaco_911call')
    local filePath = resourcePath .. '/' .. configPath
    local file = io.open(filePath, 'r')

    if file then
        local content = file:read('*all')
        file:close()

        -- Execute Lua code from config file
        local fn, err = load(content, 'settings.lua', 't')
        if fn then
            fn()
            return Config
        else
            print('^1[911call] Failed to load config: ' .. tostring(err) .. '^7')
        end
    else
        print('^1[911call] Config file not found: ' .. filePath .. '^7')
    end

    -- Return defaults if config fails to load
    return {
        APISettings = {
            URL = 'https://apihub.agnes-ai.com/v1/chat/completions',
            Model = 'agnes-2.0-flash',
            APIKey = '',
            Timeout = 30,
            MaxRetries = 1,
        },
        TTSSettings = {
            Provider = 'edge',
            AzureRegion = 'eastus',
            AzureKey = '',
            Voice = 'en-US-AriaNeural',
            EdgeVoice = 'en-US-AriaNeural',
        },
        DispatchStyle = 'B',
        WaitTime = 2000,
        Language = 'en',
        ChatSettings = {
            OperatorPrefix = '[OPERATOR]',
            DispatcherPrefix = '[DISPATCHER]',
            SystemPrefix = '[911 SYSTEM]',
            CaseReportPrefix = '[CASE REPORT]',
        },
        EnableDebug = false,
    }
end

Config = LoadConfig()

--- Log debug messages
function DebugLog(msg)
    if Config.EnableDebug then
        print('^5[911call DEBUG]^7 ' .. tostring(msg))
    end
end

--- Check if player has an active session
function HasActiveSession(source)
    return CallSessions[source] ~= nil
end

--- Create a new call session
function CreateSession(source, playerName)
    CallSessions[source] = {
        source = source,
        playerName = playerName or GetPlayerName(source),
        message = '',
        location = {},
        locationStr = '',
        timestamp = os.time(),
        status = 'initiated',
        caseNumber = nil,
        followUpCount = 0,
        emergencyType = 'unknown',
        allReports = {},  -- stores all messages for context during follow-ups
    }
    DebugLog('Session created for player ' .. source .. ': ' .. CallSessions[source].playerName)
end

--- Get current session
function GetSession(source)
    return CallSessions[source]
end

--- Update session field
function UpdateSession(source, field, value)
    if CallSessions[source] then
        CallSessions[source][field] = value
        DebugLog('Session updated: ' .. field .. ' = ' .. tostring(value))
    end
end

--- Complete and clean up session
function CompleteSession(source)
    if CallSessions[source] then
        DebugLog('Session completed for player ' .. source)
        CallSessions[source] = nil
    end
end

--- Register /911call command
RegisterCommand('911call', function(source, args, rawCommand)
    if source == 0 then return end  -- Console not allowed

    -- Check if player already has an active session
    if HasActiveSession(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            args = {'ERROR', 'You already have an active 911 call session. Use /911say to report or answer follow-up questions.'}
        })
        return
    end

    -- Create session
    CreateSession(source)
    UpdateSession(source, 'status', 'waiting')

    -- Notify client to show the 911 prompt after delay
    local waitTime = Config.WaitTime or 2000
    TriggerClientEvent('911call:startFlow', source, waitTime)

    DebugLog('/911call executed by player ' .. source)
end, false)

--- Register /911say command
RegisterCommand('911say', function(source, args, rawCommand)
    if source == 0 then return end  -- Console not allowed

    -- Check if player has an active session
    if not HasActiveSession(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            args = {'ERROR', 'Use /911call first to start a 911 report.'}
        })
        return
    end

    -- Get the message (everything after /911say)
    local message = table.concat(args, ' ')
    if message == '' or #message < 3 then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            args = {'ERROR', 'Please describe your emergency. Example: /911say I see a shooting at the gas station on 1st street.'}
        })
        return
    end

    local session = GetSession(source)

    -- Store message and append to allReports for context
    UpdateSession(source, 'message', message)
    table.insert(session.allReports, message)

    -- Check if this is a follow-up response or initial report
    if session.followUpCount and session.followUpCount > 0 then
        -- This is a follow-up response, combine with previous reports
        local combinedMessage = table.concat(session.allReports, '. ')
        UpdateSession(source, 'combinedMessage', combinedMessage)

        -- Re-analyze with combined info
        local emergencyType = ClassifyEmergency(message)  -- classify the new info
        UpdateSession(source, 'emergencyType', emergencyType)
        DebugLog('Follow-up response #' .. session.followUpCount .. ' from player ' .. source)

        -- Re-process with combined information
        ProcessReportWithFollowUp(source, message)
    else
        -- Initial report
        UpdateSession(source, 'status', 'processing')

        -- Get player location
        local ped = GetPlayerPed(source)
        local coords = GetEntityCoords(ped)
        UpdateSession(source, 'location', { x = coords.x, y = coords.y, z = coords.z })
        UpdateSession(source, 'locationStr', string.format('%.2f, %.2f, %.2f', coords.x, coords.y, coords.z))

        DebugLog('Player ' .. source .. ' reported: ' .. message)

        -- Trigger server-side AI processing
        ProcessReport(source)
    end
end, false)

--- Main report processing pipeline (initial report)
function ProcessReport(source)
    local session = GetSession(source)
    if not session then return end

    local message = session.message
    local coords = session.location
    local locationStr = session.locationStr or CoordsToString(coords)

    -- Step 1: Classify emergency type using trigger words
    local emergencyType = ClassifyEmergency(message)
    UpdateSession(source, 'emergencyType', emergencyType)
    DebugLog('Emergency type classified: ' .. emergencyType)

    -- Step 2: Dispatch based on style
    local dispatchStyle = Config.DispatchStyle or 'B'

    if dispatchStyle == 'A' then
        ProcessStyleA(source, message, coords, emergencyType)
    else
        ProcessStyleB(source, message, coords, emergencyType)
    end
end

--- Process follow-up response (AI evaluates combined info)
function ProcessReportWithFollowUp(source, newMessage)
    local session = GetSession(source)
    if not session then return end

    local playerName = session.playerName
    local coords = session.location
    local locationStr = session.locationStr or CoordsToString(coords)
    local combinedMessage = session.combinedMessage or newMessage
    local emergencyType = session.emergencyType or ClassifyEmergency(newMessage)
    UpdateSession(source, 'emergencyType', emergencyType)

    -- Re-run the operator/unified check with combined message
    local dispatchStyle = Config.DispatchStyle or 'B'

    if dispatchStyle == 'A' then
        ProcessStyleAFollowUp(source, combinedMessage, coords, emergencyType, playerName, locationStr)
    else
        ProcessStyleBFollowUp(source, combinedMessage, coords, emergencyType, playerName, locationStr)
    end
end

--- Export for external resources
exports('ProcessReport', ProcessReport)
