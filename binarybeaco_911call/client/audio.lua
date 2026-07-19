-- ============================================================
-- 911 Call Plugin - Audio Playback
-- Handles TTS audio playback via NUI
-- ============================================================

--- Play audio through the NUI overlay
-- @param audioPath string - Path to the audio file
local audioElement = nil

RegisterNetEvent('911call:playTTSAudio', function(audioPath)
    if not audioPath or audioPath == '' then return end

    -- Ensure NUI is focused for audio playback
    SetNuiFocus(false, false)

    -- Send audio path to NUI for playback
    SendNUIMessage({
        action = 'playAudio',
        audioPath = audioPath,
    })
end)

--- Play a simple system sound
-- @param soundName string - FiveM sound name
function PlaySystemSound(soundName)
    PlaySoundFrontend(-1, soundName, 'HUD_MINI_GAME_SOUNDSET')
end
