-- ============================================================
-- 911 Call Plugin - Dispatch Logic
-- Handles Style A (Operator->Dispatcher) and Style B (Unified)
-- Uses callback-based AI calls for proper FiveM async handling
-- ============================================================

--- Process report using Style A: Operator then Dispatcher
function ProcessStyleA(source, message, coords, emergencyType)
    local session = GetSession(source)
    if not session then return end

    local playerName = session.playerName
    local locationStr = CoordsToString(coords)

    -- Step 1: Operator prompt
    local operatorSystem = [[You are a professional 911 emergency operator. Analyze the caller's emergency report carefully.
Extract the most detailed location information possible from what the caller describes AND their GPS coordinates.
Respond with VALID JSON only, no markdown formatting, no code blocks. Use these exact field names:
{
    "extractedLocation": "Detailed location from caller description and GPS",
    "summary": "Brief summary of the emergency situation",
    "severity": "LOW|MEDIUM|HIGH|CRITICAL",
    "peopleInvolved": "Description of people involved",
    "callerDescription": "Brief description of the caller's situation"
}]]

    local operatorPrompt = string.format(
        "Caller: %s\nLocation (GPS): %s\nEmergency Type: %s\nCaller Report: %s",
        playerName, locationStr, GetEmergencyDisplayName(emergencyType), message
    )

    DebugLog('Operator AI call...')

    CallAI(operatorPrompt, operatorSystem, function(operatorResponse)
        if not operatorResponse then
            SendFailureResponse(source, 'AI operator failed to respond.')
            return
        end

        local operatorData = ParseAIResponse(operatorResponse)
        if not operatorData then
            SendFailureResponse(source, 'Failed to parse operator response.')
            return
        end

        -- Step 2: Dispatcher prompt
        local dispatcherSystem = [[You are a professional 911 dispatcher. Based on the operator's summary, analyze the case and assign appropriate dispatch codes.
Respond with VALID JSON only, no markdown formatting, no code blocks. Use these exact field names:
{
    "dispatchCodes": "UCR/NIBRS dispatch codes (e.g., 12-A, 10-Code)",
    "priority": "LOW|MEDIUM|HIGH|CRITICAL",
    "unitsNeeded": "List of units to dispatch (e.g., Police, Fire, EMS)",
    "estimatedResponse": "Estimated response time in minutes",
    "additionalNotes": "Any additional dispatcher notes"
}]]

        local dispatcherPrompt = string.format(
            "Operator Summary: %s\nEmergency Type: %s\nSeverity: %s\nLocation: %s\nPeople Involved: %s",
            operatorData.summary or 'N/A', emergencyType, operatorData.severity or 'N/A',
            operatorData.extractedLocation or 'N/A', operatorData.peopleInvolved or 'N/A'
        )

        DebugLog('Dispatcher AI call...')

        CallAI(dispatcherPrompt, dispatcherSystem, function(dispatcherResponse)
            if not dispatcherResponse then
                SendFailureResponse(source, 'AI dispatcher failed to respond.')
                return
            end

            local dispatcherData = ParseAIResponse(dispatcherResponse)
            if not dispatcherData then
                SendFailureResponse(source, 'Failed to parse dispatcher response.')
                return
            end

            -- Step 3: Combine into full case report
            BuildAndSendReport(source, operatorData, dispatcherData, message, playerName, emergencyType)
        end)
    end)
end

--- Process report using Style B: Unified operator + dispatcher
function ProcessStyleB(source, message, coords, emergencyType)
    local session = GetSession(source)
    if not session then return end

    local playerName = session.playerName
    local locationStr = CoordsToString(coords)

    local unifiedSystem = [[You are a combined 911 emergency operator and dispatcher. Analyze the caller's emergency report and provide a comprehensive case analysis.
Respond with VALID JSON only, no markdown formatting, no code blocks. Use these exact field names:
{
    "extractedLocation": "Detailed location from caller description and GPS",
    "summary": "Brief summary of the emergency situation",
    "severity": "LOW|MEDIUM|HIGH|CRITICAL",
    "peopleInvolved": "Description of people involved",
    "dispatchCodes": "UCR/NIBRS dispatch codes",
    "priority": "LOW|MEDIUM|HIGH|CRITICAL",
    "unitsNeeded": "List of units to dispatch",
    "estimatedResponse": "Estimated response time in minutes",
    "additionalNotes": "Any additional notes"
}]]

    local unifiedPrompt = string.format(
        "Caller: %s\nLocation (GPS): %s\nEmergency Type: %s\nCaller Report: %s",
        playerName, locationStr, GetEmergencyDisplayName(emergencyType), message
    )

    DebugLog('Unified AI call (Style B)...')

    CallAI(unifiedPrompt, unifiedSystem, function(response)
        if not response then
            SendFailureResponse(source, 'AI failed to respond.')
            return
        end

        local data = ParseAIResponse(response)
        if not data then
            SendFailureResponse(source, 'Failed to parse AI response.')
            return
        end

        BuildAndSendReport(source, data, data, message, playerName, emergencyType)
    end)
