-- ============================================================
-- 911呼叫插件 — TTS生成（Azure TTS / Edge-TTS）
-- ============================================================

--- 使用 Azure TTS 生成语音
-- @param text string - 要转换为语音的文本
-- @return string|nil - 生成的音频文件相对路径，失败则返回 nil
function GenerateSpeechAzure(text)
    local ttsSettings = Config.TTSSettings
    if not ttsSettings or not ttsSettings.AzureKey or ttsSettings.AzureKey == 'YOUR_AZURE_TTS_KEY_HERE' then
        print('^1[911呼叫] Azure TTS 密钥未配置！^7')
        return nil
    end

    local region = ttsSettings.AzureRegion or 'eastus'
    local voice = ttsSettings.Voice or 'en-US-AriaNeural'

    -- 第一步：获取 OAuth 令牌
    local tokenUrl = 'https://' .. region .. '.api.cognitiveservices.azure.com/sts/v1.0/issueToken'
    local tokenHeaders = 'Ocp-Apim-Subscription-Key: ' .. ttsSettings.AzureKey

    DebugLog('正在获取 Azure TTS 令牌...')
    local tokenResp, tokenStatus = PerformHttpRequest(tokenUrl, 'POST', '', tokenHeaders, 10000)

    if tokenStatus ~= 200 or not tokenResp then
        print('^1[911呼叫] 获取 Azure TTS 令牌失败。状态码: ' .. tostring(tokenStatus) .. '^7')
        return nil
    end

    local accessToken = tokenResp  -- 新端点直接返回令牌字符串
    if not accessToken or #accessToken == 0 then
        print('^1[911呼叫] 收到的令牌为空^7')
        return nil
    end

    -- 第二步：使用 SSML 生成语音
    local ssml = string.format(
        '<speak xmlns="http://www.w3.org/2001/10/synthesis" xmlns:mstts="http://www.w3.org/2001/mstts" version="1.0" xml:lang="en-US">' ..
        '<voice name="%s">' ..
        '<mstts:express-as style="news" styledegree="1" role="SeniorFemale">' ..
        '<prosody rate="1.0" pitch="1.0" volume="5">%s</prosody>' ..
        '</mstts:express-as>' ..
        '</voice></speak>',
        voice, text
    )

    local ttsUrl = 'https://' .. region .. '.tts.speech.microsoft.com/cognitiveservices/v1'
    local ttsHeaders = 'Authorization: Bearer ' .. accessToken .. '\r\nContent-Type: application/ssml+xml\r\nX-Microsoft-OutputFormat: riff-16khz-16bit-mono-pcm'

    DebugLog('正在通过 Azure TTS 生成语音...')
    local audioData, audioStatus = PerformHttpRequest(ttsUrl, 'POST', ssml, ttsHeaders, 30000)

    if not audioData or audioStatus ~= 200 then
        print('^1[911呼叫] Azure TTS 生成失败。状态码: ' .. tostring(audioStatus) .. '^7')
        return nil
    end

    -- 第三步：保存音频到资源目录
    local caseNum = GenerateCaseNumber()
    local fileName = '911call_' .. caseNum:gsub('%-', '_') .. '.wav'
    local filePath = 'audio/' .. fileName
    local fullPath = GetResourcePath('binarybeaco_911call') .. '/' .. filePath

    local file = io.open(fullPath, 'wb')
    if file then
        file:write(audioData)
        file:close()
        DebugLog('Azure TTS 音频已保存: ' .. filePath)
        return filePath
    end

    print('^1[911呼叫] 保存音频文件失败^7')
    return nil
end

--- 使用 Edge-TTS（免费备选方案）生成语音
-- @param text string - 要转换为语音的文本
-- @return string|nil - 生成的音频文件相对路径，失败则返回 nil
function GenerateSpeechEdge(text)
    local ttsSettings = Config.TTSSettings
    local voice = ttsSettings.EdgeVoice or 'en-US-AriaNeural'

    local caseNum = GenerateCaseNumber()
    local fileName = '911call_' .. caseNum:gsub('%-', '_') .. '.mp3'
    local filePath = 'audio/' .. fileName
    local fullPath = GetResourcePath('binarybeaco_911call') .. '/' .. filePath

    -- 转义文本中的特殊字符
    local escapedText = text:gsub('"', '\\"'):gsub('%', '%%')

    -- 构建 edge-tts 命令
    local cmd = string.format('edge-tts --voice "%s" --text "%s" --write-media "%s"', voice, escapedText, fullPath)

    DebugLog('Edge-TTS 命令: ' .. cmd)

    local handle = io.popen(cmd)
    if handle then
        handle:close()
        local f = io.open(fullPath, 'rb')
        if f then
            f:close()
            DebugLog('Edge-TTS 音频已保存: ' .. filePath)
            return filePath
        end
    end

    print('^1[911呼叫] Edge-TTS 生成失败。请安装: pip install edge-tts^7')
    return nil
end

--- 主TTS生成函数（不依赖具体提供商）
-- @param text string - 要转换为语音的文本
-- @return string|nil - 生成的音频文件相对路径
function GenerateSpeech(text)
    if not text or text == '' then return nil end

    local provider = Config.TTSSettings.Provider or 'azure'

    if provider == 'azure' then
        local result = GenerateSpeechAzure(text)
        if result then return result end
        print('^3[911呼叫] Azure TTS 不可用，降级使用 Edge-TTS^7')
    end

    return GenerateSpeechEdge(text)
end
