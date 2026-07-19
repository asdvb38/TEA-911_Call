-- ============================================================
-- 911呼叫插件 — AI集成（agnes-ai.com）
-- 使用回调方式的 PerformHttpRequest 进行异步API调用
-- ============================================================

--- 调用 agnes-ai.com API
-- @param prompt string - 用户提示/消息内容
-- @param systemPrompt string - 系统指令
-- @param callback function|nil - 可选回调函数 result
-- @return string|nil - 原始AI回复文本（仅在不提供回调时返回）
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

    -- 构建请求体（OpenAI 兼容格式）
    local requestBody = json.encode({
        model = model,
        messages = {
            { role = 'system', content = systemPrompt },
            { role = 'user', content = prompt }
        },
        temperature = 0.3,
        max_tokens = 2000,
    })

    -- 构建请求头
    local headers = 'Authorization: Bearer ' .. apiSettings.APIKey .. '\r\nContent-Type: application/json'

    DebugLog('Calling AI API: ' .. url)

    --- 内部递归重试函数
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
                    DebugLog('API retry ' .. (10 - retriesLeft) .. '/10 (status: ' .. tostring(statusCode) .. ')')
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
