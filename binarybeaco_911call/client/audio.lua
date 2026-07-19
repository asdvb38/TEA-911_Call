-- ============================================================
-- 911呼叫插件 — 音频播放
-- 通过隐藏NUI播放TTS语音（无视觉UI）
-- ============================================================

--- 播放TTS音频
RegisterNetEvent('911call:playTTSAudio', function(audioPath, audioBase64)
    if not audioPath and not audioBase64 then return end

    SendNUIMessage({
        action = 'playAudio',
        audioPath = audioPath,
        audioBase64 = audioBase64,
    })
end)
