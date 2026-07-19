-- ============================================================
-- 911呼叫插件 — NUI界面管理
-- 处理NUI可见性和回调
-- ============================================================

local isNUIFocused = false

--- 显示NUI覆盖层
function ShowNUI()
    if isNUIFocused then return end
    SetNuiFocus(true, false)
    SetNuiFocusKeepInput(true)
    isNUIFocused = true
    SendNUIMessage({ action = 'setVisible', visible = true })
end

--- 隐藏NUI覆盖层
function HideNUI()
    if not isNUIFocused then return end
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    isNUIFocused = false
    SendNUIMessage({ action = 'setVisible', visible = false })
end

--- 切换NUI可见性
function ToggleNUI()
    if isNUIFocused then
        HideNUI()
    else
        ShowNUI()
    end
end

-- NUI回调：当玩家在聊天中输入时隐藏NUI覆盖层
RegisterNUICallback('chatInput', function(data, cb)
    HideNUI()
    cb('ok')
end)

-- NUI回调：当玩家点击关闭时
RegisterNUICallback('dismiss', function(data, cb)
    HideNUI()
    cb('ok')
end)
