-- ============================================================
-- 911呼叫插件 — 调度逻辑
-- 支持风格A（接线员→调度员）和风格B（统一处理）
-- 使用回调式AI调用以适配FiveM异步模型
-- ============================================================

--- 风格A处理：接线员 → 调度员 两步流程
function ProcessStyleA(source, message, coords, emergencyType)
    local session = GetSession(source)
    if not session then return end

    local playerName = session.playerName
    local locationStr = CoordsToString(coords)

    -- 第一步：接线员提示词
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

        -- 第二步：调度员提示词
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

            -- 第三步：组合完整案件报告
            BuildAndSendReport(source, operatorData, dispatcherData, message, playerName, emergencyType)
        end)
    end)
end

--- 风格B处理：统一接线员+调度员一步到位
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

--- 构建并发送完整案件报告
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

--- 解析AI返回的JSON响应（处理markdown代码块）
-- @param response string - AI原始回复文本
-- @return table|nil - 解析后的JSON数据
function ParseAIResponse(response)
    if not response then return nil end

    -- 移除markdown代码块标记
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

--- 发送完整报告到客户端
function SendCompleteReport(source, report)
    -- 生成TTS文本（英文播报）
    local ttsText = FormatReportForTTS(report)
    DebugLog('Generating TTS audio...')

    local audioPath = GenerateSpeech(ttsText)

    -- 读取音频文件并编码为base64以便NUI播放
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

    -- 触发客户端显示报告和播放音频
    TriggerClientEvent('911call:displayReport', source, report, audioPath, audioBase64)

    DebugLog('Report sent to player ' .. source .. ': ' .. report.caseNumber)
end

--- 发送失败响应到客户端
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
