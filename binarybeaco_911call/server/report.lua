-- ============================================================
-- 911呼叫插件 — 案件报告格式化
-- 额外的报告格式化工具函数
-- ============================================================

--- 生成用于聊天显示的格式化文本报告
-- @param report table - 案件报告数据
-- @return string - 格式化后的报告文本
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

--- 验证报告数据完整性
-- @param report table - 报告数据
-- @return boolean - 是否有效
function ValidateReport(report)
    if not report then return false end
    if not report.caseNumber then return false end
    if not report.emergencyType then return false end
    if not report.location then return false end
    return true
end
