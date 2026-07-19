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
    lines[#lines + 1] = string.format('%s %s', Config.ChatSettings.CaseReportPrefix, report.caseNumber or '未知')
    lines[#lines + 1] = string.format('  类型: %s', report.emergencyType or '未知')
    lines[#lines + 1] = string.format('  地点: %s', report.location or '未知')
    lines[#lines + 1] = string.format('  摘要: %s', report.summary or '无详细信息')
    lines[#lines + 1] = string.format('  严重程度: %s', report.severity or '中')
    lines[#lines + 1] = string.format('  优先级: %s', report.priority or '中')
    lines[#lines + 1] = string.format('  涉及人员: %s', report.peopleInvolved or '未说明')
    lines[#lines + 1] = string.format('  出动单位: %s', report.units or '无')
    lines[#lines + 1] = string.format('  调度代码: %s', report.dispatchCodes or '待定')
    lines[#lines + 1] = string.format('  预计响应: %s', report.estimatedResponse or '待定')
    lines[#lines + 1] = string.format('  状态: %s', report.status or '活跃')
    if report.additionalNotes and report.additionalNotes ~= '' then
        lines[#lines + 1] = string.format('  备注: %s', report.additionalNotes)
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
