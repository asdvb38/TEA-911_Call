-- ============================================================
-- 911 Call Plugin - Case Report Generation
-- Additional report formatting helpers
-- ============================================================

--- Generate a formatted text report for display
-- @param report table - Case report data
-- @return string - Formatted report text
function FormatReportDisplay(report)
    if not report then return '' end

    local lines = {}
    lines[#lines + 1] = string.format('%s %s', Config.ChatSettings.CaseReportPrefix, report.caseNumber or 'N/A')
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

--- Get report as a single line for TTS (already in shared/utils.lua FormatReportForTTS)
-- This file is for additional report formatting helpers

--- Validate report data
-- @param report table
-- @return boolean
function ValidateReport(report)
    if not report then return false end
    if not report.caseNumber then return false end
    if not report.emergencyType then return false end
    if not report.location then return false end
    return true
end
