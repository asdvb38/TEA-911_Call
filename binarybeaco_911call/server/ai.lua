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
        print('^1[911呼叫] API密钥未配置！请在 config/settings.lua 中设置 Config.APISettings.APIKey^7')
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

    DebugLog('正在调用AI API: ' .. url)

    --- 内部递归重试函数
    local function attemptRequest(retriesLeft)
        PerformHttpRequest(url, function(statusCode, responseBody, responseHeaders)
            if statusCode == 200 and responseBody then
                local data = json.decode(responseBody)
                if data and data.choices and data.choices[1] and data.choices[1].message then
                    local content = data.choices[1].message.content
                    DebugLog('AI回复已接收 (' .. #content .. ' 字符)')
                    if callback then
                        callback(content)
                    else
                        return content
                    end
                    return
                end
                print('^1[911呼叫] API响应格式异常^7')
            elseif statusCode == 521 or statusCode == 520 then
                -- Cloudflare/临时错误，进行重试
                if retriesLeft > 0 then
                    DebugLog('API重试 ' .. (10 - retriesLeft) .. '/10 (状态码: ' .. tostring(statusCode) .. ')')
                    Wait(2000)
                    attemptRequest(retriesLeft - 1)
                    return
                end
            end

            print('^1[911呼叫] API请求失败。状态码: ' .. tostring(statusCode) .. '^7')
            if callback then callback(nil) end
        end, requestBody, headers, timeout)
    end

    attemptRequest(10)
end
