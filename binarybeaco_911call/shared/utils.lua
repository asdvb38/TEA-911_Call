-- ============================================================
-- 911呼叫插件 — 共享工具函数
-- ============================================================

local TriggerWordsCache = nil

--- Load trigger words from JSON config file
function LoadTriggerWords()
    if TriggerWordsCache then return TriggerWordsCache end

    local path = 'config/triggerwords.json'
    local file = LoadResourceFile('binarybeaco_911call', path)
    if not file then
        print('^1[911call] Failed to load triggerwords.json, using defaults^7')
        return {}
    end

    TriggerWordsCache = json.decode(file)
    return TriggerWordsCache
end

--- Classify a message by matching trigger words
-- @param message string - 玩家的紧急报告内容
-- @return string - 分类后的紧急类型
function ClassifyEmergency(message)
    local words = LoadTriggerWords()
    if not words or not message then return 'unknown' end

    local lowerMsg = string.lower(message)
    local bestMatch = 'unknown'
    local bestScore = 0

    for category, keywords in pairs(words) do
        for _, keyword in ipairs(keywords) do
            if string.find(lowerMsg, string.lower(keyword)) then
                local score = #keyword  -- 关键词越长，匹配权重越高
                if score > bestScore then
                    bestScore = score
                    bestMatch = category
                end
            end
        end
    end

    return bestMatch
end

--- Get a display name for emergency type (English, consistent with TTS)
-- @param type string - 分类后的紧急类型
-- @return string - 人类可读的名称
function GetEmergencyDisplayName(type)
    local names = {
        shooting = 'Shooting Incident',
        robbery = 'Robbery',
        car_accident = 'Vehicle Accident',
        kidnapping = 'Kidnapping',
        domestic_violence = 'Domestic Violence',
        suspicious_activity = 'Suspicious Activity',
        medical_emergency = 'Medical Emergency',
        fire = 'Fire/Explosion',
        assault = 'Assault',
        hostage = 'Hostage Situation',
        unknown = 'Unclassified',
    }
    return names[type] or type
end

--- Get current player coordinates (client-side only)
-- @return table - {x, y, z} 坐标
function GetPlayerCoords()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    return { x = coords.x, y = coords.y, z = coords.z }
end

--- Convert coordinates to a readable string
-- @param coords table - {x, y, z} 坐标
-- @return string - 可读坐标字符串
function CoordsToString(coords)
    return string.format('%.2f, %.2f, %.2f', coords.x, coords.y, coords.z)
end

--- Generate a unique case number
-- @return string - 格式: 911-YYYYMMDD-XXXX
function GenerateCaseNumber()
    local date = os.date('%Y%m%d')
    local rand = math.random(1000, 9999)
    return string.format('911-%s-%s', date, rand)
end

--- Base64 encode
-- @param data string - 原始二进制数据
-- @return string - Base64 编码字符串
function Base64Encode(data)
    return b64encode(data)
end

--- Format a case report for display
-- @param report table - 原始报告数据
-- @return string - 格式化后的报告文本
function FormatCaseReport(report)
    if not report then return '' end

    local lines = {}
    lines[#lines + 1] = string.format('案件编号: %s', report.caseNumber or '未知')
    lines[#lines + 1] = string.format('类型: %s', report.emergencyType or '未知')
    lines[#lines + 1] = string.format('地点: %s', report.location or '未知')
    lines[#lines + 1] = string.format('摘要: %s', report.summary or '无详细信息')
    lines[#lines + 1] = string.format('优先级: %s', report.priority or '未分配')
    lines[#lines + 1] = string.format('出动单位: %s', report.units or '无')
    lines[#lines + 1] = string.format('状态: %s', report.status or '活跃')
    lines[#lines + 1] = string.format('调度代码: %s', report.dispatchCodes or '待定')

    return table.concat(lines, '\n')
end

--- Format report as plain text for TTS broadcast (English)
-- @param report table - 原始报告数据
-- @return string - 用于语音合成的纯文本
function FormatReportForTTS(report)
    if not report then return '' end

    local parts = {}
    parts[#parts + 1] = string.format('Case number %s.', report.caseNumber or 'unknown')
    parts[#parts + 1] = string.format('Emergency type: %s.', report.emergencyType or 'unknown')
    parts[#parts + 1] = string.format('Location: %s.', report.location or 'unknown')
    parts[#parts + 1] = string.format('Summary: %s.', report.summary or 'no details available')
    parts[#parts + 1] = string.format('Priority level: %s.', report.priority or 'unassigned')
    parts[#parts + 1] = string.format('Units dispatched: %s.', report.units or 'none')
    parts[#parts + 1] = string.format('Status: %s.', report.status or 'active')
    parts[#parts + 1] = string.format('Dispatch codes: %s.', report.dispatchCodes or 'pending analysis')

    return table.concat(parts, ' ')
end
