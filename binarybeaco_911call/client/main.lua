-- ============================================================
-- 911 Call Plugin - Client Main
-- Pure chat-based interaction, no NUI visual overlay
-- ============================================================

-- Import shared config
SharedConfig = SharedConfig or {}
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

    -- Delay, then show emergency prompt
    SetTimeout(delay, function()
        TriggerEvent('chat:addMessage', {
            color = {0, 150, 255},
            args = {'911 CENTER', 'What is your emergency? Please describe the situation and location.'},
        })
    end)
end)

--- Handle follow-up question from server (AI asking for more details)
RegisterNetEvent('911call:askQuestion', function(question)
    TriggerEvent('chat:addMessage', {
        color = {255, 200, 0},
        args = {SharedConfig.ChatSettings.OperatorPrefix, question},
    })

    -- Show hint for how to respond
    SetTimeout(1000, function()
        TriggerEvent('chat:addMessage', {
            color = {150, 150, 150},
            args = {'', '(Reply using /911say with the requested details)'},
        })
    end)
end)

--- Handle case report display
RegisterNetEvent('911call:displayReport', function(report, audioPath, audioBase64)
    if not report then return end

    -- Display full report in chat
    local displayText = FormatReportDisplay(report)
    TriggerEvent('chat:addMessage', {
        color = {255, 255, 255},
        args = {'SYSTEM', displayText},
    })

    -- Play TTS audio broadcast
    if audioPath and audioPath ~= '' then
        TriggerEvent('911call:playTTSAudio', audioPath, audioBase64)
    else
        TriggerEvent('chat:addMessage', {
            color = {255, 200, 0},
            args = {SharedConfig.ChatSettings.SystemPrefix, 'Audio broadcast unavailable. Check server TTS configuration.'},
        })
    end
end)

--- Format report for chat display
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
