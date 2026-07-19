-- ============================================================
-- 911 Call Plugin - AI Integration (agnes-ai.com)
-- Uses callback-based PerformHttpRequest for async API calls
-- ============================================================

--- Call the agnes-ai.com API
-- @param prompt string - The user prompt/message
-- @param systemPrompt string - System instruction for the AI
-- @param callback function|nil - Optional callback(result) for async handling
-- @return string|nil - Raw AI response text (only if no callback provided)
function CallAI(prompt, systemPrompt, callback)
    local apiSettings = Config.APISettings
    if not apiSettings or not apiSettings.APIKey or apiSettings.APIKey == 'YOUR_AGNES_API_KEY_HERE' then
        print('^1[911call] API key not configured! Set Config.APISettings.APIKey in config/settings.lua^7')
        if callback then callback(nil) end
        return nil
    end

    local url = apiSettings.URL or 'https://apihub.agnes-ai.com/v1/chat/completions'
    local model = apiSettings.Model or 'agnes-2.0-flash'
    local timeout = (apiSettings.Timeout or 30) * 1000

    local requestBody = json.encode({
        model = model,
        messages = {
            { role = 'system', content = systemPrompt },
            { role = 'user', content = prompt }
        },
        temperature = 0.3,
        max_tokens = 2000,
    })

    local headers = 'Authorization: Bearer ' .. apiSettings.APIKey .. '\r\nContent-Type: application/json'

    DebugLog('Calling AI API: ' .. url)

    --- Inner recursive retry function
    local function attemptRequest(retriesLeft)
        PerformHttpRequest(url, function(statusCode, responseBody, responseHeaders)
            if statusCode == 200 and responseBody then
                local data = json.decode(responseBody)
                if data and data.choices and data.choices[1] and data.choices[1].message then
                    local content = data.choices[1].message.content
                    DebugLog('AI response received (' .. #content .. ' chars)')
                    if callback then
                        callback(content)
                    else
                        return content
                    end
                    return
                end
                print('^1[911call] Unexpected API response format^7')
            elseif statusCode == 521 or statusCode == 520 then
                -- Cloudflare/temporary error, retry
                if retriesLeft > 0 then
                    DebugLog('API retry ' .. (10 - retriesLeft) .. '/' .. 10 .. ' (status: ' .. tostring(statusCode) .. ')')
                    Wait(2000)
                    attemptRequest(retriesLeft - 1)
                    return
                end
            end

            print('^1[911call] API request failed. Status: ' .. tostring(statusCode) .. '^7')
            if callback then callback(nil) end
        end, requestBody, headers, timeout)
    end

    attemptRequest(10)
end
