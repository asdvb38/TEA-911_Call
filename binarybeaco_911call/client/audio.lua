-- ============================================================
-- 911呼叫插件 — 音频播放
-- 通过NUI处理TTS语音播放
-- ============================================================

--- 通过NUI播放音频
-- @param audioPath string - 音频文件路径
-- @param audioBase64 string - Base64编码的音频数据
local function PlayAudioViaNUI(audioPath, audioBase64)
    if not audioPath and not audioBase64 then return end

    -- 确保NUI不被锁定（不影响聊天输入）
    SetNuiFocus(false, false)

    -- 发送音频路径到NUI播放
    SendNUIMessage({
        action = 'playAudio',
        audioPath = audioPath,
        audioBase64 = audioBase64,
    })
end

--- 注册音频播放事件（与 client/main.lua 保持一致）
RegisterNetEvent('911call:playTTSAudio', function(audioPath, audioBase64)
    PlayAudioViaNUI(audioPath, audioBase64)
end)

--- 播放简单的系统音效
-- @param soundName string - FiveM音效名称
local function PlaySystemSound(soundName)
    PlaySoundFrontend(-1, soundName, 'HUD_MINI_GAME_SOUNDSET')
end
