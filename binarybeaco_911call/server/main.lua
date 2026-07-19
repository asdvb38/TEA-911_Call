-- ============================================================
-- 911呼叫插件 — 服务器主逻辑
-- 命令注册与会话管理
-- ============================================================

local CallSessions = {}  -- 跟踪每个玩家的通话会话

--- 安全加载配置文件
local function LoadConfig()
    local configPath = 'config/settings.lua'
    local resourcePath = GetResourcePath('binarybeaco_911call')
    local filePath = resourcePath .. '/' .. configPath
    local file = io.open(filePath, 'r')

    if file then
        local content = file:read('*all')
        file:close()

        -- 执行配置文件中的 Lua 代码
        local fn, err = load(content, 'settings.lua', 't')
        if fn then
            fn()
            return Config
        else
            print('^1[911呼叫] 加载配置失败: ' .. tostring(err) .. '^7')
        end
    else
        print('^1[911呼叫] 配置文件不存在: ' .. filePath .. '^7')
    end

    -- 配置加载失败时使用默认值
    return {
        APISettings = {
            URL = 'https://apihub.agnes-ai.com/v1/chat/completions',
            Model = 'agnes-2.0-flash',
            APIKey = '',
            Timeout = 30,
            MaxRetries = 1,
        },
        TTSSettings = {
            Provider = 'azure',
            AzureRegion = 'eastus',
            AzureKey = '',
            Voice = 'en-US-AriaNeural',
            EdgeVoice = 'en-US-AriaNeural',
        },
        DispatchStyle = 'A',
        WaitTime = 2000,
        Language = 'en',
        ChatSettings = {
            OperatorPrefix = '[接线员]',
            DispatcherPrefix = '[调度员]',
            SystemPrefix = '[911系统]',
            CaseReportPrefix = '[案件报告]',
        },
        EnableDebug = false,
    }
end

Config = LoadConfig()

--- 记录调试日志
function DebugLog(msg)
    if Config.EnableDebug then
        print('^5[911呼叫 调试]^7 ' .. tostring(msg))
    end
end

--- 检查玩家是否有活跃的会话
function HasActiveSession(source)
    return CallSessions[source] ~= nil
end

--- 创建新的呼叫会话
function CreateSession(source, playerName)
    CallSessions[source] = {
        source = source,
        playerName = playerName or GetPlayerName(source),
        message = '',
        location = {},
        timestamp = os.time(),
        status = 'initiated',
        caseNumber = nil,
    }
    DebugLog('为玩家 ' .. source .. ' 创建会话: ' .. CallSessions[source].playerName)
end

--- 获取当前会话
function GetSession(source)
    return CallSessions[source]
end

--- 更新会话字段
function UpdateSession(source, field, value)
    if CallSessions[source] then
        CallSessions[source][field] = value
        DebugLog('会话更新: ' .. field .. ' = ' .. tostring(value))
    end
end

--- 完成并清理会话
function CompleteSession(source)
    if CallSessions[source] then
        DebugLog('玩家 ' .. source .. ' 会话已完成')
        CallSessions[source] = nil
    end
end

--- 注册 /911call 命令
RegisterCommand('911call', function(source, args, rawCommand)
    if source == 0 then return end  -- 不允许控制台使用

    -- 检查玩家是否已有活跃会话
    if HasActiveSession(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            args = {'错误', '您已有一个活跃的911呼叫会话。请使用 /911say 描述您的紧急情况。'}
        })
        return
    end

    -- 创建新会话
    CreateSession(source)
    UpdateSession(source, 'status', 'waiting')

    -- 通知客户端在延迟后显示911提示
    local waitTime = Config.WaitTime or 2000
    TriggerClientEvent('911call:startFlow', source, waitTime)

    DebugLog('玩家 ' .. source .. ' 使用了 /911call')
end, false)

--- 注册 /911say 命令
RegisterCommand('911say', function(source, args, rawCommand)
    if source == 0 then return end  -- 不允许控制台使用

    -- 检查玩家是否有活跃会话
    if not HasActiveSession(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            args = {'错误', '请先使用 /911call 开始911报案。'}
        })
        return
    end

    -- 获取消息内容（/911say 之后的所有内容）
    local message = table.concat(args, ' ')
    if message == '' or #message < 3 then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            args = {'错误', '请详细描述您的紧急情况。例如: /911say 我看到加油站有人开枪射击'}
        })
        return
    end

    -- 存储消息到会话
    UpdateSession(source, 'message', message)
    UpdateSession(source, 'status', 'processing')

    -- 获取玩家位置
    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    UpdateSession(source, 'location', { x = coords.x, y = coords.y, z = coords.z })

    DebugLog('玩家 ' .. source .. ' 报告: ' .. message)

    -- 触发服务端AI处理
    ProcessReport(source)
end, false)

--- 主要报告处理流程
function ProcessReport(source)
    local session = GetSession(source)
    if not session then return end

    local message = session.message
    local coords = session.location

    -- 第一步：通过触发词分类紧急类型
    local emergencyType = ClassifyEmergency(message)
    DebugLog('紧急类型分类: ' .. emergencyType)

    -- 第二步：根据调度风格处理
    local dispatchStyle = Config.DispatchStyle or 'A'

    if dispatchStyle == 'A' then
        ProcessStyleA(source, message, coords, emergencyType)
    else
        ProcessStyleB(source, message, coords, emergencyType)
    end
end

--- 供外部资源调用的导出
exports('ProcessReport', ProcessReport)
