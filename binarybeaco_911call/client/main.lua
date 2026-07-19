-- ============================================================
-- 911 Call Plugin - Client Main
-- Client commands and event handlers
-- ============================================================

-- Import shared config
SharedConfig = SharedConfig or {}
SharedConfig.DispatchStyle = SharedConfig.DispatchStyle or 'A'
SharedConfig.WaitTime = SharedConfig.WaitTime or 2000
SharedConfig.ChatSettings = SharedConfig.ChatSettings or {
    OperatorPrefix = '[OPERATOR]',
    DispatcherPrefix = '[DISPATCHER]',
    SystemPrefix = '[911 SYSTEM]',
    CaseReportPrefix = '[CASE REPORT]',
}

--- Handle the start flow event from server
RegisterNetEvent('911call:startFlow', function(waitTime)
    local delay = waitTime or SharedConfig.WaitTime

    -- Show system message immediately
    TriggerEvent('chat:addMessage', {
        color = {255, 255, 255},
        args = {SharedConfig.ChatSettings.SystemPrefix, 'Connecting to 911 center...'},
    })

    -- Wait, then show the emergency prompt
    SetTimeout(delay, function()
        TriggerEvent('chat:addMessage', {
            color = {0, 150, 255},
            args = {'911 CENTER', 'What is your emergency? Please describe the situation and location.'},
        })

        -- Show NUI hint
        TriggerEvent('911call:showHint', 'Type /911say <your emergency description>')
    end)
end)

--- Handle displaying the case report
RegisterNetEvent('911call:displayReport', function(report, audioPath, audioBase64)
    if not report then return end

    -- Display report in chat
    local displayText = FormatReportDisplay(report)
    TriggerEvent('chat:addMessage', {
        color = {255, 255, 255},
        args = {'SYSTEM', displayText},
    })

    -- Also send to NUI for enhanced display
    TriggerEvent('911call:showReport', report)

    -- Play TTS audio if available
    if audioPath and audioPath ~= '' then
        TriggerEvent('911call:playTTSAudio', audioPath, audioBase64)
    else
        -- Fallback: inform user audio unavailable
        TriggerEvent('chat:addMessage', {
            color = {255, 200, 0},
            args = {SharedConfig.ChatSettings.SystemPrefix, 'Audio broadcast unavailable. Please check server TTS configuration.'},
        })
    end
end)

--- Show a temporary hint on screen
RegisterNetEvent('911call:showHint', function(text)
    SendNUIMessage({
        action = 'showHint',
        text = text,
    })

    -- Auto-hide after 5 seconds
    SetTimeout(5000, function()
        SendNUIMessage({
            action = 'hideHint',
        })
    end)
end)

--- Show report on NUI
RegisterNetEvent('911call:showReport', function(report)
    SendNUIMessage({
        action = 'showReport',
        report = report,
    })
end)

--- Play TTS audio
RegisterNetEvent('911call:playTTSAudio', function(audioPath, audioBase64)
    SendNUIMessage({
        action = 'playAudio',
        audioPath = audioPath,
        audioBase64 = audioBase64,
    })
end)

--- Register client-side commands (for direct use)
RegisterCommand('911call', function()
    ExecuteCommand('911call')
end, false)

RegisterCommand('911say', function()
    ExecuteCommand('911say')
end, false)

--- Format report for client display (shared function)
function FormatReportDisplay(report)
    if not report then return '' end

    local lines = {}
    lines[#lines + 1] = string.format('%s %s', SharedConfig.ChatSettings.CaseReportPrefix, report.caseNumber or 'N/A')
    lines[#lines + 1] = string.format('  Type: %s', report.emergencyType or 'Unknown')
    lines[#lines + 1] = string.format('  Location: %s', report.location or 'Unknown')
    lines[#lines + 1] = string.format('  Summary: %s', report.summary or 'No details')
    lines[#lines + 1] = string.format('  Severity: %s', report.severity or 'MEDIUM')
    lines[#lines + 1] = string.format('  Priority: %s', report.priority or 'MEDIUM')
    lines[#lines + 1] = string.format('  Units: %s', report.units or 'None')
    lines[#lines + 1] = string.format('  Dispatch Codes: %s', report.dispatchCodes or 'Pending')
    lines[#lines + 1] = string.format('  Status: %s', report.status or 'ACTIVE')

    return table.concat(lines, '\n')
end
