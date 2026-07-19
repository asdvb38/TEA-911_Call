-- ============================================================
-- 911呼叫插件 — 客户端主逻辑
-- 客户端命令与事件处理
-- ============================================================

-- 导入共享配置
SharedConfig = SharedConfig or {}
SharedConfig.DispatchStyle = SharedConfig.DispatchStyle or 'A'
SharedConfig.WaitTime = SharedConfig.WaitTime or 2000
SharedConfig.ChatSettings = SharedConfig.ChatSettings or {
    OperatorPrefix = '[接线员]',
    DispatcherPrefix = '[调度员]',
    SystemPrefix = '[911系统]',
    CaseReportPrefix = '[案件报告]',
}

--- 处理服务端传来的开始流程事件
RegisterNetEvent('911call:startFlow', function(waitTime)
    local delay = waitTime or SharedConfig.WaitTime

    -- 立即显示系统消息
    TriggerEvent('chat:addMessage', {
        color = {255, 255, 255},
        args = {SharedConfig.ChatSettings.SystemPrefix, '正在连接911中心...'},
    })

    -- 延迟后显示紧急提示
    SetTimeout(delay, function()
        TriggerEvent('chat:addMessage', {
            color = {0, 150, 255},
            args = {'911中心', '请描述您的紧急情况。'},
        })

        -- 显示NUI提示
        TriggerEvent('911call:showHint', '输入 /911say <描述您的紧急情况>')
    end)
end)

--- 处理案件报告显示
RegisterNetEvent('911call:displayReport', function(report, audioPath, audioBase64)
    if not report then return end

    -- 在聊天中显示报告
    local displayText = FormatReportDisplay(report)
    TriggerEvent('chat:addMessage', {
        color = {255, 255, 255},
        args = {'系统', displayText},
    })

    -- 同时发送到NUI增强显示
    TriggerEvent('911call:showReport', report)

    -- 播放TTS语音广播
    if audioPath and audioPath ~= '' then
        TriggerEvent('911call:playTTSAudio', audioPath, audioBase64)
    else
        -- 降级提示
        TriggerEvent('chat:addMessage', {
            color = {255, 200, 0},
            args = {SharedConfig.ChatSettings.SystemPrefix, '语音广播不可用。请检查服务器TTS配置。'},
        })
    end
end)

--- 显示屏幕提示
RegisterNetEvent('911call:showHint', function(text)
    SendNUIMessage({
        action = 'showHint',
        text = text,
    })

    -- 5秒后自动隐藏
    SetTimeout(5000, function()
        SendNUIMessage({
            action = 'hideHint',
        })
    end)
end)

--- 在NUI中显示报告
RegisterNetEvent('911call:showReport', function(report)
    SendNUIMessage({
        action = 'showReport',
        report = report,
    })
end)

--- 播放TTS语音
RegisterNetEvent('911call:playTTSAudio', function(audioPath, audioBase64)
    SendNUIMessage({
        action = 'playAudio',
        audioPath = audioPath,
        audioBase64 = audioBase64,
    })
end)

--- 格式化报告用于客户端聊天显示
function FormatReportDisplay(report)
    if not report then return '' end

    local lines = {}
    lines[#lines + 1] = string.format('%s %s', SharedConfig.ChatSettings.CaseReportPrefix, report.caseNumber or '未知')
    lines[#lines + 1] = string.format('  类型: %s', report.emergencyType or '未知')
    lines[#lines + 1] = string.format('  地点: %s', report.location or '未知')
    lines[#lines + 1] = string.format('  摘要: %s', report.summary or '无详细信息')
    lines[#lines + 1] = string.format('  严重程度: %s', report.severity or '中')
    lines[#lines + 1] = string.format('  优先级: %s', report.priority or '中')
    lines[#lines + 1] = string.format('  出动单位: %s', report.units or '无')
    lines[#lines + 1] = string.format('  调度代码: %s', report.dispatchCodes or '待定')
    lines[#lines + 1] = string.format('  状态: %s', report.status or '活跃')

    return table.concat(lines, '\n')
end
