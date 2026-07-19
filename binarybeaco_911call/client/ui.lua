-- ============================================================
-- 911 Call Plugin - NUI UI Management
-- Handles NUI visibility and callbacks
-- ============================================================

local isNUIFocused = false

--- Show the NUI overlay
function ShowNUI()
    if isNUIFocused then return end
    SetNuiFocus(true, false)
    SetNuiFocusKeepInput(true)
    isNUIFocused = true
    SendNUIMessage({ action = 'setVisible', visible = true })
end

--- Hide the NUI overlay
function HideNUI()
    if not isNUIFocused then return end
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    isNUIFocused = false
    SendNUIMessage({ action = 'setVisible', visible = false })
end

--- Toggle NUI visibility
function ToggleNUI()
    if isNUIFocused then
        HideNUI()
    else
        ShowNUI()
    end
end

-- NUI callback: when player types in chat, hide NUI overlay
RegisterNUICallback('chatInput', function(data, cb)
    HideNUI()
    cb('ok')
end)

-- NUI callback: when player clicks to dismiss
RegisterNUICallback('dismiss', function(data, cb)
    HideNUI()
    cb('ok')
end)

-- Handle ESC key to close NUI
RegisterKeyMapping('911call-toggle', 'Toggle 911 Call UI', 'keyboard', 'ESC')
