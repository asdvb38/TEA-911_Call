-- ============================================================
-- 911呼叫插件 — 客户端主逻辑
-- 纯聊天框交互，无NUI视觉覆盖层
-- ============================================================

-- 导入共享配置
SharedConfig = SharedConfig or {}
SharedConfig.WaitTime = SharedConfig.WaitTime or 2000
SharedConfig.ChatSettings = SharedConfig.ChatSettings or {
    OperatorPrefix = '[OPERATOR]',
    DispatcherPrefix = '[DISPATCHER]',
    SystemPrefix = '[911 SYSTEM]',
    CaseReportPrefix = '[CASE REPORT]',
}

--- 处理服务端传来的开始流程事件
RegisterNetEvent('911call:startFlow', function(waitTime)
    local delay = waitTime or SharedConfig.WaitTime

    -- 立即显示系统消息
    TriggerEvent('chat:addMessage', {
        color = {255, 255, 255},
        args = {SharedConfig.ChatSettings.SystemPrefix, 'Connecting to 911 center...'},
    })

    -- 延迟后显示紧急提示
    SetTimeout(delay, function()
        TriggerEvent('chat:addMessage', {
            color = {0, 150, 255},
            args = {'911 CENTER', 'What is your emergency? Please describe the situation and location.'},
        })
    end)
end)

--- 处理案件报告显示
RegisterNetEvent('911call:displayReport', function(report, audioPath, audioBase64)
    if not report then return end

    -- 在聊天中显示完整报告
    local displayText = FormatReportDisplay(report)
    TriggerEvent('chat:addMessage', {
        color = {255, 255, 255},
        args = {'SYSTEM', displayText},
    })

    -- 播放TTS语音广播
    if audioPath and audioPath ~= '' then
        TriggerEvent('911call:playTTSAudio', audioPath, audioBase64)
    else
        TriggerEvent('chat:addMessage', {
            color = {255, 200, 0},
            args = {SharedConfig.ChatSettings.SystemPrefix, 'Audio broadcast unavailable. Check server TTS configuration.'},
        })
    end
end)

--- 格式化报告用于聊天显示
function FormatReportDisplay(report)
    if not report then return '' end

    local lines = {}
    lines[#lines + 1] = string.format('%s %s', SharedConfig.ChatSettings.CaseReportPrefix, report.caseNumber or 'N/A')
    lines[#lines + 1] = string.format('  Type: %s', report.emergencyType or 'Unknown')
    lines[#lines + 1] = string.format('  Location: %s', report.location or 'Unknown')
    lines[#lines + 1] = string.format('  Summary: %s', report.summary or 'No details')
    lines[#lines + 1] = string.format('  Severity: %s', report.severity or 'MEDIUM')
    lines[#lines + 1] = string.format('  Priority: %s', report.priority or 'MEDIUM')
    lines[#lines + 1] = string.format('  People Involved: %s', report.peopleInvolved or 'Not specified')
    lines[#lines + 1] = string.format('  Units: %s', report.units or 'None')
    lines[#lines + 1] = string.format('  Dispatch Codes: %s', report.dispatchCodes or 'Pending')
    lines[#lines + 1] = string.format('  Est. Response: %s', report.estimatedResponse or 'TBD')
    lines[#lines + 1] = string.format('  Status: %s', report.status or 'ACTIVE')

    if report.additionalNotes and report.additionalNotes ~= '' then
        lines[#lines + 1] = string.format('  Notes: %s', report.additionalNotes)
    end

    return table.concat(lines, '\n')
end
