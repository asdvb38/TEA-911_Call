-- ============================================================
-- 911 Call Plugin - Dispatch Logic
-- Supports Style A (Operator->Dispatcher) and Style B (Unified)
-- Uses callback-based AI calls for proper FiveM async handling
-- Includes follow-up questioning when report is incomplete
-- ============================================================

--- Maximum follow-up questions before giving up
MAX_FOLLOWUPS = 3

--- Process report using Style A: Operator then Dispatcher
function ProcessStyleA(source, message, coords, emergencyType)
    local session = GetSession(source)
    if not session then return end

    local playerName = session.playerName
    local locationStr = CoordsToString(coords)

    -- Step 1: Operator analyzes and decides if more info is needed
    local operatorSystem = [[You are a professional 911 emergency operator. Analyze the caller's emergency report.
Determine if the report contains enough detail to proceed.
REQUIRED information: specific location, nature of emergency, number of people involved, weapons if any, suspect description/direction.

Respond with VALID JSON only, no markdown formatting, no code blocks. Use these exact field names:
{
    "needsClarification": true or false,
    "followUpQuestion": "Specific question to ask the caller if more info needed. Leave empty if enough info.",
    "extractedLocation": "Detailed location from caller description and GPS (or Unknown)",
    "summary": "Brief summary of the emergency situation",
    "severity": "LOW|MEDIUM|HIGH|CRITICAL",
    "peopleInvolved": "Description of people involved",
    "callerDescription": "Brief description of the caller's situation"
}

IMPORTANT:
- If the report is vague (e.g., "someone got shot", "there is a robbery"), ALWAYS ask for more details.
- Your followUpQuestion should be specific and helpful, asking for the missing information.
- Only set needsClarification to false when you have: exact location, clear emergency type, people involved, and suspect details.]]

    local operatorPrompt = string.format(
        "Caller: %s\nLocation (GPS): %s\nEmergency Type: %s\nCaller Report: %s",
        playerName, locationStr, GetEmergencyDisplayName(emergencyType), message
    )

    DebugLog('Operator AI call...')

    CallAI(operatorPrompt, operatorSystem, function(operatorResponse)
        if not operatorResponse then
            SendFollowUpQuestion(source, 'The 911 center is experiencing technical difficulties. Please try again.', session)
            return
        end

        local operatorData = ParseAIResponse(operatorResponse)
        if not operatorData then
            SendFollowUpQuestion(source, 'Unable to process your report. Please describe the emergency in more detail.', session)
            return
        end

        -- Check if more information is needed
        if operatorData.needsClarification and operatorData.followUpQuestion then
            SendFollowUpQuestion(source, operatorData.followUpQuestion, session)
            return
        end

        -- Step 2: Dispatcher prompt (only when info is sufficient)
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

            -- Build and send complete case report
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

    local unifiedSystem = [[You are a combined 911 emergency operator and dispatcher. Analyze the caller's emergency report.
Determine if the report contains enough detail to proceed.
REQUIRED information: specific location, nature of emergency, number of people involved, weapons if any, suspect description/direction.

Respond with VALID JSON only, no markdown formatting, no code blocks. Use these exact field names:
{
    "needsClarification": true or false,
    "followUpQuestion": "Specific question to ask the caller if more info needed. Leave empty if enough info.",
    "extractedLocation": "Detailed location from caller description and GPS (or Unknown)",
    "summary": "Brief summary of the emergency situation",
    "severity": "LOW|MEDIUM|HIGH|CRITICAL",
    "peopleInvolved": "Description of people involved",
    "dispatchCodes": "UCR/NIBRS dispatch codes",
    "priority": "LOW|MEDIUM|HIGH|CRITICAL",
    "unitsNeeded": "List of units to dispatch",
    "estimatedResponse": "Estimated response time in minutes",
    "additionalNotes": "Any additional notes"
}

IMPORTANT:
- If the report is vague (e.g., "someone got shot", "there is a robbery"), ALWAYS ask for more details.
- Your followUpQuestion should be specific and helpful, asking for the missing information.
- Only set needsClarification to false when you have: exact location, clear emergency type, people involved, and suspect details.]]

    local unifiedPrompt = string.format(
        "Caller: %s\nLocation (GPS): %s\nEmergency Type: %s\nCaller Report: %s",
        playerName, locationStr, GetEmergencyDisplayName(emergencyType), message
    )

    DebugLog('Unified AI call (Style B)...')

    CallAI(unifiedPrompt, unifiedSystem, function(response)
        if not response then
            SendFollowUpQuestion(source, 'The 911 center is experiencing technical difficulties. Please try again.', session)
            return
        end

        local data = ParseAIResponse(response)
        if not data then
            SendFollowUpQuestion(source, 'Unable to process your report. Please describe the emergency in more detail.', session)
            return
        end

        -- Check if more information is needed
        if data.needsClarification and data.followUpQuestion then
            SendFollowUpQuestion(source, data.followUpQuestion, session)
            return
        end

        -- Info is sufficient, build report
        BuildAndSendReport(source, data, data, message, playerName, emergencyType)
    end)
end

--- Send a follow-up question to the player via chat
function SendFollowUpQuestion(source, question, session)
    if not session then return end

    -- Increment follow-up counter
    local followUps = (session.followUpCount or 0) + 1
    UpdateSession(source, 'followUpCount', followUps)

    -- Check if max questions reached
    if followUps > MAX_FOLLOWUPS then
        -- Too many follow-ups, just generate a basic report with available info
        DebugLog('Max follow-ups reached for player ' .. source .. ', generating basic report')
        local basicData = {
            extractedLocation = session.locationStr or 'Unknown',
            summary = session.message or 'Insufficient details provided',
            severity = 'MEDIUM',
            peopleInvolved = 'Not specified',
            callerDescription = session.message or 'No additional details',
        }
        local basicDispatcher = {
            dispatchCodes = 'Pending analysis',
            priority = 'MEDIUM',
            unitsNeeded = 'Not assigned',
            estimatedResponse = 'TBD',
            additionalNotes = 'Insufficient information for detailed analysis after ' .. MAX_FOLLOWUPS .. ' follow-up attempts',
        }
        BuildAndSendReport(source, basicData, basicDispatcher, session.message, session.playerName, session.emergencyType or 'unknown')
        return
    end

    -- Send question to player via chat
    TriggerClientEvent('911call:askQuestion', source, question)

    DebugLog('Follow-up question ' .. followUps .. '/' .. MAX_FOLLOWUPS .. ' sent to player ' .. source)
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
-- @param response string - AI raw response text
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
    -- Generate TTS text (English broadcast)
    local ttsText = FormatReportForTTS(report)
    DebugLog('Generating TTS audio...')

    local audioPath = GenerateSpeech(ttsText)

    -- Read audio file and encode as base64 for NUI playback
    local audioBase64 = nil
    if audioPath then
        local fullPath = GetResourcePath('binarybeaco_911call') .. '/' .. audioPath
        local file = io.open(fullPath, 'rb')
        if file then
            local data = file:read('*all')
            file:close()
            audioBase64 = 'data:audio/wav;base64,' .. Base64Encode(data)
            DebugLog('Audio encoded to Base64 (' .. #audioBase64 .. ' bytes)')
        end
    end

    -- Trigger client to display report and play audio
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

--- Process follow-up response (Style A): Operator re-evaluates combined info
function ProcessStyleAFollowUp(source, combinedMessage, coords, emergencyType, playerName, locationStr)
    local operatorSystem = [[You are a professional 911 emergency operator. The caller has provided additional information after your follow-up question.
Evaluate the COMBINED information from all their messages.
Determine if the report now contains enough detail to proceed.

Respond with VALID JSON only, no markdown formatting, no code blocks. Use these exact field names:
{
    "needsClarification": true or false,
    "followUpQuestion": "Specific question if more info needed. Leave empty if enough info.",
    "extractedLocation": "Detailed location from combined reports",
    "summary": "Brief summary combining all information",
    "severity": "LOW|MEDIUM|HIGH|CRITICAL",
    "peopleInvolved": "Description of people involved",
    "callerDescription": "Full description from combined reports"
}

IMPORTANT:
- Evaluate ALL messages together, not just the latest one.
- If the combined info is sufficient, set needsClarification to false.
- If still missing key details, ask a SPECIFIC follow-up question.]]

    local operatorPrompt = string.format(
        "Caller: %s\nLocation (GPS): %s\nEmergency Type: %s\nCombined Reports: %s",
        playerName, locationStr, GetEmergencyDisplayName(emergencyType), combinedMessage
    )

    DebugLog('Operator follow-up AI call...')

    CallAI(operatorPrompt, operatorSystem, function(operatorResponse)
        if not operatorResponse then
            SendFollowUpQuestion(source, 'Unable to process your response. Please try again.', GetSession(source))
            return
        end

        local operatorData = ParseAIResponse(operatorResponse)
        if not operatorData then
            SendFollowUpQuestion(source, 'Unable to process your response. Please try again.', GetSession(source))
            return
        end

        -- Check if more info is still needed
        if operatorData.needsClarification and operatorData.followUpQuestion then
            SendFollowUpQuestion(source, operatorData.followUpQuestion, GetSession(source))
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

        DebugLog('Dispatcher follow-up AI call...')

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

            BuildAndSendReport(source, operatorData, dispatcherData, combinedMessage, playerName, emergencyType)
        end)
    end)
end

--- Process follow-up response (Style B): Unified AI re-evaluates combined info
function ProcessStyleBFollowUp(source, combinedMessage, coords, emergencyType, playerName, locationStr)
    local unifiedSystem = [[You are a combined 911 emergency operator and dispatcher. The caller has provided additional information after your follow-up question.
Evaluate the COMBINED information from all their messages.
Determine if the report now contains enough detail to proceed.

Respond with VALID JSON only, no markdown formatting, no code blocks. Use these exact field names:
{
    "needsClarification": true or false,
    "followUpQuestion": "Specific question if more info needed. Leave empty if enough info.",
    "extractedLocation": "Detailed location from combined reports",
    "summary": "Brief summary combining all information",
    "severity": "LOW|MEDIUM|HIGH|CRITICAL",
    "peopleInvolved": "Description of people involved",
    "dispatchCodes": "UCR/NIBRS dispatch codes",
    "priority": "LOW|MEDIUM|HIGH|CRITICAL",
    "unitsNeeded": "List of units to dispatch",
    "estimatedResponse": "Estimated response time in minutes",
    "additionalNotes": "Any additional notes"
}

IMPORTANT:
- Evaluate ALL messages together, not just the latest one.
- If the combined info is sufficient, set needsClarification to false.
- If still missing key details, ask a SPECIFIC follow-up question.]]

    local unifiedPrompt = string.format(
        "Caller: %s\nLocation (GPS): %s\nEmergency Type: %s\nCombined Reports: %s",
        playerName, locationStr, GetEmergencyDisplayName(emergencyType), combinedMessage
    )

    DebugLog('Unified follow-up AI call (Style B)...')

    CallAI(unifiedPrompt, unifiedSystem, function(response)
        if not response then
            SendFollowUpQuestion(source, 'Unable to process your response. Please try again.', GetSession(source))
            return
        end

        local data = ParseAIResponse(response)
        if not data then
            SendFollowUpQuestion(source, 'Unable to process your response. Please try again.', GetSession(source))
            return
        end

        -- Check if more info is still needed
        if data.needsClarification and data.followUpQuestion then
            SendFollowUpQuestion(source, data.followUpQuestion, GetSession(source))
            return
        end

        -- Info is sufficient, build report
        BuildAndSendReport(source, data, data, combinedMessage, playerName, emergencyType)
    end)
end