end

--- Build and send the complete case report
function BuildAndSendReport(source, operatorData, dispatcherData, message, playerName, emergencyType)
    local report = {
        caseNumber = GenerateCaseNumber(),
        emergencyType = GetEmergencyDisplayName(emergencyType),
        emergencyTypeRaw = emergencyType,
        location = operatorData.extractedLocation or 'Unknown',
        summary = operatorData.summary or 'No details available',
        severity = operatorData.severity or 'MEDIUM',
        peopleInvolved = operatorData.peopleInvolved or 'Not specified',
        callerDescription = operatorData.callerDescription or message,
        dispatchCodes = dispatcherData.dispatchCodes or 'Pending analysis',
        priority = dispatcherData.priority or operatorData.severity or 'MEDIUM',
        units = dispatcherData.unitsNeeded or 'Not assigned',
        estimatedResponse = dispatcherData.estimatedResponse or 'TBD',
        additionalNotes = dispatcherData.additionalNotes or '',
        status = 'ACTIVE',
        callerName = playerName,
        timestamp = os.date('%Y-%m-%d %H:%M:%S'),
    }

    SendCompleteReport(source, report)
end

--- Parse AI JSON response (handles markdown code blocks)
-- @param response string - Raw AI response text
-- @return table|nil - Parsed JSON data
function ParseAIResponse(response)
    if not response then return nil end

    -- Remove markdown code blocks if present
    local cleaned = response
        :gsub('^```json\n?', '')
        :gsub('\n?```$', '')
        :gsub('^```', '')
        :gsub('```$', '')
        :gsub('^`', '')
        :gsub('`$', '')
        :gsub('\r\n', '\n')

    local data = json.decode(cleaned)
    if data then
        DebugLog('AI response parsed successfully')
        return data
    end

    print('^1[911call] Failed to parse AI JSON response:^7')
    print('^3[911call] ' .. cleaned .. '^7')
    return nil
end

--- Send complete report to client
function SendCompleteReport(source, report)
    -- Get TTS audio
    local ttsText = FormatReportForTTS(report)
    DebugLog('Generating TTS audio...')

    local audioPath = GenerateSpeech(ttsText)

    -- Read audio file as base64 for reliable NUI playback
    local audioBase64 = nil
    if audioPath then
        local fullPath = GetResourcePath('binarybeaco_911call') .. '/' .. audioPath
        local file = io.open(fullPath, 'rb')
        if file then
            local data = file:read('*all')
            file:close()
            -- Encode to base64 for NUI playback
            audioBase64 = 'data:audio/mpeg;base64,' .. Base64Encode(data)
            DebugLog('Audio encoded to base64 (' .. #audioBase64 .. ' bytes)')
        end
    end

    -- Trigger TTS + display on client
    TriggerClientEvent('911call:displayReport', source, report, audioPath, audioBase64)

    DebugLog('Report sent to player ' .. source .. ': ' .. report.caseNumber)
end

--- Send failure response to client
function SendFailureResponse(source, errorMessage)
    local report = {
        caseNumber = GenerateCaseNumber(),
        emergencyType = 'Communication Error',
        location = 'Unknown',
        summary = errorMessage,
        severity = 'MEDIUM',
        peopleInvolved = 'N/A',
        dispatchCodes = 'N/A',
        priority = 'MEDIUM',
        units = 'None',
        estimatedResponse = 'TBD',
        additionalNotes = 'AI communication failed',
        status = 'FAILED',
        callerName = GetPlayerName(source),
        timestamp = os.date('%Y-%m-%d %H:%M:%S'),
    }

    TriggerClientEvent('911call:displayReport', source, report, nil, nil)
end
