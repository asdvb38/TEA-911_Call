-- ============================================================
-- 911 Call Plugin - Shared Utilities
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
-- @param message string - The player's emergency message
-- @return string - The classified emergency type
function ClassifyEmergency(message)
    local words = LoadTriggerWords()
    if not words or not message then return 'unknown' end

    local lowerMsg = string.lower(message)
    local bestMatch = 'unknown'
    local bestScore = 0

    for category, keywords in pairs(words) do
        for _, keyword in ipairs(keywords) do
            if string.find(lowerMsg, string.lower(keyword)) then
                local score = #keyword  -- longer keyword = stronger match
                if score > bestScore then
                    bestScore = score
                    bestMatch = category
                end
            end
        end
    end

    return bestMatch
end

--- Get a formatted display name for emergency type
-- @param type string - The emergency type from classification
-- @return string - Human-readable name
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
        unknown = 'Unclassified',
    }
    return names[type] or type
end

--- Get player coordinates (cross-framework compatible)
-- @param source number - Player server-side source ID
-- @return table - {x, y, z} coordinates
function GetPlayerCoords(source)
    local coords = GetEntityCoords(GetPlayerPed(source))
    return { x = coords.x, y = coords.y, z = coords.z }
end

--- Convert coordinates to a readable address-like string
-- @param coords table - {x, y, z} coordinates
-- @return string - Readable coordinate string
function CoordsToString(coords)
    return string.format('%.2f, %.2f, %.2f', coords.x, coords.y, coords.z)
end

--- Generate a unique case number
-- @return string - Format: 911-YYYYMMDD-XXXX
function GenerateCaseNumber()
    local date = os.date('%Y%m%d')
    local rand = math.random(1000, 9999)
    return string.format('911-%s-%s', date, rand)
end

--- Base64 encode a string
-- @param data string - Raw binary data
-- @return string - Base64 encoded string
function Base64Encode(data)
    return b64encode(data)
end

--- Format a case report for display and TTS
-- @param report table - Raw report data
-- @return string - Formatted text for chat + TTS
function FormatCaseReport(report)
    if not report then return '' end

    local lines = {}
    lines[#lines + 1] = string.format('CASE %s', report.caseNumber or 'N/A')
    lines[#lines + 1] = string.format('TYPE: %s', report.emergencyType or 'Unknown')
    lines[#lines + 1] = string.format('LOCATION: %s', report.location or 'Unknown')
    lines[#lines + 1] = string.format('SUMMARY: %s', report.summary or 'No details')
    lines[#lines + 1] = string.format('PRIORITY: %s', report.priority or 'Unassigned')
    lines[#lines + 1] = string.format('UNITS: %s', report.units or 'None')
    lines[#lines + 1] = string.format('STATUS: %s', report.status or 'Active')
    lines[#lines + 1] = string.format('CODES: %s', report.dispatchCodes or 'Pending')

    return table.concat(lines, '\n')
end

--- Format report as plain text for TTS (no special characters)
-- @param report table - Raw report data
-- @return string - Clean text for speech synthesis
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
