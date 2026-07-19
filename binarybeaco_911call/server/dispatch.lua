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
    local operatorSystem = [[你是一个专业的911紧急接线员。仔细分析呼叫者的紧急情况报告。
从呼叫者描述和GPS坐标中提取尽可能详细的地点信息。
只回复有效的JSON格式，不要使用markdown格式，不要用代码块。使用以下字段名：
{
    "extractedLocation": "从呼叫者描述和GPS提取的详细地点",
    "summary": "紧急情况的简要摘要",
    "severity": "低|中|高|危急",
    "peopleInvolved": "涉及人员描述",
    "callerDescription": "呼叫者情况简述"
}]]

    local operatorPrompt = string.format(
        "呼叫者: %s\n位置(GPS): %s\n紧急类型: %s\n呼叫者报告: %s",
        playerName, locationStr, GetEmergencyDisplayName(emergencyType), message
    )

    DebugLog('接线员AI调用...')

    CallAI(operatorPrompt, operatorSystem, function(operatorResponse)
        if not operatorResponse then
            SendFailureResponse(source, '接线员AI未能响应。')
            return
        end

        local operatorData = ParseAIResponse(operatorResponse)
        if not operatorData then
            SendFailureResponse(source, '无法解析接线员回复。')
            return
        end

        -- 第二步：调度员提示词
        local dispatcherSystem = [[你是一个专业的911调度员。根据接线员的摘要，分析案件并分配相应的调度代码。
只回复有效的JSON格式，不要使用markdown格式，不要用代码块。使用以下字段名：
{
    "dispatchCodes": "UCR/NIBRS调度代码（例如: 12-A, 10-Code）",
    "priority": "低|中|高|危急",
    "unitsNeeded": "需要出动的单位（例如: 警察, 消防, 救护车）",
    "estimatedResponse": "预计响应时间（分钟）",
    "additionalNotes": "任何额外的调度员备注"
}]]

        local dispatcherPrompt = string.format(
            "接线员摘要: %s\n紧急类型: %s\n严重程度: %s\n地点: %s\n涉及人员: %s",
            operatorData.summary or '无', emergencyType, operatorData.severity or '无',
            operatorData.extractedLocation or '无', operatorData.peopleInvolved or '无'
        )

        DebugLog('调度员AI调用...')

        CallAI(dispatcherPrompt, dispatcherSystem, function(dispatcherResponse)
            if not dispatcherResponse then
                SendFailureResponse(source, '调度员AI未能响应。')
                return
            end

            local dispatcherData = ParseAIResponse(dispatcherResponse)
            if not dispatcherData then
                SendFailureResponse(source, '无法解析调度员回复。')
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

    local unifiedSystem = [[你是一个统一的911紧急接线员兼调度员。分析呼叫者的紧急报告并提供全面的案件分析。
只回复有效的JSON格式，不要使用markdown格式，不要用代码块。使用以下字段名：
{
    "extractedLocation": "从呼叫者描述和GPS提取的详细地点",
    "summary": "紧急情况的简要摘要",
    "severity": "低|中|高|危急",
    "peopleInvolved": "涉及人员描述",
    "dispatchCodes": "UCR/NIBRS调度代码",
    "priority": "低|中|高|危急",
    "unitsNeeded": "需要出动的单位",
    "estimatedResponse": "预计响应时间（分钟）",
    "additionalNotes": "任何额外备注"
}]]

    local unifiedPrompt = string.format(
        "呼叫者: %s\n位置(GPS): %s\n紧急类型: %s\n呼叫者报告: %s",
        playerName, locationStr, GetEmergencyDisplayName(emergencyType), message
    )

    DebugLog('统一AI调用（风格B）...')

    CallAI(unifiedPrompt, unifiedSystem, function(response)
        if not response then
            SendFailureResponse(source, 'AI未能响应。')
            return
        end

        local data = ParseAIResponse(response)
        if not data then
            SendFailureResponse(source, '无法解析AI回复。')
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
        location = operatorData.extractedLocation or '未知',
        summary = operatorData.summary or '无详细信息',
        severity = operatorData.severity or '中',
        peopleInvolved = operatorData.peopleInvolved or '未说明',
        callerDescription = operatorData.callerDescription or message,
        dispatchCodes = dispatcherData.dispatchCodes or '待分析',
        priority = dispatcherData.priority or operatorData.severity or '中',
        units = dispatcherData.unitsNeeded or '未分配',
        estimatedResponse = dispatcherData.estimatedResponse or '待定',
        additionalNotes = dispatcherData.additionalNotes or '',
        status = '活跃',
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
        DebugLog('AI响应解析成功')
        return data
    end

    print('^1[911呼叫] 无法解析AI JSON响应:^7')
    print('^3[911呼叫] ' .. cleaned .. '^7')
    return nil
end

--- 发送完整报告到客户端
function SendCompleteReport(source, report)
    -- 生成TTS文本（英文播报）
    local ttsText = FormatReportForTTS(report)
    DebugLog('正在生成语音广播...')

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
            DebugLog('音频已编码为Base64 (' .. #audioBase64 .. ' 字节)')
        end
    end

    -- 触发客户端显示报告和播放音频
    TriggerClientEvent('911call:displayReport', source, report, audioPath, audioBase64)

    DebugLog('报告已发送至玩家 ' .. source .. ': ' .. report.caseNumber)
end

--- 发送失败响应到客户端
function SendFailureResponse(source, errorMessage)
    local report = {
        caseNumber = GenerateCaseNumber(),
        emergencyType = '通信错误',
        location = '未知',
        summary = errorMessage,
        severity = '中',
        peopleInvolved = '无',
        dispatchCodes = '无',
        priority = '中',
        units = '无',
        estimatedResponse = '待定',
        additionalNotes = 'AI通信失败',
        status = '失败',
        callerName = GetPlayerName(source),
        timestamp = os.date('%Y-%m-%d %H:%M:%S'),
    }

    TriggerClientEvent('911call:displayReport', source, report, nil, nil)
end
