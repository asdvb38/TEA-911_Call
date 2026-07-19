-- ============================================================
-- 911 Call Plugin - TTS Generation (Azure TTS / Edge-TTS)
-- ============================================================

--- Generate speech from text using Azure TTS
-- @param text string - Text to convert to speech
-- @return string|nil - Relative path to generated audio file or nil
function GenerateSpeechAzure(text)
    local ttsSettings = Config.TTSSettings
    if not ttsSettings or not ttsSettings.AzureKey or ttsSettings.AzureKey == 'YOUR_AZURE_TTS_KEY_HERE' then
        print('^1[911call] Azure TTS key not configured!^7')
        return nil
    end

    local region = ttsSettings.AzureRegion or 'eastus'
    local voice = ttsSettings.Voice or 'en-US-AriaNeural'

    -- Step 1: Get OAuth token (Azure Cognitive Services uses a simple API key auth)
    local tokenUrl = 'https://' .. region .. '.api.cognitiveservices.azure.com/sts/v1.0/issueToken'
    local tokenHeaders = 'Ocp-Apim-Subscription-Key: ' .. ttsSettings.AzureKey

    DebugLog('Getting Azure TTS token...')
    local tokenResp, tokenStatus = PerformHttpRequest(tokenUrl, 'POST', '', tokenHeaders, 10000)

    if tokenStatus ~= 200 or not tokenResp then
        print('^1[911call] Failed to get Azure TTS token. Status: ' .. tostring(tokenStatus) .. '^7')
        return nil
    end

    local accessToken = tokenResp  -- The new endpoint returns the token directly as a string
    if not accessToken or #accessToken == 0 then
        print('^1[911call] Empty access token received^7')
        return nil
    end

    -- Step 2: Generate speech with SSML
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

    DebugLog('Generating speech via Azure TTS...')
    local audioData, audioStatus = PerformHttpRequest(ttsUrl, 'POST', ssml, ttsHeaders, 30000)

    if not audioData or audioStatus ~= 200 then
        print('^1[911call] Azure TTS generation failed. Status: ' .. tostring(audioStatus) .. '^7')
        return nil
    end

    -- Step 3: Save audio to resource's audio folder
    local caseNum = GenerateCaseNumber()
    local fileName = '911call_' .. caseNum:gsub('%-', '_') .. '.wav'
    local filePath = 'audio/' .. fileName
    local fullPath = GetResourcePath('binarybeaco_911call') .. '/' .. filePath

    local file = io.open(fullPath, 'wb')
    if file then
        -- Convert base64 if needed, or write raw bytes
        file:write(audioData)
        file:close()
        DebugLog('Azure TTS audio saved: ' .. filePath)
        return filePath
    end

    print('^1[911call] Failed to save audio file^7')
    return nil
end

--- Generate speech using Edge-TTS (free fallback)
-- @param text string - Text to convert to speech
-- @return string|nil - Relative path to generated audio file or nil
function GenerateSpeechEdge(text)
    local ttsSettings = Config.TTSSettings
    local voice = ttsSettings.EdgeVoice or 'en-US-AriaNeural'

    local caseNum = GenerateCaseNumber()
    local fileName = '911call_' .. caseNum:gsub('%-', '_') .. '.mp3'
    local filePath = 'audio/' .. fileName
    local fullPath = GetResourcePath('binarybeaco_911call') .. '/' .. filePath

    -- Escape text for shell
    local escapedText = text:gsub('"', '\\"'):gsub('%', '%%')

    -- Try edge-tts command
    local cmd = string.format('edge-tts --voice "%s" --text "%s" --write-media "%s"', voice, escapedText, fullPath)

    DebugLog('Edge-TTS command: ' .. cmd)

    local handle = io.popen(cmd)
    if handle then
        handle:close()
        local f = io.open(fullPath, 'rb')
        if f then
            f:close()
            DebugLog('Edge-TTS audio saved: ' .. filePath)
            return filePath
        end
    end

    print('^1[911call] Edge-TTS failed. Install it with: pip install edge-tts^7')
    return nil
end

--- Main TTS generation function (provider-agnostic)
-- @param text string - Text to convert to speech
-- @return string|nil - Relative path to generated audio file
function GenerateSpeech(text)
    if not text or text == '' then return nil end

    local provider = Config.TTSSettings.Provider or 'azure'

    if provider == 'azure' then
        local result = GenerateSpeechAzure(text)
        if result then return result end
        print('^3[911call] Azure TTS unavailable, falling back to Edge-TTS^7')
    end

    return GenerateSpeechEdge(text)
end
